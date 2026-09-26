import Foundation
import CoreImage
import CryptoKit
import CoreGraphics
import CoreText
@testable import LumoraCore

extension LumoraVisualTestLab {
    private func silverPhotoRegions(_ index:Int)->[(String,Double,Double)] {
        switch index {
        case 0:return [("skin",0.38,0.52),("eye",0.40,0.62),("lips",0.30,0.43),("hair",0.48,0.83)]
        case 1:return [("skin",0.47,0.54),("eyes",0.46,0.68),("hair",0.65,0.52),("dark clothing",0.74,0.20)]
        case 2:return [("clouds",0.61,0.78),("blue sky",0.30,0.92),("green landscape",0.50,0.30),("rocks",0.35,0.10)]
        case 3:return [("sun",0.65,0.70),("hair",0.25,0.57),("face",0.45,0.72),("sea reflection",0.69,0.48)]
        case 4:return [("lamp",0.36,0.78),("sky",0.62,0.75),("stone",0.23,0.66),("wet pavement",0.55,0.17)]
        case 5:return [("dark interior",0.30,0.59),("sunlit wall",0.75,0.72),("wood table",0.56,0.33),("window",0.92,0.78)]
        case 6:return [("white dress",0.37,0.43),("white wall",0.90,0.43),("skin",0.44,0.73),("blue sky",0.75,0.81)]
        default:return [("skin",0.38,0.59),("hair",0.24,0.57),("fabric",0.36,0.40),("water",0.78,0.45)]
        }
    }
    private func silverPhotoCrop(_ image:CIImage,x:Double,y:Double,side:Int=384)->CIImage {
        let e=image.extent,s=min(CGFloat(side),e.width,e.height)
        let xx=min(e.maxX-s,max(e.minX,e.minX+e.width*x-s/2)),yy=min(e.maxY-s,max(e.minY,e.minY+e.height*y-s/2))
        return image.cropped(to:CGRect(x:floor(xx),y:floor(yy),width:s,height:s))
    }
    func silverPhotographs(_ chart:SilverBWTestChart) throws {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder=repo.appendingPathComponent("Validation/VisualTestAssets")
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
            .filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count==8 else {throw LabError.configuration}
        let presets=CreativeFXPreset.all(for:.silverBW),titles=presets.map(\.title)
        let chartInput=silverFullFrame(chart.image,side:512)
        let synthetic=try presets.map{try render(chartInput,[$0.makeEffect()])}
        var matrix=Array(repeating:Array(repeating:0.0,count:8),count:8)
        var structureItems:[(String,CIImage)]=[],global:[(String,CIImage)]=[]
        var sourceHashes:[String:String]=[:]
        let names=["portrait_silver_comparison.png","portrait_silver_comparison.png","landscape_silver_comparison.png",
                   "backlight_silver_comparison.png","night_silver_comparison.png","indoor_silver_comparison.png",
                   "white_subject_silver_comparison.png","fine_texture_silver_comparison.png"]
        for (index,file) in files.enumerated() {
            progress("Silver B&W photograph \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                let hash=SHA256.hash(data:try Data(contentsOf:file)).map{String(format:"%02x",$0)}.joined()
                sourceHashes[file.lastPathComponent]=hash
                guard var input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
                input=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,y:-input.extent.minY))
                let root="SilverBW/RealPhotos/"+file.deletingPathExtension().lastPathComponent
                let regions=silverPhotoRegions(index)
                var outputs:[CIImage]=[],samples:[CIImage]=[],contact:[(String,CIImage)]=[("Original",input)]
                var crops:[(String,CIImage)]=[],c=LabCase(name:"SBW_photo_"+file.deletingPathExtension().lastPathComponent)
                c.notes=["Original source unchanged (SHA256 recorded). All metrics in linear sRGB. Full frame scaled by long edge, no portrait cropping or transparent padding.",
                         "Native 384px crops; 128px measurement ROIs. Lower-left coordinates: "+regions.map{"\($0.0)=(\($0.1),\($0.2))"}.joined(separator:", ")]
                let reference=silverFullFrame(input,side:512)
                for preset in presets {
                    let fx=preset.makeEffect(),output=try render(input,[fx]),sample=silverFullFrame(output,side:512)
                    outputs.append(output);samples.append(sample);contact.append((preset.title,output))
                    let key=preset.title.lowercased().replacingOccurrences(of:" ",with:"_")
                    try artifacts.png(output,root+"/"+key+".png")
                    try artifacts.json(fx,root+"/"+key+"_settings.json")
                    let m=gpu.compare(reference,sample),p=silverPixels(sample)
                    c.metrics[key+"-meanY"]=m.output.mean;c.metrics[key+"-meanDeltaY"]=m.residual.mean
                    c.metrics[key+"-clippedFraction"]=Double(m.whiteOutput)/Double(max(1,m.output.count))
                    c.metrics[key+"-blackFraction"]=Double(m.blackOutput)/Double(max(1,m.output.count))
                    c.metrics[key+"-maxChannelDifference"]=silverNeutralError(p)
                    c.check(preset.title+" finite/neutral",m.nonFinite==0 && silverNeutralError(p)<2e-6,hard:true,"512px full-frame RGBAf")
                    for (name,x,y) in regions {
                        let a=silverPhotoCrop(input,x:x,y:y,side:128),b=silverPhotoCrop(output,x:x,y:y,side:128),regionMetric=gpu.compare(a,b)
                        c.metrics[key+" / "+name+" / meanY"]=regionMetric.output.mean
                        c.metrics[key+" / "+name+" / RMS"]=regionMetric.output.standardDeviation
                        if index<2 && name=="skin" {
                            c.check(preset.title+" skin separation",regionMetric.output.standardDeviation>0.4*regionMetric.input.standardDeviation,
                                    "Skin ROI tonal variation retained; photographic quality heuristic, not face processing")
                        }
                    }
                    global.append((file.deletingPathExtension().lastPathComponent+" "+preset.title,silverFullFrame(output,side:192)))
                }
                for (name,x,y) in regions {
                    crops.append(("Original / "+name,silverPhotoCrop(input,x:x,y:y)))
                    for (i,preset) in presets.enumerated() {crops.append((preset.title+" / "+name,silverPhotoCrop(outputs[i],x:x,y:y)))}
                }
                for i in 0..<8 {for j in 0..<i {
                    let d=gpu.compare(samples[i],samples[j]).mae;matrix[i][j]+=d/8;matrix[j][i]+=d/8
                }}
                try artifacts.sheet(contact,root+"/SilverBW_contact_sheet.png",cell:512,maxColumns:3)
                try artifacts.sheet(crops,root+"/"+names[index],nativeCrop:true,cell:384,maxColumns:3)
                c.images=[root+"/SilverBW_contact_sheet.png",root+"/"+names[index]]
                if [0,1,2,6].contains(index) {
                    var filterItems:[(String,CIImage)]=[],filterCrops:[(String,CIImage)]=[]
                    let profile=index<2 ? 2.0:0.0
                    for (name,hue,strength) in [("No Filter",0.0,0.0),("Yellow",60,50),("Orange",30,50),("Red",0,50),("Green",120,50)] {
                        let output=try render(input,[silverFX(["filmResponse":profile,"filterHue":hue,"filterStrength":strength])])
                        filterItems.append((name,output))
                        for (region,x,y) in regions {
                            filterCrops.append((name+" / "+region,silverPhotoCrop(output,x:x,y:y)))
                            let b=silverPhotoCrop(output,x:x,y:y,side:128),m=gpu.compare(b,b)
                            c.metrics["filter "+name+" / "+region+" / meanY"]=m.output.mean
                        }
                    }
                    let path=root+(index==6 ? "/red_filter_comparison.png":"/color_filter_comparison.png")
                    // Each filter has its complete frame and all material crops.
                    try artifacts.sheet(filterItems+filterCrops,path,cell:384,maxColumns:5)
                    c.images.append(path)
                }
                // Five real materials, full-source structure radius, then native crops.
                let material:[Int:(String,Double,Double)]=[0:("skin",0.38,0.52),1:("hair",0.65,0.52),
                    2:("clouds",0.61,0.78),4:("stone",0.23,0.66),7:("fabric",0.36,0.40)]
                if let (label,x,y)=material[index] {
                    for strength in [0.0,25,50,75,100] {
                        let output=try render(input,[silverFX(["structure":strength])])
                        structureItems.append(("\(label) / Structure \(Int(strength))",silverPhotoCrop(output,x:x,y:y)))
                    }
                }
                let afterHash=SHA256.hash(data:try Data(contentsOf:file)).map{String(format:"%02x",$0)}.joined()
                c.check("Source unchanged",afterHash==hash,hard:true,"No modification of photographic corpus")
                cases.append(c)
            }
        }
        try artifacts.sheet(structureItems,"SilverBW/structure_comparison.png",nativeCrop:true,cell:384,maxColumns:5)
        try artifacts.sheet(global,"SilverBW/global_photo_contact_sheet.png",cell:192,maxColumns:8)
        try artifacts.json(sourceHashes,"SilverBW/source_hashes.json")
        var syntheticMatrix=Array(repeating:Array(repeating:0.0,count:8),count:8)
        var diversity=LabCase(name:"SBW_preset_diversity")
        for i in 0..<8 {for j in 0..<i {
            let d=gpu.compare(synthetic[i],synthetic[j]).mae
            syntheticMatrix[i][j]=d;syntheticMatrix[j][i]=d
            let key=titles[i]+" / "+titles[j]
            diversity.metrics[key+"-syntheticMAE"]=d;diversity.metrics[key+"-photoMAE"]=matrix[i][j]
            diversity.check(key+" synthetic",d>=0.004,"Shared preset diversity heuristic; no post-run tuning")
            diversity.check(key+" photos",matrix[i][j]>=0.004,"Mean of eight full-frame RGB MAEs")
        }}
        try silverMatrix(matrix,titles:titles,path:"SilverBW/preset_distance_matrix.png",title:"Eight-photo preset distance matrix")
        try silverMatrix(syntheticMatrix,titles:titles,path:"SilverBW/synthetic_preset_distance_matrix.png",title:"Synthetic preset distance matrix")
        try artifacts.json(["titles":titles],"SilverBW/preset_distance_labels.json")
        try artifacts.json(["photographic":matrix,"synthetic":syntheticMatrix],"SilverBW/preset_distances.json")
        cases.append(diversity)
    }
    private func silverMatrix(_ values:[[Double]],titles:[String],path:String,title:String) throws {
        let width=1050,height=840,cell=90,left=285,bottom=45
        guard let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {throw LabError.render}
        context.setFillColor(CGColor(gray:0.06,alpha:1));context.fill(CGRect(x:0,y:0,width:width,height:height))
        func label(_ text:String,_ x:Double,_ y:Double,_ size:Double,_ dark:Bool=false) {
            let attrs:[NSAttributedString.Key:Any]=[NSAttributedString.Key(kCTFontAttributeName as String):CTFontCreateWithName("Helvetica" as CFString,size,nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:dark ? 0.06:0.94,alpha:1)]
            context.textPosition=CGPoint(x:x,y:y)
            CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:attrs)),context)
        }
        label(title,35,800,25);label("Columns follow the numbered row order; linear RGB MAE",35,774,15)
        let maximum=max(0.00001,values.flatMap{$0}.max() ?? 1)
        for i in titles.indices {
            label("\(i+1). \(titles[i])",20,Double(bottom+(7-i)*cell+38),16)
            label("\(i+1)",Double(left+i*cell+40),756,16)
            for j in titles.indices {
                let v=values[i][j],q=sqrt(v/maximum)
                context.setFillColor(CGColor(red:0.08+0.18*q,green:0.12+0.66*q,blue:0.22+0.48*q,alpha:1))
                context.fill(CGRect(x:left+j*cell,y:bottom+(7-i)*cell,width:cell-2,height:cell-2))
                label(String(format:"%.4f",v),Double(left+j*cell+15),Double(bottom+(7-i)*cell+38),16,q>0.6)
            }
        }
        guard let image=context.makeImage() else {throw LabError.render}
        try artifacts.png(CIImage(cgImage:image),path)
    }

}
