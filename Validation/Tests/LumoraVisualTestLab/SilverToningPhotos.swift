import Foundation
import CoreImage
import CryptoKit
import CoreGraphics
import CoreText
@testable import LumoraCore

extension LumoraVisualTestLab {
    private func toningPhotoRegions(_ index:Int)->[(String,Double,Double)] {
        switch index {
        case 0:return [("skin",0.38,0.52),("eye",0.40,0.62),("lips",0.30,0.43),("hair",0.48,0.83),("bright background",0.8,0.8)]
        case 1:return [("skin",0.47,0.54),("eyes",0.46,0.68),("hair",0.65,0.52),("dark clothing",0.74,0.20),("highlight on skin",0.40,0.56),("lips",0.43,0.48)]
        case 2:return [("clouds",0.61,0.78),("blue sky",0.30,0.92),("green landscape",0.50,0.30),("rocks",0.35,0.10),("mountain",0.8,0.55)]
        case 3:return [("sun",0.65,0.70),("hair",0.25,0.57),("face",0.45,0.72),("sea reflection",0.69,0.48)]
        case 4:return [("lamp",0.36,0.78),("sky",0.62,0.75),("stone",0.23,0.66),("wet pavement",0.55,0.17)]
        case 5:return [("dark interior",0.30,0.59),("sunlit wall",0.75,0.72),("wood table",0.56,0.33),("white object",0.66,0.31)]
        case 6:return [("white dress",0.37,0.43),("white wall",0.90,0.43),("skin",0.44,0.73),("blue sky",0.75,0.81)]
        default:return [("skin",0.38,0.59),("hair",0.24,0.57),("fabric",0.36,0.40),("water",0.78,0.45)]
        }
    }
    private func toningPhotoCrop(_ image:CIImage,x:Double,y:Double,side:Int=384)->CIImage {
        let e=image.extent,s=min(CGFloat(side),e.width,e.height)
        let xx=min(e.maxX-s,max(e.minX,e.minX+e.width*x-s/2)),yy=min(e.maxY-s,max(e.minY,e.minY+e.height*y-s/2))
        return image.cropped(to:CGRect(x:floor(xx),y:floor(yy),width:s,height:s))
    }
    func toningPhotographs() throws {
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let files=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("Validation/VisualTestAssets"),includingPropertiesForKeys:nil)
            .filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count==8 else {throw LabError.configuration}
        let presets=CreativeFXPreset.all(for:.silverToning),titles=presets.map(\.title),n=presets.count
        var photoMatrix=Array(repeating:Array(repeating:0.0,count:n),count:n)
        var syntheticMatrix=photoMatrix,hashes:[String:String]=[:],triptych:[(String,CIImage)]=[],overlayBoard:[(String,CIImage)]=[]
        let referenceTitles=["Neutral Print","Subtle Selenium","Classic Sepia","Copper Print","Cool Gold","Platinum Print","Warm Silver","Cool Silver","Split Warm/Cool"]
        let names=["portrait_light_toning_comparison","portrait_dark_toning_comparison","landscape_toning_comparison","backlight_toning_comparison","night_toning_comparison","indoor_toning_comparison","white_subject_toning_comparison","fine_texture_toning_comparison"]
        for (index,file) in files.enumerated() {
            progress("Silver Toning photograph \(index+1)/8: \(file.lastPathComponent)")
            try autoreleasepool {
                guard let input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
                let hash=SHA256.hash(data:try Data(contentsOf:file)).map{String(format:"%02x",$0)}.joined();hashes[file.lastPathComponent]=hash
                let base=try render(input,[silverPreset("Neutral Silver")]),folder="SilverToning/RealPhotos/"+file.deletingPathExtension().lastPathComponent
                let baseSample=silverFullFrame(base,side:384),regions=toningPhotoRegions(index)
                var c=LabCase(name:"ST_photo_"+file.deletingPathExtension().lastPathComponent)
                var samples:[CIImage]=[],outputs:[CIImage]=[],contact:[(String,CIImage)]=[],crops:[(String,CIImage)]=[],diffs:[(String,CIImage)]=[]
                for preset in presets {
                    let output=try toningOutput(base,preset.makeEffect()),sample=silverFullFrame(output,side:384)
                    outputs.append(output);samples.append(sample);contact.append((preset.title,output))
                    let key=preset.title.lowercased().replacingOccurrences(of:" ",with:"_").replacingOccurrences(of:"/",with:"_")
                    try artifacts.png(output,folder+"/"+key+".png")
                    diffs.append((preset.title+" / difference ×8",artifacts.difference(base,output,gain:8)))
                    let m=gpu.compare(baseSample,sample)
                    c.metrics[key+"-meanDeltaY"]=m.residual.mean;c.metrics[key+"-luminanceResidualRMS"]=m.residualStd
                    c.metrics[key+"-colorMAE"]=m.mae
                    c.check(preset.title+" finite / Y",m.nonFinite==0 && m.residualStd<2e-5,hard:true,"Identical Neutral Silver base for all toning variants")
                    for (label,x,y) in regions {
                        let a=toningPhotoCrop(base,x:x,y:y,side:128),b=toningPhotoCrop(output,x:x,y:y,side:128),mm=gpu.compare(a,b)
                        c.metrics[key+" / "+label+" / deltaY"]=mm.residual.mean
                        c.metrics[key+" / "+label+" / RMSratio"]=mm.output.standardDeviation/max(1e-9,mm.input.standardDeviation)
                        c.check(preset.title+" / "+label+" detail",mm.residualStd<2e-5,hard:true,"Linear luminance detail is preserved; inspect color on skin, hair, white and black")
                    }
                    if [0,4,6].contains(index) && referenceTitles.contains(preset.title) {
                        triptych.append((file.deletingPathExtension().lastPathComponent+" / "+preset.title,silverFullFrame(output,side:384)))
                    }
                }
                // Each row is one native source crop, columns use the same preset order.
                for (label,x,y) in regions {
                    crops.append(("Original color / "+label,toningPhotoCrop(input,x:x,y:y)))
                    for (i,preset) in presets.enumerated() {
                        crops.append((preset.title+" / "+label,toningPhotoCrop(outputs[i],x:x,y:y)))
                    }
                }
                try artifacts.sheet(contact,folder+"/SilverToning_contact_sheet.png",cell:512,maxColumns:4)
                try artifacts.sheet(crops,folder+"/"+names[index]+".png",nativeCrop:true,cell:384,maxColumns:12)
                try artifacts.sheet(diffs,folder+"/difference_maps.png",cell:384,maxColumns:4)
                c.images=[folder+"/SilverToning_contact_sheet.png",folder+"/"+names[index]+".png"]
                for i in 0..<n {for j in 0..<i {
                    let d=gpu.compare(samples[i],samples[j]).mae;photoMatrix[i][j]+=d/8;photoMatrix[j][i]+=d/8
                }}
                if index==0 {
                    var colorAmounts:[(String,CIImage)]=[]
                    for amount in [0.0,25,50,75,100] {
                        var fx=toningPreset("Classic Sepia");fx["amount"]=amount
                        colorAmounts.append(("Color input / Amount \(amount)",try toningOutput(input,fx)))
                    }
                    try artifacts.sheet(colorAmounts,"SilverToning/color_input_amount.png",cell:512,maxColumns:5)
                    for name in ["Subtle Selenium","Classic Sepia","Split Warm/Cool"] {
                        for (label,source) in [("Ramp",silverRamp{SIMD3(repeating:Float($0))}),("Photograph",baseSample)] {
                            let out=try toningOutput(source,toningPreset(name)),fit=toningBestOverlay(source,out),overlay=toningOverlay(source,ratios:fit)
                            func display(_ i:CIImage)->CIImage { label=="Ramp" ? toningVisualRamp(i):i }
                            overlayBoard += [(name+" / "+label+" Neutral",display(source)),("Best constant overlay",display(overlay)),("Real Silver Toning",display(out)),("Difference ×8",display(artifacts.difference(overlay,out,gain:8)))]
                            c.metrics[name+" / "+label+" / bestOverlayResidualMAE"]=gpu.compare(overlay,out).mae
                        }
                    }
                }
                if index==6 {
                    var paper:[(String,CIImage)]=[]
                    for (name,value) in [("Paper neutral",0.0),("Warm paper",35.0),("Cool paper",-35.0),("Strong warm paper",100.0)] {
                        let out=try toningOutput(base,toningFX(["toner":5,"silverTone":0,"paperTone":value,"strength":100]))
                        paper.append((name,out))
                    }
                    var paperCrops:[(String,CIImage)]=[]
                    for (label,x,y) in regions {for (name,out) in paper {paperCrops.append((name+" / "+label,toningPhotoCrop(out,x:x,y:y)))}}
                    try artifacts.sheet(paper+paperCrops,folder+"/paper_tone_white_subject.png",cell:384,maxColumns:4)
                }
                c.check("Original unchanged",hash==SHA256.hash(data:try Data(contentsOf:file)).map{String(format:"%02x",$0)}.joined(),hard:true,"SHA256 original corpus")
                c.notes=["Native 384px crops, 128px metric ROIs; coordinates inherited from validated corpus: "+regions.map{"\($0.0)=(\($0.1),\($0.2))"}.joined(separator:", ")]
                cases.append(c)
            }
        }
        try artifacts.sheet(triptych,"SilverToning/reference_triptych.png",cell:384,maxColumns:9)
        try artifacts.sheet(overlayBoard,"SilverToning/not_an_overlay.png",cell:512,maxColumns:4)
        try artifacts.json(hashes,"SilverToning/source_hashes.json")
        let synthetic=SilverToningTestChart.generate(size:256)
        let syntheticOutputs=try presets.map{try toningOutput(synthetic,$0.makeEffect())}
        var diversity=LabCase(name:"ST_preset_diversity")
        for i in 0..<n {for j in 0..<i {
            let d=gpu.compare(syntheticOutputs[i],syntheticOutputs[j]).mae
            syntheticMatrix[i][j]=d;syntheticMatrix[j][i]=d
            diversity.metrics[titles[i]+" / "+titles[j]+" synthetic"]=d
            diversity.metrics[titles[i]+" / "+titles[j]+" photos"]=photoMatrix[i][j]
            let subtle=["Neutral Print","Subtle Selenium","Platinum Print"].contains(titles[i]) || ["Neutral Print","Subtle Selenium","Platinum Print"].contains(titles[j])
            diversity.check(titles[i]+" / "+titles[j],subtle || d>0.001 || photoMatrix[i][j]>0.0005,"WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning")
        }}
        try toningMatrix(syntheticMatrix,titles:titles,path:"SilverToning/preset_distance_matrix_synthetic.png",title:"Synthetic / linear RGB MAE")
        try toningMatrix(photoMatrix,titles:titles,path:"SilverToning/preset_distance_matrix_photos.png",title:"Eight photographs / linear RGB MAE")
        try artifacts.sheet([( "Synthetic",CIImage(contentsOf:artifacts.url("SilverToning/preset_distance_matrix_synthetic.png"))!), ("Photographs",CIImage(contentsOf:artifacts.url("SilverToning/preset_distance_matrix_photos.png"))!)],"SilverToning/preset_distance_matrix.png",cell:1050,maxColumns:2)
        try artifacts.json(["synthetic":syntheticMatrix,"photos":photoMatrix],"SilverToning/preset_distances.json")
        try artifacts.json(titles,"SilverToning/preset_labels.json")
        cases.append(diversity)
    }
    private func toningMatrix(_ values:[[Double]],titles:[String],path:String,title:String) throws {
        let n=titles.count,cell=85,left=250,bottom=30,width=left+n*cell+25,height=bottom+n*cell+100
        guard let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {throw LabError.render}
        context.setFillColor(CGColor(gray:0.06,alpha:1));context.fill(CGRect(x:0,y:0,width:width,height:height))
        func label(_ s:String,_ x:Int,_ y:Int,_ size:Double=15) {
            let attrs:[NSAttributedString.Key:Any]=[NSAttributedString.Key(kCTFontAttributeName as String):CTFontCreateWithName("Helvetica" as CFString,size,nil),NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:0.96,alpha:1)]
            context.textPosition=CGPoint(x:x,y:y);CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:attrs)),context)
        }
        label(title,30,height-35,23)
        let maximum=max(1e-8,values.flatMap{$0}.max()!)
        for i in 0..<n {
            label("\(i+1). \(titles[i])",10,bottom+(n-1-i)*cell+35)
            label("\(i+1)",left+i*cell+35,bottom+n*cell+15)
            for j in 0..<n {
                let q=sqrt(values[i][j]/maximum)
                context.setFillColor(CGColor(red:0.08+0.1*q,green:0.12+0.45*q,blue:0.2+0.35*q,alpha:1))
                context.fill(CGRect(x:left+j*cell,y:bottom+(n-1-i)*cell,width:cell-2,height:cell-2))
                label(String(format:"%.4f",values[i][j]),left+j*cell+12,bottom+(n-1-i)*cell+35)
            }
        }
        guard let image=context.makeImage() else {throw LabError.render}
        try artifacts.png(CIImage(cgImage:image),path)
    }
}
