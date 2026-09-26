import Foundation
import CoreImage
import Testing
@testable import LumoraCore

struct DarkenLightenCenterTestChart {
    static func image(width:Int=768,height:Int=512)->CIImage {
        let square=SyntheticCharts.make(size:max(width,height)){x,y in
            if x<0.08 && y<0.08 {return SIMD3(0.7,0.04,0.03)}
            if x>0.92 && y<0.08 {return SIMD3(0.03,0.6,0.05)}
            if x<0.08 && y>0.92 {return SIMD3(0.02,0.07,0.8)}
            if x>0.92 && y>0.92 {return SIMD3(0.7,0.6,0.02)}
            let grid=(x*16).truncatingRemainder(dividingBy:1)<0.025 || (y*16).truncatingRemainder(dividingBy:1)<0.025
            let marker=hypot(x-0.5,y-0.5)<0.015 || hypot(x-0.25,y-0.25)<0.012 || hypot(x-0.75,y-0.7)<0.012
            return SIMD3(repeating:marker ? 0.5:grid ? 0.12:0.18)
        }
        return square.transformed(by:CGAffineTransform(scaleX:Double(width)/square.extent.width,y:Double(height)/square.extent.height))
    }
}
@Test func darkenLightenCenterValidation() async throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("Validation/TestArtifacts"),full:true)
    do {
        try lab.dlcGeometry()
        try await lab.dlcIntegration()
        try lab.dlcPerformance()
        try lab.dlcPhotos()
    } catch {
        var c=LabCase(name:"DLC_harness");c.check("Completed",false,hard:true,String(describing:error));lab.cases.append(c)
        try lab.dlcReport();throw error
    }
    try lab.dlcReport()
    for c in lab.cases {for check in c.checks where check.hard {#expect(check.status != "FAIL","\(c.name) / \(check.name)")}}
}
extension LumoraVisualTestLab {
    func dlc(_ values:[String:Double]=[:])->CreativeEffect {effect(.darkenLightenCenter,values)}
    func dlcPreset(_ title:String)->CreativeEffect {CreativeFXPreset.all(for:.darkenLightenCenter).first{$0.title==title}!.makeEffect()}
    func dlcFlat(_ width:Int,_ height:Int,_ y:Double=0.18)->CIImage {
        CIImage(color:CIColor(red:y,green:y,blue:y,colorSpace:gpu.linear)!).cropped(to:CGRect(x:0,y:0,width:width,height:height))
    }
    // Independent double precision reference, pixel centers in top-left image coordinates.
    func dlcEV(x:Double,y:Double,width:Double,height:Double,fx:CreativeEffect)->Double {
        let scale=min(width,height),dx=(x-fx["centerX"]*width)/scale,dy=(y-fx["centerY"]*height)/scale
        let angle=fx["rotation"]*Double.pi/180,a=pow(2,fx["shape"]/100),r=fx["size"]/100
        let xx=(dx*cos(angle)+dy*sin(angle))/(r*a),yy=(-dx*sin(angle)+dy*cos(angle))/(r/a)
        let distance=sqrt(xx*xx+yy*yy),width=0.15+0.0085*fx["feather"]
        let t=min(1,max(0,(distance-1+width)/width))
        let mask=1-(6*pow(t,5)-15*pow(t,4)+10*pow(t,3))
        return fx["borderEV"]+(fx["centerEV"]-fx["borderEV"])*mask
    }
    func dlcSheet(_ name:String,_ inputs:[(String,CIImage)],_ configs:[(String,[String:Double])]) throws {
        var items:[(String,CIImage)]=[]
        for (label,input) in inputs {for (title,values) in configs {items.append((label+" / "+title,try render(input,[dlc(values)])))}}
        try artifacts.sheet(items,"DarkenLightenCenter/"+name+".png",cell:384,maxColumns:min(5,max(1,configs.count)))
    }
    func dlcGeometry() throws {
        progress("DLC: geometric oracle, aspect/rotation/extent, signed HDR and identities")
        let dimensions=[(768,512),(512,768),(512,512)],flat=dlcFlat(512,512)
        var c=LabCase(name:"DLC_geometry_oracle"),rows:[[String:Double]]=[]
        for (w,h) in dimensions {for shape in [-100.0,0,100] {for angle in [0.0,37,90,173] {
            let fx=dlc(["centerEV":1,"borderEV":-1,"centerX":0.3731,"centerY":0.4273,"size":38,"shape":shape,"rotation":angle])
            let p=silverPixels(try render(dlcFlat(w,h),[fx]));var error=0.0
            for y in stride(from:0,to:h,by:7) {for x in stride(from:0,to:w,by:7) {
                let ev=dlcEV(x:Double(x)+0.5,y:Double(y)+0.5,width:Double(w),height:Double(h),fx:fx)
                error=max(error,abs(Double(p[(y*w+x)*4])-0.18*pow(2,ev)))
            }}
            c.check("\(w)x\(h)/\(shape)/\(angle)",error<3e-6,hard:true,"Independent Float64 spatial oracle, pixel centers and top-left coordinates")
            rows.append(["width":Double(w),"height":Double(h),"centerX":fx["centerX"],"centerY":fx["centerY"],"size":fx["size"],"shape":shape,"rotation":angle,"feather":fx["feather"],"centerEV":1,"borderEV":-1,"maxRGBError":error])
        }}}
        try artifacts.json(rows,"DarkenLightenCenter/geometry_table.json");cases.append(c)
        var identities=LabCase(name:"DLC_identity_EV_HDR_color")
        let color=SilverBWTestChart.generate(size:256).image
        for size in [5.0,45,150] {for shape in [-100.0,0,100] {
            let base=["size":size,"shape":shape,"centerX":0.1,"centerY":0.9,"rotation":73.0,"feather":0.0]
            for key in ["neutral","amount"] {
                var vals=base
                if key=="amount" {vals["amount"]=0;vals["centerEV"]=2;vals["borderEV"] = -2}
                let m=gpu.compare(color,try render(color,[dlc(vals)]))
                identities.check("\(key)/\(size)/\(shape)",m.maxError==0,hard:true,"Strict input return")
            }
            for ev in [-2.0,-1,0,1,2] {
                var vals=base;vals["centerEV"]=ev;vals["borderEV"]=ev
                let out=try render(color,[dlc(vals)]),reference=color.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:ev]),m=gpu.compare(reference,out)
                identities.metrics["equalEV/\(ev)/\(size)/\(shape)-maxError"]=m.maxError
                identities.check("Equal EV \(ev)/\(size)/\(shape)",m.maxError<2e-6,hard:true,"Matches global linear exposure regardless of geometry")
            }
        }}
        let fx=dlc(["centerEV":2,"borderEV":-2,"size":35,"feather":50])
        for value in [-0.05,-0.01,-0.001,0,0.1,0.5,1,2,4,8] {
            let source=dlcFlat(512,512,value),out=silverPixels(try render(source,[fx]))
            let center=Double(out[(256*512+256)*4]),border=Double(out[0])
            identities.check("HDR / signed \(value)",out.allSatisfy(\.isFinite) && abs(center-value*4)<2e-5 && abs(border-value/4)<2e-5,hard:true,"Exact ×4 / ×.25 at plateaus; signed RGB, no clamp")
        }
        let coloredOut=try render(color,[fx]),a=silverPixels(color),b=silverPixels(coloredOut)
        var drift=0.0
        for i in stride(from:0,to:a.count,by:4) {
            let sa=Double(a[i]+a[i+1]+a[i+2]),sb=Double(b[i]+b[i+1]+b[i+2])
            if sa>1e-6 && sb>1e-6 {for k in 0..<3 {drift=max(drift,abs(Double(a[i+k])/sa-Double(b[i+k])/sb))}}
        }
        identities.metrics["maxChromaticityDrift"]=drift
        identities.check("Color preserved",drift<2e-6,hard:true,"RGB normalized ratios before any display clipping/gamut mapping")
        for amount in [0.0,25,50,75,100] {
            var partial=fx;partial["amount"]=amount
            let reference=try FXBlend.mix(color,coloredOut,amount:amount/100)
            identities.check("Amount \(amount)",gpu.compare(reference,try render(color,[partial])).maxError<2e-6,hard:true,"Final linear blend, not EV interpolation")
        }
        identities.check("Deterministic",gpu.compare(coloredOut,try render(color,[fx])).maxError==0,hard:true,"Same immutable geometry")
        cases.append(identities)
        var invariant=LabCase(name:"DLC_circle_symmetry_extent_crop")
        let circle=dlc(["centerEV":1,"borderEV":-1,"size":38]),original=try render(flat,[circle])
        for angle in [0.0,37,90,173] {
            var rotated=circle;rotated["rotation"]=angle
            invariant.check("Circle rotation \(angle)",gpu.compare(original,try render(flat,[rotated])).maxError==0,hard:true,"Circle canonical rotation")
        }
        let p=silverPixels(original);var mirror=0.0,radial=0.0
        for y in 0..<512 {for x in 0..<512 {
            mirror=max(mirror,Double(abs(p[(y*512+x)*4]-p[(y*512+511-x)*4])),Double(abs(p[(y*512+x)*4]-p[((511-y)*512+x)*4])))
            radial=max(radial,Double(abs(p[(y*512+x)*4]-p[(x*512+y)*4])))
        }}
        invariant.check("Mirror and axis symmetry",max(mirror,radial)<2e-6,hard:true,"Horizontal, vertical, diagonal; implies 180 degree symmetry")
        let tall=dlc(["centerEV":1,"borderEV":-1,"shape":-65,"rotation":0]),wide=dlc(["centerEV":1,"borderEV":-1,"shape":65,"rotation":90])
        invariant.check("Ellipse 90 axes exchange",gpu.compare(try render(flat,[tall]),try render(flat,[wide])).maxError<2e-6,hard:true,"Reciprocal axes at constant ellipse area")
        let translation=CGAffineTransform(translationX:137,y:-92)
        let shifted=try render(flat.transformed(by:translation),[circle]).transformed(by:translation.inverted())
        invariant.check("Translated extent",gpu.compare(original,shifted).maxError<2e-6,hard:true,"Integer nonzero CI extent, same local geometry")
        // CI rounds a fractional transformed extent outward. Compare to that actual
        // incoming frame, not the original size (which is no longer 512 square).
        let fractional=flat.transformed(by:CGAffineTransform(translationX:137.25,y:-91.75))
        let fp=silverPixels(try render(fractional,[circle])),fe=fractional.extent,fw=Int(fe.width),fh=Int(fe.height)
        var fractionalError=0.0
        for y in stride(from:3,to:fh-3,by:7) {for x in stride(from:3,to:fw-3,by:7) {
            let expected=0.18*pow(2,dlcEV(x:Double(x)+0.5,y:Double(y)+0.5,width:fe.width,height:fe.height,fx:circle))
            fractionalError=max(fractionalError,abs(Double(fp[(y*fw+x)*4])-expected))
        }}
        invariant.metrics["fractionalExtentOracleMaxError"]=fractionalError
        invariant.check("Fractional extent actual-frame oracle",fractionalError<2e-6,hard:true,"CI rounds transformed bounds to 513×513; interior avoids resampled source alpha boundary")
        let crop=CGRect(x:100,y:70,width:300,height:250)
        let cropBefore=try render(flat.cropped(to:crop),[circle]),cropAfter=original.cropped(to:crop)
        invariant.check("Crop semantics",gpu.compare(cropBefore,cropAfter).mae>0.001,hard:true,"DLC uses its incoming extent; crop before and after have different frames")
        try artifacts.sheet([("Crop → DLC",cropBefore),("DLC → Crop",cropAfter)],"DarkenLightenCenter/crop_semantics.png",cell:384,maxColumns:2)
        cases.append(invariant)
        try dlcProfilesAndViews()
    }
    func dlcProfilesAndViews() throws {
        let gray=dlcFlat(768,512),chart=DarkenLightenCenterTestChart.image()
        let base=["centerEV":1.0,"borderEV":-1.0]
        func config(_ extra:[String:Double])->[String:Double] {base.merging(extra){_,b in b}}
        let positions=[(0.5,0.5),(0.25,0.25),(0.75,0.25),(0.25,0.75),(0.75,0.75),(0.01,0.5),(0.99,0.5),(0.5,0.01),(0.5,0.99),(0.01,0.01)]
        let moves=positions.map{x,y in ("\(x),\(y)",config(["centerX":x,"centerY":y]))}
        try dlcSheet("center_positions",[("Grid",chart)],moves)
        try dlcSheet("edge_center_positions",[("Grid",chart)],Array(moves.suffix(5)))
        try dlcSheet("circle_aspect_ratio",[("Landscape",chart),("Portrait",DarkenLightenCenterTestChart.image(width:512,height:768)),("Square",DarkenLightenCenterTestChart.image(width:512,height:512))],[("Circle",config(["shape":0]))])
        try dlcSheet("ellipse_shapes",[("Grid",chart)],[-100.0,0,100].map{("Shape \($0)",config(["shape":$0]))})
        try dlcSheet("rotation",[("Grid",chart)],[0.0,30,45,90,135].map{("Rotation \($0)",config(["shape":60,"rotation":$0]))})
        try dlcSheet("feather_response",[("Uniform",gray)],[0.0,25,50,75,100].map{("Feather \($0)",config(["feather":$0]))})
        try dlcSheet("center_border_independence",[("Uniform",gray)],[("+1 / 0",["centerEV":1]),("0 / −1",["borderEV":-1]),("+1 / −1",base),("−1 / +1",["centerEV":-1,"borderEV":1])])
        try dlcSheet("amount_response",[("Grid",chart)],[0.0,25,50,75,100].map{("Amount \($0)",config(["amount":$0]))})
        try dlcSheet("center_equals_border",[("Grid",chart)],[-1.0,1].map{("Equal EV \($0)",["centerEV":$0,"borderEV":$0])})
        try dlcSheet("extreme_field_diagnostic",[("Uniform",gray)],[("Diagnostic only",["centerEV":2,"borderEV":-2,"shape":65,"rotation":37,"feather":50])])
        let subtle=try render(gray,[dlc(["centerEV":0.1,"borderEV":-0.1,"size":90,"shape":50,"feather":100])])
        try artifacts.sheet([("Original",gray),("±0.1 EV",subtle),("Difference ×16",artifacts.difference(gray,subtle,gain:16))],"DarkenLightenCenter/subtle_field_difference.png",cell:384,maxColumns:3)
        var c=LabCase(name:"DLC_profiles_subpixel_viewport"),series:[(String,[Double])]=[]
        // Materialize only one scanline from a square 4096² graph: full frame geometry retained.
        for feather in [0.0,25,50,75,100] {
            let fx=dlc(["centerEV":1,"borderEV":-1,"feather":feather,"size":35])
            let output=try render(dlcFlat(4096,4096),[fx]),pixels=gpu.read(output,CGRect(x:0,y:2048,width:4096,height:1))
            let ev=stride(from:0,to:pixels.count,by:4).map{log2(Double(pixels[$0])/0.18)}
            let d1=zip(ev.dropFirst(),ev).map(-),d2=zip(d1.dropFirst(),d1).map(-)
            c.metrics["feather\(feather)-maxFirstDifference"]=d1.map(abs).max()!
            c.metrics["feather\(feather)-maxSecondDifference"]=d2.map(abs).max()!
            c.check("Smooth \(feather)",d1.map(abs).max()!<0.025 && d2.map(abs).max()!<0.001,hard:true,"4096 spatial profile; bounded first/second differences, C2 plateaus")
            c.check("No overshoot \(feather)",ev.min()! > -1.00001 && ev.max()!<1.00001,hard:true,"EV remains between Center and Border")
            series.append(("Feather \(feather)",ev))
            try artifacts.json(["EV":ev,"firstDifference":d1,"secondDifference":d2],"DarkenLightenCenter/profile_\(Int(feather)).json")
        }
        try artifacts.plot(series,"DarkenLightenCenter/feather_profiles.png",title:"EV profile through center",xMaximum:4096)
        // Sample GPU on a 1024 square along the four radial rays; nearest sampling has a bounded footprint.
        let circle=dlc(["centerEV":1,"borderEV":-1,"size":35]),p=silverPixels(try render(dlcFlat(1024,1024),[circle]))
        var rays:[(String,[Double])]=[]
        for degrees in [0.0,45,90,135] {
            var values:[Double]=[],error=0.0
            for r in 0..<450 {
                let angle=degrees*Double.pi/180,x=Int((511.5+Double(r)*cos(angle)).rounded()),y=Int((511.5+Double(r)*sin(angle)).rounded())
                let ev=log2(Double(p[(y*1024+x)*4])/0.18);values.append(ev)
                let reference=dlcEV(x:512+Double(r),y:512,width:1024,height:1024,fx:circle)
                error=max(error,abs(ev-reference))
            }
            c.metrics["radial\(degrees)-maxEVError"]=error
            c.check("Radial \(degrees)",error<0.015,hard:true,"Nearest GPU sampling footprint <= .71 px; reference exact radial distance")
            rays.append(("\(degrees)°",values))
        }
        try artifacts.plot(rays,"DarkenLightenCenter/radial_profiles.png",title:"GPU circle radial EV profiles",xMaximum:449)
        var steps:[Double]=[]
        for i in 0..<6 {
            var fx=circle;fx["centerX"]=0.3731+Double(i)*0.001
            let values=silverPixels(try render(dlcFlat(512,512),[fx]))
            var sum=0.0,moment=0.0
            for y in 0..<512 {for x in 0..<512 {let weight=max(0,log2(Double(values[(y*512+x)*4])/0.18)+1);sum+=weight;moment+=weight*(Double(x)+0.5)}}
            let actual=moment/sum/512;steps.append(actual)
            c.metrics["subpixel\(i)-centerError"]=abs(actual-fx["centerX"])
            c.check("Subpixel \(i)",abs(actual-fx["centerX"])<0.00001,hard:true,"Weighted EV centroid, normalized error <1e-5 (0.00512px)")
        }
        c.check("Continuous displacement",zip(steps.dropFirst(),steps).allSatisfy{abs(($0-$1)-0.001)<1e-5},hard:true,"No quantization to preview pixels")
        for view in [CGSize(width:390,height:340),CGSize(width:844,height:300),CGSize(width:768,height:900)] {
            for zoom in [1.0,2,5] {for image in [CGSize(width:1600,height:900),CGSize(width:900,height:1600)] {
                let viewport=DLCViewport(image:image,view:view,zoom:zoom,pan:CGSize(width:47,height:-31))
                let point=CGPoint(x:0.3731,y:0.4273),roundtrip=viewport.normalized(viewport.screen(point))
                c.check("UI roundtrip \(view)/\(zoom)/\(image)",hypot(roundtrip.x-point.x,roundtrip.y-point.y)<1e-12,hard:true,"Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates")
            }}
        }
        cases.append(c)
        try dlcDiagnosticFields(gray)
    }
    func dlcDiagnosticFields(_ input:CIImage) throws {
        let configs:[(String,[String:Double])]=[("Circle",[:]),("Wide",["shape":65]),("Rotated",["shape":65,"rotation":37]),("Off-center",["centerX":0.25,"centerY":0.35]),("Reverse",["centerEV":-1,"borderEV":1])]
        var fields:[(String,CIImage)]=[],isolines:[(String,CIImage)]=[]
        for (name,values) in configs {
            let fx=dlc(["centerEV":1,"borderEV":-1].merging(values){_,b in b})
            let output=try render(input,[fx]),pixels=silverPixels(output),w=Int(input.extent.width),h=Int(input.extent.height)
            func diagnostic(_ lines:Bool)->CIImage {
                var p=pixels
                for i in stride(from:0,to:p.count,by:4) {
                    let ev=log2(Double(pixels[i])/0.18),t=(ev+1)/2
                    let line=abs((ev*4).rounded()-ev*4)<0.04
                    p[i]=Float(lines && line ? 1:max(0,ev));p[i+1]=Float(lines && line ? 1:0.15+0.25*(1-abs(ev)));p[i+2]=Float(lines && line ? 1:1-t)
                }
                return CIImage(bitmapData:p.withUnsafeBytes{Data($0)},bytesPerRow:w*16,size:CGSize(width:w,height:h),format:.RGBAf,colorSpace:gpu.linear)
            }
            fields.append((name+" blue=−1 / red=+1 EV",diagnostic(false)));isolines.append((name+" 0.25 EV contours",diagnostic(true)))
        }
        try artifacts.sheet(fields,"DarkenLightenCenter/ev_field_map.png",cell:384,maxColumns:5)
        try artifacts.sheet(isolines,"DarkenLightenCenter/ev_field_isolines.png",cell:384,maxColumns:5)
    }
}
