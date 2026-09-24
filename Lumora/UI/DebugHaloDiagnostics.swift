#if DEBUG
import Foundation
import CoreGraphics

/// Display-domain diagnostics only. The input and result are the same preview
/// bitmaps shown by DebugLabCanvas; this never changes a tone variant.
enum DebugHaloDiagnostics {
    struct Region: Codable, Sendable {
        let pixels: Int
        let meanAbsoluteY: Double
        let meanSignedY: Double
        let meanAbsoluteChroma: Double
    }
    struct Border: Codable, Sendable {
        let edgeMeanAbsoluteY: Double
        let innerMeanAbsoluteY: Double
        let excess: Double
        let signedEdgeY: Double
    }
    struct Metrics: Codable, Sendable {
        let width: Int, height: Int
        let meanAbsoluteY: Double, p95AbsoluteY: Double
        let meanAbsoluteChroma: Double, p95AbsoluteChroma: Double
        let changed2: Double, changed5: Double, changed10: Double, changed20: Double
        let shadows: Region, midtones: Region, highlights: Region
        let subject: Region?, background: Region?
        let subjectSource: String
        let meanAbsoluteLocalContrastChange: Double
        let meanSignedLocalContrastChange: Double
        let introducedShadowClipping: Double, introducedHighlightClipping: Double
        let strongEdgeCount: Int, brightHaloCount: Int, darkHaloCount: Int
        let brightHaloBands: Int, darkHaloBands: Int, largestBandPixels: Int
        let edgeEnhancementCount: Int
        let brightHaloFraction: Double, darkHaloFraction: Double
        let left: Border, right: Border, top: Border, bottom: Border
        let leftRightExcessAsymmetry: Double, topBottomExcessAsymmetry: Double
        let worstX: Int, worstY: Int, worstResidual: Double
        let suspectedCause: String, diagnosisConfidence: String
    }
    struct Result: Sendable {
        let metrics: Metrics
        let overlays: [String: CGImage]
    }
    private struct Acc {
        var count=0, absY=0.0, signedY=0.0, absC=0.0
        mutating func add(_ d:Double,_ c:Double) {
            count+=1;absY+=abs(d);signedY+=d;absC+=abs(c)
        }
        var region:Region {
            let n=Double(max(1,count))
            return Region(pixels:count,meanAbsoluteY:absY/n,
                          meanSignedY:signedY/n,meanAbsoluteChroma:absC/n)
        }
    }

