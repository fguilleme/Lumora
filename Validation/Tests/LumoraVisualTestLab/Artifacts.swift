import Foundation
import CoreImage
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

struct LabArtifacts {
    let root:URL
    let gpu:LabGPU
    func url(_ name:String) throws -> URL {
        let url=root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        return url
    }
    func png(_ image:CIImage,_ name:String) throws {
        try gpu.context.writePNGRepresentation(of:image,to:url(name),format:.RGBA16,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,options:[:])
    }
    func difference(_ a:CIImage,_ b:CIImage,gain:Double=4)->CIImage {
        b.applyingFilter("CIDifferenceBlendMode",parameters:[kCIInputBackgroundImageKey:a])
            .applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:gain,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:gain,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:gain,w:0)]).cropped(to:a.extent)
    }
    func sheet(_ items:[(String,CIImage)],_ name:String,nativeCrop:Bool=false,
               cell:Int=512,maxColumns:Int=4) throws {
        let columns=min(maxColumns,items.count),rows=(items.count+columns-1)/columns
        let header=44
        let context=try bitmap(width:columns*cell,height:rows*(cell+header))
        context.setFillColor(CGColor(gray:0.06,alpha:1));context.fill(CGRect(x:0,y:0,width:context.width,height:context.height))
        for (i,item) in items.enumerated() {
            let x=(i%columns)*cell,y=context.height-(i/columns+1)*(cell+header)
            let input:CIImage
            if nativeCrop {
                let extent=item.1.extent,w=min(CGFloat(cell),extent.width),h=min(CGFloat(cell),extent.height)
                input=item.1.cropped(to:CGRect(x:floor(extent.midX-w/2),y:floor(extent.midY-h/2),width:w,height:h))
            } else { input=item.1 }
            guard let cg=gpu.context.createCGImage(input,from:input.extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!) else { throw LabError.render }
            let factor=nativeCrop ? 1:min(Double(cell)/Double(cg.width),Double(cell)/Double(cg.height))
            let w=Double(cg.width)*factor,h=Double(cg.height)*factor
            context.interpolationQuality=nativeCrop ? .none:.high
            context.draw(cg,in:CGRect(x:Double(x)+(Double(cell)-w)/2,y:Double(y)+(Double(cell)-h)/2,width:w,height:h))
            label(item.0,in:context,x:Double(x+12),y:Double(y+cell+12),size:17)
        }
        try save(context,name)
    }
    func plot(_ series:[(String,[Double])],_ name:String,title:String,yRange:ClosedRange<Double>?=nil,xMaximum:Double=1) throws {
        let ctx=try bitmap(width:960,height:600)
        ctx.setFillColor(CGColor(gray:0.06,alpha:1));ctx.fill(CGRect(x:0,y:0,width:960,height:600))
        let all=series.flatMap(\.1).filter(\.isFinite)
        let lo=yRange?.lowerBound ?? min(0,all.min() ?? 0),hi=yRange?.upperBound ?? max(0.00001,all.max() ?? 1)
        label(title,in:ctx,x:65,y:555,size:23)
        let colors:[CGColor]=[CGColor(red:0.1,green:0.85,blue:0.65,alpha:1),CGColor(red:1,green:0.65,blue:0.2,alpha:1),CGColor(red:0.5,green:0.65,blue:1,alpha:1),CGColor(red:1,green:0.4,blue:0.65,alpha:1),CGColor(red:0.8,green:0.65,blue:1,alpha:1)]
        for j in 0...4 {
            let y=70+Double(j)*110
            ctx.setStrokeColor(CGColor(gray:0.25,alpha:1));ctx.setLineWidth(1)
            ctx.move(to:CGPoint(x:70,y:y));ctx.addLine(to:CGPoint(x:910,y:y));ctx.strokePath()
            label(String(format:"%.3g",lo+(hi-lo)*Double(j)/4),in:ctx,x:5,y:y-4,size:12)
        }
        for tick in 0...4 {
            label(String(format:"%.2f",Double(tick)*xMaximum/4),in:ctx,x:60+Double(tick)*210,y:50,size:12)
        }
        for (i,s) in series.enumerated() {
            ctx.setStrokeColor(colors[i%colors.count]);ctx.setLineWidth(2)
            for (j,v) in s.1.enumerated() where v.isFinite {
                let point=CGPoint(x:70+Double(j)/Double(max(1,s.1.count-1))*840,y:70+(v-lo)/max(1e-20,hi-lo)*440)
                if j==0 { ctx.move(to:point) } else { ctx.addLine(to:point) }
            }
            ctx.strokePath();label(s.0,in:ctx,x:70+Double(i)*840/Double(max(3,series.count)),y:28,size:14,color:colors[i%colors.count])
        }
        try save(ctx,name)
    }
    func json<T:Encodable>(_ value:T,_ name:String) throws {
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity:"Infinity",negativeInfinity:"-Infinity",nan:"NaN")
        try encoder.encode(value).write(to:url(name),options:.atomic)
    }
    private func bitmap(width:Int,height:Int) throws -> CGContext {
        guard let ctx=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { throw LabError.render }
        return ctx
    }
    private func label(_ text:String,in ctx:CGContext,x:Double,y:Double,size:Double,color:CGColor=CGColor(gray:0.9,alpha:1)) {
        let attributes:[NSAttributedString.Key:Any]=[NSAttributedString.Key(kCTFontAttributeName as String):CTFontCreateWithName("Helvetica" as CFString,size,nil),NSAttributedString.Key(kCTForegroundColorAttributeName as String):color]
        let line=CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:attributes))
        ctx.textPosition=CGPoint(x:x,y:y);CTLineDraw(line,ctx)
    }
    private func save(_ ctx:CGContext,_ name:String) throws {
        guard let cg=ctx.makeImage(),let dest=CGImageDestinationCreateWithURL(try url(name) as CFURL,UTType.png.identifier as CFString,1,nil) else { throw LabError.render }
        CGImageDestinationAddImage(dest,cg,nil)
        guard CGImageDestinationFinalize(dest) else { throw LabError.render }
    }
}
enum LabError:Error { case render, invalidGolden, configuration }
struct GoldenManifest:Codable,Equatable {
    let schema:Int
    let inputIdentity:String
    let configuration:String
    let width:Int,height:Int
    let space:String
}
enum GoldenStore {
    /// Separate explicit recording runs, never self-compare a newly recorded result.
    static func process(_ image:CIImage,id:String,inputIdentity:String,configuration:String,gpu:LabGPU,environment:[String:String]=ProcessInfo.processInfo.environment) throws -> (String,Comparison?) {
        let env=environment
        guard let path=env["LUMORA_GOLDEN_DIR"] else { return ("WARN: no reviewed golden configured",nil) }
        let root=URL(fileURLWithPath:path,isDirectory:true)
        let manifest=GoldenManifest(schema:1,inputIdentity:inputIdentity,configuration:configuration,width:Int(image.extent.width),height:Int(image.extent.height),space:"extendedLinearSRGB RGBA float TIFF")
        let metadata=root.appendingPathComponent(id+".json"),file=root.appendingPathComponent(id+".tiff")
        if env["LUMORA_RECORD_GOLDENS"] == "YES_I_REVIEWED_THE_OUTPUTS" {
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            try gpu.context.writeTIFFRepresentation(of:image,to:file,format:.RGBAf,colorSpace:gpu.linear,options:[:])
            try JSONEncoder().encode(manifest).write(to:metadata,options:.atomic)
            return ("WARN: golden recorded explicitly; not compared in this run",nil)
        }
        guard FileManager.default.fileExists(atPath:metadata.path) else { return ("WARN: reviewed golden missing for this case",nil) }
        let old=try JSONDecoder().decode(GoldenManifest.self,from:Data(contentsOf:metadata))
        guard old==manifest,let golden=CIImage(contentsOf:file) else { throw LabError.invalidGolden }
        return ("Reviewed golden compared",gpu.compare(golden,image))
    }
}
