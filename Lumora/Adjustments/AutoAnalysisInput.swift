import Foundation
import CoreImage

struct AutoAnalysisKey: Sendable, Equatable {
    let url: URL
    let version: String
    let upstream: EditState
    let mask: LocalMask?
    let maximum: Int
    init(url: URL, version: String, state: EditState, maskID: UUID?, maximum: Int = 512) {
        self.url=url;self.version=version;self.maximum=maximum
        var upstream=EditState();upstream.optics=state.optics;upstream.geometry=state.geometry
        if let index=state.masks.firstIndex(where:{$0.id==maskID}) {
            upstream=state;upstream.creative=CreativeEffectStack()
            upstream.masks=Array(state.masks.prefix(index))
            // Legacy grain is after all masked development, therefore not an analysis input.
            upstream.effects.grain=0
            for i in upstream.masks.indices { upstream.masks[i].adjustments.effects.grain=0 }
            var target=state.masks[index];target.adjustments=LocalAdjustmentState();target.opacity=100
            mask=target
        } else { mask=nil }
        self.upstream=upstream
    }
}

struct AutoAnalysisResult: Sendable {
    let proposal: AutoProposal
    let cacheHit: Bool
    let milliseconds: Double
}

enum AutoAnalysisInput {
    static func pixels(_ image: CIImage, context: CIContext, maximum: Int = 512, mask: CIImage? = nil) -> [Float] {
        let extent=image.extent
        let scale=min(1,Double(maximum)/max(extent.width,extent.height))
        let normalized=image.transformed(by:CGAffineTransform(translationX:-extent.minX,y:-extent.minY))
            .transformed(by:CGAffineTransform(scaleX:scale,y:scale))
        let width=max(1,Int((extent.width*scale).rounded())),height=max(1,Int((extent.height*scale).rounded()))
        let bounds=CGRect(x:0,y:0,width:width,height:height)
        var pixels=[Float](repeating:0,count:width*height*4)
        let space=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!
        context.render(normalized,toBitmap:&pixels,rowBytes:width*16,bounds:bounds,format:.RGBAf,colorSpace:space)
        if let mask {
            var matte=[Float](repeating:0,count:pixels.count)
            let fitted=mask.transformed(by:CGAffineTransform(translationX:-extent.minX,y:-extent.minY))
                .transformed(by:CGAffineTransform(scaleX:scale,y:scale))
            context.render(fitted,toBitmap:&matte,rowBytes:width*16,bounds:bounds,format:.RGBAf,colorSpace:space)
            for i in stride(from:0,to:pixels.count,by:4) where matte[i] < 0.05 { pixels[i+3]=0 }
        }
        return pixels
    }
}
