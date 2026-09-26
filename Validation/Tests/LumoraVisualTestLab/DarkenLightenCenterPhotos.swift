import Foundation
import CoreImage
import CryptoKit
import CoreGraphics
import CoreText
@testable import LumoraCore

extension LumoraVisualTestLab {
    private func dlcPhotoRegions(_ index:Int)->[(String,Double,Double)] {
        switch index {
        case 0:return [("skin",0.38,0.52),("eye",0.40,0.62),("lips",0.30,0.43),("hair",0.48,0.83),("bright background",0.8,0.8),("transition",0.65,0.5)]
        case 1:return [("skin",0.47,0.54),("eyes",0.46,0.68),("hair",0.65,0.52),("dark clothing",0.74,0.20),("background",0.85,0.7),("transition",0.7,0.6)]
        case 2:return [("clouds",0.61,0.78),("blue sky",0.30,0.92),("green landscape",0.50,0.30),("rocks",0.35,0.10)]
        case 3:return [("sun",0.65,0.70),("hair",0.25,0.57),("face",0.45,0.72),("sea reflection",0.69,0.48),("shoulder",0.45,0.45)]
        case 4:return [("lamp",0.36,0.78),("sky",0.62,0.75),("stone",0.23,0.66),("wet pavement",0.55,0.17)]
        case 5:return [("dark interior",0.30,0.59),("sunlit wall",0.75,0.72),("wood table",0.56,0.33),("window",0.92,0.78)]
        case 6:return [("white dress",0.37,0.43),("white wall",0.90,0.43),("skin",0.44,0.73),("blue sky",0.75,0.81),("transition",0.65,0.5)]
        default:return [("skin",0.38,0.59),("hair",0.24,0.57),("fabric",0.36,0.40),("water",0.78,0.45)]
        }
    }
    private func dlcPhotoCrop(_ image:CIImage,x:Double,y:Double,side:Int=384)->CIImage {
        let e=image.extent,s=min(CGFloat(side),e.width,e.height)
        let xx=min(e.maxX-s,max(e.minX,e.minX+e.width*x-s/2)),yy=min(e.maxY-s,max(e.minY,e.minY+e.height*y-s/2))
        return image.cropped(to:CGRect(x:floor(xx),y:floor(yy),width:s,height:s))
    }
    func dlcPhotos() throws {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let files=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("Validation/VisualTestAssets"),includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count==8 else {throw LabError.configuration}
        let presets=CreativeFXPreset.all(for:.darkenLightenCenter),n=presets.count
        let centers:[CGPoint]=[.init(x:0.37,y:0.45),.init(x:0.45,y:0.44),.init(x:0.5,y:0.65),.init(x:0.4,y:0.4),.init(x:0.45,y:0.68),.init(x:0.56,y:0.67),.init(x:0.42,y:0.47),.init(x:0.35,y:0.45)]
        let names=["portrait_light","portrait_dark","landscape","backlight","night","indoor","white_subject","fine_texture"]
        var photoMatrix=Array(repeating:Array(repeating:0.0,count:n),count:n),offCenter:[(String,CIImage)]=[],composition:[(String,CIImage)]=[]
        var hashes:[String:String]=[:],photoStats:[String:[String:Double]]=[:],configuration:[String:CreativeEffect]=[:]
        for (index,file) in files.enumerated() {
            progress("DLC photograph \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard let input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
                let hash=SHA256.hash(data:try Data(contentsOf:file)).map{String(format:"%02x",$0)}.joined();hashes[file.lastPathComponent]=hash
                let root="DarkenLightenCenter/RealPhotos/"+file.deletingPathExtension().lastPathComponent,regions=dlcPhotoRegions(index),reference=silverFullFrame(input,side:512)
                var c=LabCase(name:"DLC_photo_"+names[index]),contact:[(String,CIImage)]=[("Original",input)],samples:[CIImage]=[],custom:[(String,CIImage)]=[("Original",input)],diffs:[(String,CIImage)]=[]
                for preset in presets {
                    let output=try render(input,[preset.makeEffect()]),sample=silverFullFrame(output,side:512)
                    contact.append((preset.title,output));samples.append(sample)
                    let stats=dlcPhotoStatistics(reference,sample)
                    photoStats[file.lastPathComponent+" / "+preset.title]=stats
                    c.check(preset.title+" finite",stats["nonFinitePixels"]==0,hard:true,"Full-frame float sample")
                    c.check(preset.title+" new clipping",stats["newClippedFraction"]!<0.02,"Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation")
                    if ["Subtle Focus","Portrait Focus","Dark Surround","Reverse Focus"].contains(preset.title) {
                        diffs.append((preset.title+" / difference ×4",artifacts.difference(input,output,gain:4)))
                    }
                    var positioned=preset.makeEffect();positioned["centerX"]=centers[index].x;positioned["centerY"]=centers[index].y
                    if index==2 && preset.title=="Wide Focus" {positioned["size"]=80;positioned["shape"]=65;positioned["rotation"] = -8}
                    let focused=try render(input,[positioned]);custom.append((preset.title,focused))
                    configuration[file.lastPathComponent+" / "+preset.title]=positioned
                    photoStats[file.lastPathComponent+" / positioned "+preset.title]=dlcPhotoStatistics(reference,silverFullFrame(focused,side:512))
                    for (label,x,y) in regions {
                        let a=dlcPhotoCrop(input,x:x,y:y,side:128),b=dlcPhotoCrop(focused,x:x,y:y,side:128),stat=dlcPhotoStatistics(a,b)
                        for k in ["clippedFraction","inputClippedFraction","newClippedFraction","shadowRMS","chromaticityDrift"] {c.metrics[preset.title+" / "+label+" / "+k]=stat[k]}
                        c.check(preset.title+" / "+label+" hue",stat["chromaticityDrift"]!<2e-6,hard:true,"Native ROI RGB ratios before gamut conversion; DLC is not a color effect")
                    }
                }
                var crops:[(String,CIImage)]=[]
                for (label,x,y) in regions {for (title,out) in custom {crops.append((title+" / "+label,dlcPhotoCrop(out,x:x,y:y)))}}
                try artifacts.sheet(contact,root+"/contact_sheet.png",cell:512,maxColumns:3)
                try artifacts.sheet(custom+crops,root+"/"+names[index]+"_focus_comparison.png",cell:384,maxColumns:9)
                try artifacts.sheet(diffs,root+"/difference_maps.png",cell:384,maxColumns:4)
                if index==2 {
                    try artifacts.sheet(custom.map{($0.0+" / sky",dlcPhotoCrop($0.1,x:0.5,y:0.82,side:512))},root+"/landscape_sky_transition.png",nativeCrop:true,cell:512,maxColumns:3)
                }
                if [0,2,6].contains(index) {
                    var focused=dlcPreset("Subtle Focus");focused["centerX"]=centers[index].x;focused["centerY"]=centers[index].y;focused["centerEV"]=0.25;focused["borderEV"] = -0.4;focused["size"]=index==2 ? 80:50;focused["shape"]=index==2 ? 55:-25
                    configuration[file.lastPathComponent+" / composition"]=focused
                    let out=try render(input,[focused])
                    composition += [(names[index]+" Original",silverFullFrame(input,side:512)),("Subtle Focus",silverFullFrame(try render(input,[dlcPreset("Subtle Focus")]),side:512)),("Fixed subject center",silverFullFrame(out,side:512))]
                    offCenter += [(names[index]+" Original",silverFullFrame(input,side:512)),("Centered same settings",silverFullFrame(try render(input,[dlc(["centerEV":0.25,"borderEV":-0.4,"size":focused["size"],"shape":focused["shape"],"feather":focused["feather"]])]),side:512)),("Subject \(centers[index].x),\(centers[index].y)",silverFullFrame(out,side:512))]
                }
                for i in 0..<n {for j in 0..<i {let d=gpu.compare(samples[i],samples[j]).mae;photoMatrix[i][j]+=d/8;photoMatrix[j][i]+=d/8}}
                c.check("Source unchanged",hash==SHA256.hash(data:try Data(contentsOf:file)).map{String(format:"%02x",$0)}.joined(),hard:true,"Original SHA256 before/after")
                c.notes=["Fixed top-left subject coordinates: \(centers[index]). Native ROIs use lower-left image coordinates. No face detection or automated subject placement."]
                c.images=[root+"/contact_sheet.png",root+"/"+names[index]+"_focus_comparison.png"]
                cases.append(c)
            }
        }
        try artifacts.sheet(offCenter,"DarkenLightenCenter/off_center_real_photos.png",cell:512,maxColumns:3)
        try artifacts.sheet(composition,"DarkenLightenCenter/compositional_examples.png",cell:512,maxColumns:3)
        try artifacts.json(hashes,"DarkenLightenCenter/source_hashes.json")
        try artifacts.json(photoStats,"DarkenLightenCenter/photo_statistics.json")
        try artifacts.json(configuration,"DarkenLightenCenter/fixed_photo_settings.json")
        var matrices=["photos":photoMatrix],diversity=LabCase(name:"DLC_preset_diversity")
        for (name,input) in [("uniform",dlcFlat(512,512)),("geometric",DarkenLightenCenterTestChart.image(width:512,height:512))] {
            let outputs=try presets.map{try render(input,[$0.makeEffect()])};var matrix=photoMatrix
            for i in 0..<n {for j in 0..<n {matrix[i][j]=gpu.compare(outputs[i],outputs[j]).mae}}
            matrices[name]=matrix
        }
        for i in 0..<n {for j in 0..<i {
            let d=photoMatrix[i][j],s=matrices["uniform"]![i][j]
            diversity.metrics[presets[i].title+" / "+presets[j].title+"-photoMAE"]=d
            diversity.check(presets[i].title+" / "+presets[j].title,presets[i].title=="Subtle Focus" || presets[j].title=="Subtle Focus" || d>0.003 || s>0.003,"WARN only for non-subtle looks close on photos and uniform chart; no tuning")
        }}
        try artifacts.json(matrices,"DarkenLightenCenter/preset_distances.json")
        try artifacts.json(presets.map(\.title),"DarkenLightenCenter/preset_labels.json")
        let plot=(0..<n).map{i in (presets[i].title,photoMatrix[i])}
        try artifacts.plot(plot,"DarkenLightenCenter/preset_distance_matrix.png",title:"Preset distances / eight-photo RGB MAE",xMaximum:7)
        cases.append(diversity)
        let chart=DarkenLightenCenterTestChart.image(),vignette=try render(chart,[dlc(["centerEV":0,"borderEV":-0.7,"centerX":0.5,"centerY":0.5,"shape":0])])
        var items:[(String,CIImage)]=[]
        for (label,values) in [("Off center",["centerX":0.25,"centerY":0.35,"borderEV":-0.7]),("Center only",["centerEV":0.5,"borderEV":0]),("Reverse",["centerEV":-0.5,"borderEV":0.3])] {
            items += [("Original",chart),("Simple centered radial darkening",vignette),(label,try render(chart,[dlc(values)]))]
        }
        try artifacts.sheet(items,"DarkenLightenCenter/not_just_a_vignette.png",cell:512,maxColumns:3)
    }
    func dlcPhotoStatistics(_ input:CIImage,_ output:CIImage)->[String:Double] {
        let a=silverPixels(input),b=silverPixels(output);var ys:[Double]=[],shadow=Moments(),clipped=0,inputClipped=0,newClipped=0,black=0,nonfinite=0,drift=0.0
        for i in stride(from:0,to:a.count,by:4) {
            guard (0..<4).allSatisfy({b[i+$0].isFinite}) else {nonfinite+=1;continue}
            let y=LabGPU.luma(b,i),old=LabGPU.luma(a,i);ys.append(y)
            if old<0.1 {shadow.add(y)}
            let before=(0..<3).contains{a[i+$0]>=1},after=(0..<3).contains{b[i+$0]>=1}
            if before {inputClipped+=1};if after {clipped+=1};if after && !before {newClipped+=1};if y<=1e-6 {black+=1}
            let sa=Double(a[i]+a[i+1]+a[i+2]),sb=Double(b[i]+b[i+1]+b[i+2])
            if sa>1e-6 && sb>1e-6 {for k in 0..<3 {drift=max(drift,abs(Double(a[i+k])/sa-Double(b[i+k])/sb))}}
        }
        ys.sort();let count=Double(max(1,ys.count))
        func percentile(_ q:Double)->Double {ys.isEmpty ? 0:ys[Int(Double(ys.count-1)*q)]}
        return ["meanLuminance":ys.reduce(0,+)/count,"P01":percentile(0.01),"P05":percentile(0.05),"P50":percentile(0.5),"P95":percentile(0.95),"clippedFraction":Double(clipped)/count,"inputClippedFraction":Double(inputClipped)/count,"newClippedFraction":Double(newClipped)/count,"blackClippedFraction":Double(black)/count,"shadowRMS":shadow.standardDeviation,"chromaticityDrift":drift,"nonFinitePixels":Double(nonfinite)]
    }
}
