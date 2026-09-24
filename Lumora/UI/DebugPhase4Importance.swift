#if DEBUG
import Foundation
import CoreGraphics

/// Phase 4 map equations and constants ported from SpatialImportancePrototype.
/// The same guided/tonal Metal kernel consumes the resulting importance map.
enum DebugPhase4Importance {
    static func make(image:CGImage,scene:DebugSceneResult,variant:DebugToneVariant)throws->FloatMap {
        let decoded=try DebugLabBitmap.linear(image,maximum:256)
        let w=decoded.width,h=decoded.height,n=w*h,side=Float(min(w,h)),eps:Float=0.005
        let rgba=decoded.pixels
        var logY=[Float](repeating:0,count:n)
        for i in 0..<n {
            let y=max(0,0.2126*rgba[4*i]+0.7152*rgba[4*i+1]+0.0722*rgba[4*i+2])
            logY[i]=log2(y+eps)
        }
        let base=try gaussian(logY,w:w,h:h,sigma:max(1,side*0.06))
        let surround=try gaussian(base,w:w,h:h,sigma:max(2,side*0.18))
        let residual=(0..<n).map{logY[$0]-base[$0]}
        let residual2=residual.map{$0*$0}
        let localRMS=try gaussian(residual2,w:w,h:h,sigma:max(1,side*0.035))
        var grad=[Float](repeating:0,count:n)
        for row in 0..<h {for x in 0..<w {
            let topLeft=base[index(x-1,row-1,w,h)],top=base[index(x,row-1,w,h)],topRight=base[index(x+1,row-1,w,h)]
            let left=base[index(x-1,row,w,h)],right=base[index(x+1,row,w,h)]
            let bottomLeft=base[index(x-1,row+1,w,h)],bottom=base[index(x,row+1,w,h)],bottomRight=base[index(x+1,row+1,w,h)]
            let sx = -topLeft + topRight - 2*left + 2*right - bottomLeft + bottomRight
            let sy = -topLeft - 2*top - topRight + bottomLeft + 2*bottom + bottomRight
            grad[row*w+x]=hypot(sx,sy)
        }}
        let gradient=try gaussian(grad,w:w,h:h,sigma:max(1,side*0.03))
        var raw=[Float](repeating:0,count:n)
        for row in 0..<h {for x in 0..<w {
            let i=row*w+x
            let darkness=1-smooth(log2(0.015+eps),log2(0.30+eps),base[i])
            let contrast=clamp(sqrt(max(0,localRMS[i]))/0.95)
            let regional=clamp(abs(base[i]-surround[i])/1.8)
            let structure=clamp(gradient[i]/0.8)
            let edge=min(min(Float(x)+0.5,Float(w-x)-0.5)/Float(w),
                         min(Float(row)+0.5,Float(h-row)-0.5)/Float(h))
            let prior=0.90+0.10*smooth(0,0.15,edge)
            raw[i]=clamp(darkness*(0.12+0.38*contrast+0.32*regional+0.18*structure)*prior)
        }}
        let spatial=try gaussian(raw,w:w,h:h,sigma:max(0.7,side*0.012)).map(clamp)
        if variant == .spatial {return FloatMap(width:w,height:h,pixels:spatial)}
        let sourceW=scene.analysis.gridWidth,sourceH=scene.analysis.gridHeight
        let personSource=scene.fields["Persons"] ?? Array(repeating:0,count:sourceW*sourceH)
        let person=try gaussian(resample(personSource,w:sourceW,h:sourceH,toW:w,toH:h),
                                w:w,h:h,sigma:max(0.7,side*0.022)).map(clamp)
        var faceField=[Float](repeating:0,count:n),faceEvidence:Float=0
        for face in scene.analysis.faces {
            let area=Float(face.width*face.height)
            let confidence=Float(face.confidence)*smooth(0.0015,0.015,area)
            faceEvidence=max(faceEvidence,confidence)
            let cx=Float(face.x+face.width/2),cy=Float(face.y+face.height/2)
            let sx=max(0.01,Float(face.width)*0.85),sy=max(0.01,Float(face.height)*1.20)
            for row in 0..<h {for x in 0..<w {
                let dx=((Float(x)+0.5)/Float(w)-cx)/sx
                let dy=((Float(row)+0.5)/Float(h)-cy)/sy
                faceField[row*w+x]=max(faceField[row*w+x],exp(-0.5*(dx*dx+dy*dy))*confidence)
            }}
        }
        let personArea=Float(person.filter{$0>0.5}.count)/Float(n)
        let personEvidence:Float=scene.analysis.personAvailable
            ? 0.82*smooth(0.008,0.055,personArea)*(1-smooth(0.75,0.95,personArea)) : 0
        let confidence=max(faceEvidence,personEvidence)
        var rawSemantic=[Float](repeating:0,count:n)
        for i in 0..<n {rawSemantic[i]=clamp(1-(1-0.90*person[i])*(1-faceField[i]))}
        let semantic=try gaussian(rawSemantic,w:w,h:h,sigma:max(0.7,side*0.012)).map(clamp)
        let result=(0..<n).map {i -> Float in
            if variant == .semantic {return confidence<1e-6 ? spatial[i] : (1-confidence)*spatial[i]+confidence*semantic[i]}
            return spatial[i]+confidence*semantic[i]*(1-spatial[i])
        }
        return FloatMap(width:w,height:h,pixels:result)
    }
    private static func clamp(_ x:Float)->Float {min(1,max(0,x))}
    private static func smooth(_ a:Float,_ b:Float,_ x:Float)->Float {
        let t=clamp((x-a)/(b-a));return t*t*(3-2*t)
    }
    private static func index(_ x:Int,_ row:Int,_ w:Int,_ h:Int)->Int {
        reflect(row,h)*w+reflect(x,w)
    }
    private static func reflect(_ x:Int,_ n:Int)->Int {
        if n<=1{return 0};let period=2*n
        let value=((x%period)+period)%period
        return value<n ? value : period-value-1
    }
    private static func gaussian(_ input:[Float],w:Int,h:Int,sigma:Float)throws->[Float] {
        let radius=max(1,Int(3*sigma+0.5))
        let weights=(-radius...radius).map {exp(-0.5*Float($0*$0)/(sigma*sigma))}
        let norm=weights.reduce(0,+)
        var temp=[Float](repeating:0,count:input.count),out=temp
        for row in 0..<h {
            try Task.checkCancellation()
            for x in 0..<w {
                var sum:Float=0
                for d in -radius...radius {sum+=weights[d+radius]*input[row*w+reflect(x+d,w)]}
                temp[row*w+x]=sum/norm
            }
        }
        for row in 0..<h {
            try Task.checkCancellation()
            for x in 0..<w {
                var sum:Float=0
                for d in -radius...radius {sum+=weights[d+radius]*temp[reflect(row+d,h)*w+x]}
                out[row*w+x]=sum/norm
            }
        }
        return out
    }
    private static func resample(_ source:[Float],w:Int,h:Int,toW:Int,toH:Int)->[Float] {
        var out=[Float](repeating:0,count:toW*toH)
        for row in 0..<toH {for x in 0..<toW {
            let sx=(Float(x)+0.5)*Float(w)/Float(toW)-0.5
            let sy=(Float(row)+0.5)*Float(h)/Float(toH)-0.5
            let x0=max(0,min(w-1,Int(floor(sx)))),x1=min(w-1,x0+1)
            let y0=max(0,min(h-1,Int(floor(sy)))),y1=min(h-1,y0+1)
            let fx=clamp(sx-Float(x0)),fy=clamp(sy-Float(y0))
            let a=source[y0*w+x0]*(1-fx)+source[y0*w+x1]*fx
            let b=source[y1*w+x0]*(1-fx)+source[y1*w+x1]*fx
            out[row*toW+x]=a*(1-fy)+b*fy
        }}
        return out
    }
}
#endif
