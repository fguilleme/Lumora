#if DEBUG
import Foundation
import CoreGraphics

enum DebugLabBitmap {
    static func linear(_ image:CGImage,maximum:Int?=nil)throws->(width:Int,height:Int,pixels:[Float]) {
        let scale=maximum.map{min(1,Double($0)/Double(max(image.width,image.height)))} ?? 1
        let w=max(1,Int((Double(image.width)*scale).rounded()))
        let h=max(1,Int((Double(image.height)*scale).rounded()))
        var bytes=[UInt8](repeating:0,count:w*h*4)
        let okay=bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context=CGContext(data:buffer.baseAddress,width:w,height:h,bitsPerComponent:8,
                                        bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,
                                        bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false}
            context.draw(image,in:CGRect(x:0,y:0,width:w,height:h));return true
        }
        guard okay else{throw NSError(domain:"Debug bitmap decode",code:1)}
        var pixels=[Float](repeating:0,count:w*h*4)
        for i in 0..<w*h {
            let alpha=Float(bytes[4*i+3])/255
            for c in 0..<3 {
                let encoded=alpha>0 ? min(1,Float(bytes[4*i+c])/255/alpha) : 0
                pixels[4*i+c]=encoded<=0.04045 ? encoded/12.92 : pow((encoded+0.055)/1.055,2.4)
            }
            pixels[4*i+3]=alpha
        }
        return (w,h,pixels)
    }
    static func display(_ pixels:[Float],width w:Int,height h:Int)throws->CGImage {
        var bytes=[UInt8](repeating:0,count:w*h*4)
        for i in 0..<w*h {
            let alpha=min(1,max(0,pixels[4*i+3]))
            for c in 0..<3 {
                let value=min(1,max(0,pixels[4*i+c]))
                let encoded=value<=0.0031308 ? value*12.92 : 1.055*pow(value,1/2.4)-0.055
                bytes[4*i+c]=UInt8((min(1,max(0,encoded*alpha))*255).rounded())
            }
            bytes[4*i+3]=UInt8((alpha*255).rounded())
        }
        let data=Data(bytes)
        guard let provider=CGDataProvider(data:data as CFData),
              let image=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,
                                space:CGColorSpace(name:CGColorSpace.sRGB)!,
                                bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else {
            throw NSError(domain:"Debug bitmap encode",code:2)
        }
        return image
    }
}
#endif