    static func evaluate(original:CGImage,processed:CGImage,scene:DebugSceneResult?,makeOverlays:Bool=true) throws -> Result {
        let before=try DebugLabBitmap.linear(original)
        let after=try DebugLabBitmap.linear(processed)
        let w=before.width,h=before.height,n=w*h
        guard w==after.width,h==after.height,w>32,h>32 else {
            throw NSError(domain:"Debug halo image dimensions",code:1)
        }
        var y0=[Float](repeating:0,count:n),y1=y0,diff=y0,cdiff=y0
        var shadows=Acc(),midtones=Acc(),highlights=Acc(),subject=Acc(),background=Acc()
        var absY=0.0,absC=0.0,changed=[Int](repeating:0,count:4),clipS=0,clipH=0
        var yHistogram=[Int](repeating:0,count:4096),cHistogram=yHistogram
        let subjectField:([Float]?,Int,Int,String) = {
            guard let scene else{return (nil,0,0,"unavailable")}
            let a=scene.analysis,person=scene.fields["Persons"] ?? []
            if person.contains(where:{$0>0.5}) {return (person,a.gridWidth,a.gridHeight,"Vision person")}
            let candidates=scene.fields["Subject candidates"] ?? []
            if candidates.contains(where:{$0>0.5}) {return (candidates,a.gridWidth,a.gridHeight,"Vision candidates")}
            return (nil,0,0,"unavailable")
        }()
        for i in 0..<n {
            if i%(max(1,w)*64)==0 {try Task.checkCancellation()}
            let b=4*i
            let r0=before.pixels[b],g0=before.pixels[b+1],b0=before.pixels[b+2]
            let r1=after.pixels[b],g1=after.pixels[b+1],b1=after.pixels[b+2]
            let originalY=0.2126*r0+0.7152*g0+0.0722*b0
            let processedY=0.2126*r1+0.7152*g1+0.0722*b1
            let d=Double(processedY-originalY)
            let c=Double(chroma(r1,g1,b1)-chroma(r0,g0,b0))
            y0[i]=originalY;y1[i]=processedY;diff[i]=Float(d);cdiff[i]=Float(c)
            let ad=abs(d),ac=abs(c)
            absY+=ad;absC+=ac
            yHistogram[min(4095,Int(min(1,ad)*4095))]+=1
            cHistogram[min(4095,Int(min(1,ac)*4095))]+=1
            for j in 0..<4 where ad > [0.02,0.05,0.10,0.20][j] {changed[j]+=1}
            if originalY<0.12 {shadows.add(d,c)}
            else if originalY<0.70 {midtones.add(d,c)}
            else {highlights.add(d,c)}
            if originalY>0.003 && processedY<=0.003 {clipS+=1}
            if originalY<0.985 && processedY>=0.985 {clipH+=1}
            if let field=subjectField.0 {
                let sx=min(subjectField.1-1,(i%w)*subjectField.1/w)
                let sy=min(subjectField.2-1,(i/w)*subjectField.2/h)
                if field[sy*subjectField.1+sx]>0.5 {subject.add(d,c)}
                else {background.add(d,c)}
            }
        }
        func at(_ x:Int,_ row:Int)->Int {min(h-1,max(0,row))*w+min(w-1,max(0,x))}
        var edge=[Float](repeating:0,count:n),bright=edge,dark=edge,enhance=edge
        var localAbs=0.0,localSigned=0.0,localCount=0
        var strong=0,brightCount=0,darkCount=0,enhanceCount=0
        var worst=0.0,worstX=0,worstY=0
        // Same-side residual: 3–5 px from an edge minus 9–11 px from it.
        // This removes broad tone shifts and deliberately ignores the first
        // two pixels, where legitimate edge sharpening dominates.
        for row in 2..<(h-2) {
            if row%64==0 {try Task.checkCancellation()}
            for x in 2..<(w-2) {
                let i=row*w+x
                let gx=Double(y0[at(x+1,row)]-y0[at(x-1,row)])
                let gy=Double(y0[at(x,row+1)]-y0[at(x,row-1)])
                let gx1=Double(y1[at(x+1,row)]-y1[at(x-1,row)])
                let gy1=Double(y1[at(x,row+1)]-y1[at(x,row-1)])
                let g0=hypot(gx,gy),g1=hypot(gx1,gy1)
                localAbs+=abs(g1-g0);localSigned+=g1-g0;localCount+=1
                // A linear-luminance difference of 0.08 across 2 px is a
                // strong edge; the fixed threshold is diagnostic, not tuned.
                guard g0>=0.08,x>=12,row>=12,x<w-12,row<h-12 else {continue}
                edge[i]=Float(min(1,g0/0.4));strong+=1
                // Sample along the dominant gradient axis. The sign points
                // toward the bright side, regardless of image orientation.
                let horizontal=abs(gx)>=abs(gy)
                let sign=(horizontal ? gx:gy)>=0 ? 1:-1
                func value(_ side:Int,_ distance:Int)->Double {
                    let xx=x+(horizontal ? side*sign*distance:0)
                    let yy=row+(horizontal ? 0:side*sign*distance)
                    return Double(diff[yy*w+xx])
                }
                func residual(_ side:Int)->Double {
                    let near=(3...5).reduce(0.0){$0+value(side,$1)}/3
                    let far=(9...11).reduce(0.0){$0+value(side,$1)}/3
                    return near-far
                }
                let positive=residual(1),negative=residual(-1)
                let threshold=0.015
                if positive>threshold && negative < -threshold {
                    enhance[i]=Float(min(1,max(positive,-negative)/0.08));enhanceCount+=1
                    continue
                }
                if positive>threshold || negative>threshold {
                    let r=max(positive,negative)
                    bright[i]=Float(min(1,r/0.08));brightCount+=1
                    if r>worst {worst=r;worstX=x;worstY=row}
                }
                if positive < -threshold || negative < -threshold {
                    let r=min(positive,negative)
                    dark[i]=Float(min(1,-r/0.08));darkCount+=1
                    if -r>worst {worst = -r;worstX=x;worstY=row}
                }
            }
        }
        let band=max(4,min(16,min(w,h)/64))
        // Count coherent runs along edges separately from isolated candidate
        // pixels. Eight connected samples is a fixed descriptive minimum.
        func bands(_ values:[Float])->(Int,Int) {
            var seen=[Bool](repeating:false,count:n),count=0,largest=0
            for start in 0..<n where values[start]>0 && !seen[start] {
                var queue=[start],head=0
                seen[start]=true
                while head<queue.count {
                    let index=queue[head];head+=1
                    let x=index%w,row=index/w
                    for yy in max(0,row-1)...min(h-1,row+1) {
                        for xx in max(0,x-1)...min(w-1,x+1) {
                            let neighbor=yy*w+xx
                            if values[neighbor]>0 && !seen[neighbor] {
                                seen[neighbor]=true;queue.append(neighbor)
                            }
                        }
                    }
                }
                if queue.count>=8 {count+=1;largest=max(largest,queue.count)}
            }
            return (count,largest)
        }
        let brightBands=bands(bright),darkBands=bands(dark)
        func border(_ side:Int)->Border {
            var outer=0.0,inner=0.0,signed=0.0,count=0
            let rows:Range<Int>
            let columns:Range<Int>
            switch side {
            case 0: rows=band..<(h-band);columns=0..<(3*band)
            case 1: rows=band..<(h-band);columns=(w-3*band)..<w
            case 2: rows=0..<(3*band);columns=band..<(w-band)
            default:rows=(h-3*band)..<h;columns=band..<(w-band)
            }
            for row in rows {
                for x in columns {
                    let distance:Int
                    switch side {case 0:distance=x;case 1:distance=w-1-x
                                 case 2:distance=row;default:distance=h-1-row}
                    guard distance<band || (distance>=2*band && distance<3*band) else {continue}
                    let d=Double(diff[row*w+x])
                    if distance<band {outer+=abs(d);signed+=d}
                    else {inner+=abs(d)}
                    if distance<band {count+=1}
                }
            }
            let divisor=Double(max(1,count))
            return Border(edgeMeanAbsoluteY:outer/divisor,innerMeanAbsoluteY:inner/divisor,
                          excess:(outer-inner)/divisor,signedEdgeY:signed/divisor)
        }
        let left=border(0),right=border(1),top=border(2),bottom=border(3)
        let lr=abs(left.excess-right.excess),tb=abs(top.excess-bottom.excess)
        let haloFraction=Double(brightCount+darkCount)/Double(max(1,strong))
        let cause:String,confidence:String
        if max(lr,tb)>0.02 && max(left.excess,right.excess,top.excess,bottom.excess)>0.015 {
            cause="Border-localized difference; scene content or boundary processing not isolated"
            confidence="low"
        } else if haloFraction>0.02 {
            cause="Local reconstruction or filter response; compare variants to isolate stage"
            confidence="low"
        } else if absY/Double(n)>0.02 {
            cause="Broad tonal transform; no strong local-halo evidence"
            confidence="low"
        } else {cause="No strong artifact signature at diagnostic thresholds";confidence="low"}
        let metrics=Metrics(width:w,height:h,meanAbsoluteY:absY/Double(n),
                            p95AbsoluteY:percentile(yHistogram,n),meanAbsoluteChroma:absC/Double(n),
                            p95AbsoluteChroma:percentile(cHistogram,n),
                            changed2:Double(changed[0])/Double(n),changed5:Double(changed[1])/Double(n),
                            changed10:Double(changed[2])/Double(n),changed20:Double(changed[3])/Double(n),
                            shadows:shadows.region,midtones:midtones.region,highlights:highlights.region,
                            subject:subject.count>0 ? subject.region:nil,
                            background:background.count>0 ? background.region:nil,
                            subjectSource:subjectField.3,
                            meanAbsoluteLocalContrastChange:localAbs/Double(max(1,localCount)),
                            meanSignedLocalContrastChange:localSigned/Double(max(1,localCount)),
                            introducedShadowClipping:Double(clipS)/Double(n),
                            introducedHighlightClipping:Double(clipH)/Double(n),
                            strongEdgeCount:strong,brightHaloCount:brightCount,darkHaloCount:darkCount,
                            brightHaloBands:brightBands.0,darkHaloBands:darkBands.0,
                            largestBandPixels:max(brightBands.1,darkBands.1),
                            edgeEnhancementCount:enhanceCount,
                            brightHaloFraction:Double(brightCount)/Double(max(1,strong)),
                            darkHaloFraction:Double(darkCount)/Double(max(1,strong)),
                            left:left,right:right,top:top,bottom:bottom,
                            leftRightExcessAsymmetry:lr,topBottomExcessAsymmetry:tb,
                            worstX:worstX,worstY:worstY,worstResidual:worst,
                            suspectedCause:cause,diagnosisConfidence:confidence)
        guard makeOverlays else {return Result(metrics:metrics,overlays:[:])}
        var borderMap=[Float](repeating:0,count:n)
        let zones=[left,right,top,bottom]
        for row in 0..<h {for x in 0..<w {
            let distances=[x,w-1-x,row,h-1-row]
            for side in 0..<4 where distances[side]<band && zones[side].excess>0.015 {
                borderMap[row*w+x]=Float(min(1,zones[side].excess/0.08))
            }
        }}
        func display(_ values:[Float],rgb:(Float,Float,Float),scale:Float)->CGImage? {
            var rgba=[Float](repeating:0,count:n*4)
            for i in 0..<n {
                let a=min(0.8,max(0,values[i]*scale))
                rgba[4*i]=rgb.0;rgba[4*i+1]=rgb.1;rgba[4*i+2]=rgb.2;rgba[4*i+3]=a
            }
            return try? DebugLabBitmap.display(rgba,width:w,height:h)
        }
        let positive=diff.map {max(0,$0)},negative=diff.map {max(0,-$0)}
        var composite=[Float](repeating:0,count:n*4)
        for i in 0..<n {
            let b=bright[i],d=dark[i],border=borderMap[i]
            let weight=max(max(b,d),border)
            composite[4*i]=max(b,border)
            composite[4*i+1]=min(1,0.45*border+0.35*edge[i])
            composite[4*i+2]=d
            composite[4*i+3]=min(0.85,weight*0.75+edge[i]*0.12)
        }
        var overlays:[String:CGImage]=[:]
        overlays["Positive luminance difference"]=display(positive,rgb:(1,0.24,0.08),scale:7)
        overlays["Negative luminance difference"]=display(negative,rgb:(0.12,0.45,1),scale:7)
        overlays["Strong edges"]=display(edge,rgb:(1,1,0.2),scale:0.7)
        overlays["Suspected bright halos"]=display(bright,rgb:(1,0.1,0.4),scale:0.85)
        overlays["Suspected dark halos"]=display(dark,rgb:(0.1,0.7,1),scale:0.85)
        overlays["Border anomaly zones"]=display(borderMap,rgb:(1,0.55,0.06),scale:0.8)
        overlays["Halo Map"]=try? DebugLabBitmap.display(composite,width:w,height:h)
        return Result(metrics:metrics,overlays:overlays)
    }

    private static func percentile(_ bins:[Int],_ count:Int)->Double {
        let target=Int(ceil(Double(count)*0.95))
        var sum=0
        for (index,value) in bins.enumerated() {
            sum+=value
            if sum>=target {return Double(index)/4095}
        }
        return 1
    }
    private static func chroma(_ r:Float,_ g:Float,_ b:Float)->Float {
        // OKLab chroma from linear sRGB.
        let l=cbrt(max(0,0.4122214708*r+0.5363325363*g+0.0514459929*b))
        let m=cbrt(max(0,0.2119034982*r+0.6806995451*g+0.1073969566*b))
        let s=cbrt(max(0,0.0883024619*r+0.2817188376*g+0.6299787005*b))
        let a=1.9779984951*l-2.4285922050*m+0.4505937099*s
        let bb=0.0259040371*l+0.7827717662*m-0.8086757660*s
        return hypot(a,bb)
    }
}

actor DebugHaloAnalyzer {
    static let shared=DebugHaloAnalyzer()
    func analyze(original:CGImage,processed:CGImage,scene:DebugSceneResult?) throws -> DebugHaloDiagnostics.Result {
        try DebugHaloDiagnostics.evaluate(original:original,processed:processed,scene:scene)
    }
}
#endif
