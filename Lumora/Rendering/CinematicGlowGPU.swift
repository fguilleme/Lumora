import Foundation
import CoreImage
import Metal
import MetalPerformanceShaders

enum CinematicGlowError:Error {case metalUnavailable,invalidImage,command(String)}
private struct GlowUniforms { var diffusion:SIMD4<Float>;var halation:SIMD4<Float>;var global:SIMD4<Float> }
final class CinematicGlowFrame {
 let source:MTLTexture,output:MTLTexture
 var pyramid=[Int:MTLTexture](),scratch=[Int:MTLTexture]()
 var width:Int{source.width};var height:Int{source.height}
 var textureCount:Int{2+pyramid.count+scratch.count}
 var textureBytes:Int{([source,output]+Array(pyramid.values)+Array(scratch.values)).reduce(0){$0+$1.allocatedSize}}
 var levels:[Int]{pyramid.keys.sorted()}
 init(source:MTLTexture,output:MTLTexture){self.source=source;self.output=output}

}
final class CinematicGlowGPU {
 let device:MTLDevice,queue:MTLCommandQueue,context:CIContext
 let colorSpace=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!
 let extract:MTLComputePipelineState,combine:MTLComputePipelineState,reduce:MTLComputePipelineState,accumulate:MTLComputePipelineState,clear:MTLComputePipelineState
 let halfIntermediates:Bool,pyramidEnabled:Bool
 private var reusableFrame:CinematicGlowFrame?
 var blurCache=[Float:MPSImageGaussianBlur]()
 init(halfIntermediates:Bool=true,pyramidEnabled:Bool=true)throws {
  self.halfIntermediates=halfIntermediates;self.pyramidEnabled=pyramidEnabled
  guard let d=MTLCreateSystemDefaultDevice(),let q=d.makeCommandQueue() else{throw CinematicGlowError.metalUnavailable}
  device=d;queue=q
  context=CIContext(mtlDevice:d,options:[.workingColorSpace:colorSpace,.workingFormat:CIFormat.RGBAf,.cacheIntermediates:false])
  let opts=MTLCompileOptions();opts.fastMathEnabled=false
  let lib=try d.makeLibrary(source:CinematicGlowShader.source,options:opts)
  extract=try d.makeComputePipelineState(function:lib.makeFunction(name:"extractLevel")!)
  combine=try d.makeComputePipelineState(function:lib.makeFunction(name:"finish")!)
  reduce=try d.makeComputePipelineState(function:lib.makeFunction(name:"reduceLevel")!)
  accumulate=try d.makeComputePipelineState(function:lib.makeFunction(name:"accumulate")!)
  clear=try d.makeComputePipelineState(function:lib.makeFunction(name:"clearOutput")!)
 }
 // Actor-owned. Returned CIImage must be consumed before the next call reuses textures.
 func apply(_ input:CIImage,intensity:Double)throws->CIImage {
  let amount=intensity.isFinite ? min(100,max(0,intensity)):0
  guard amount>0 else{return input} // exact bypass: no materialization or GPU allocation
  let f=try prepare(input)
  try render(f,settings:CinematicGlowParameters(intensity:Float(amount)))
  return image(f.output).transformed(by:CGAffineTransform(translationX:input.extent.minX,y:input.extent.minY))
 }
 func releaseFrame(){reusableFrame=nil}
 var allocatedTextureBytes:Int{reusableFrame?.textureBytes ?? 0}
 func texture(_ w:Int,_ h:Int,intermediate:Bool=false)throws->MTLTexture {
  let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:intermediate && halfIntermediates ? .rgba16Float:.rgba32Float,width:w,height:h,mipmapped:false)
  desc.usage=[.shaderRead,.shaderWrite,.renderTarget];desc.storageMode = .private
  guard let t=device.makeTexture(descriptor:desc) else{throw CinematicGlowError.metalUnavailable};return t
 }
 static func load(_ url:URL)throws->CIImage {
  guard let im=CIImage(contentsOf:url,options:[.applyOrientationProperty:true,.expandToHDR:true]) else{throw CinematicGlowError.invalidImage}
  return im.transformed(by:CGAffineTransform(translationX:-im.extent.minX,y:-im.extent.minY))
 }
 func prepare(_ input:CIImage,longEdge:Int?=nil)throws->CinematicGlowFrame {
  let factor:Double=longEdge.map{min(1.0,Double($0)/Double(max(input.extent.width,input.extent.height)))} ?? 1.0
  let w=max(1,Int((input.extent.width*factor).rounded())),h=max(1,Int((input.extent.height*factor).rounded()))
  if reusableFrame?.width != w || reusableFrame?.height != h {
   reusableFrame=nil // Release old size before allocating the next one.
   reusableFrame=try CinematicGlowFrame(source:texture(w,h),output:texture(w,h))
  }
  let frame=reusableFrame!,src=frame.source
  let cb=queue.makeCommandBuffer()!
  let zero=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,y:-input.extent.minY))
  let im=zero.transformed(by:CGAffineTransform(scaleX:Double(w)/input.extent.width,y:Double(h)/input.extent.height))
   .transformed(by:CGAffineTransform(scaleX:1,y:-1)).transformed(by:CGAffineTransform(translationX:0,y:Double(h)))
  context.render(im,to:src,commandBuffer:cb,bounds:CGRect(x:0,y:0,width:w,height:h),colorSpace:colorSpace)
  cb.commit();cb.waitUntilCompleted();if let e=cb.error{throw e}
  return frame
 }
 func blur(_ sigma:Float)->MPSImageGaussianBlur {
  if let b=blurCache[sigma]{return b}
  let b=MPSImageGaussianBlur(device:device,sigma:max(0.1,sigma));b.edgeMode = .clamp
  // Cache is bounded; sliders otherwise create an unbounded kernel collection.
  if blurCache.count>48{blurCache.removeAll()};blurCache[sigma]=b;return b
 }
 func encode(_ frame:CinematicGlowFrame,settings s:CinematicGlowParameters,commandBuffer cb:MTLCommandBuffer)throws {
  if s.mix==0 || (s.diffusion==0 && s.halation==0) {
   let b=cb.makeBlitCommandEncoder()!;b.copy(from:frame.source,to:frame.output);b.endEncoding();return
  }
  var p=GlowUniforms(diffusion:SIMD4(s.diffusion,s.radius,s.threshold,s.softness),halation:SIMD4(s.halation,s.halationRadius,s.warmth,0),global:SIMD4(s.mix,s.intensity,0,0))
  func dispatch(_ pipeline:MTLComputePipelineState,_ textures:[MTLTexture],_ width:Int,_ height:Int,_ weights:SIMD4<Float> = .zero) {
   let e=cb.makeComputeCommandEncoder()!;e.setComputePipelineState(pipeline)
   for (i,t) in textures.enumerated(){e.setTexture(t,index:i)}
   var weights=weights;e.setBytes(&p,length:MemoryLayout<GlowUniforms>.stride,index:0);e.setBytes(&weights,length:16,index:1)
   e.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:16,height:16,depth:1));e.endEncoding()
  }
  let scale=Float(max(frame.width,frame.height))/960
  let ds:[Float]=[0.6,2.5,9].map{$0*s.radius*scale},hs:[Float]=[0.55,1,1.65,2.5].map{$0*s.halationRadius*scale}
  func level(_ sigma:Float)->Int {guard pyramidEnabled else{return 0};return min(3,max(0,Int(floor(log2(max(1,sigma/6))))))}
  let sigmas=(s.diffusion>0 ? ds:[])+(s.halation>0 ? hs:[]),needed=Set(sigmas.map{level($0)}),maxLevel=needed.max() ?? 0
  // Retain only the current schedule. In-flight command buffers retain their resources.
  frame.pyramid=frame.pyramid.filter{$0.key<=maxLevel};frame.scratch=frame.scratch.filter{needed.contains($0.key)}
  for l in 0...maxLevel {let divisor=1<<l,w=(frame.width+divisor-1)/divisor,h=(frame.height+divisor-1)/divisor
   if frame.pyramid[l]==nil{frame.pyramid[l]=try texture(w,h,intermediate:true)}
   if needed.contains(l) && frame.scratch[l]==nil{frame.scratch[l]=try texture(w,h,intermediate:true)}
  }
  dispatch(clear,[frame.output],frame.width,frame.height)
  for mode in 0...1 where mode==0 ? s.diffusion>0:s.halation>0 {
   p.global.z=Float(mode);dispatch(extract,[frame.source,frame.pyramid[0]!],frame.width,frame.height)
   if maxLevel>0 {for l in 1...maxLevel{let t=frame.pyramid[l]!;dispatch(reduce,[frame.pyramid[l-1]!,t],t.width,t.height)}}
   for (i,sigma) in (mode==0 ? ds:hs).enumerated(){let l=level(sigma),divisor=Float(1<<l),src=frame.pyramid[l]!,dst=frame.scratch[l]!
    // Account approximately for box reduction + bilinear reconstruction variance.
    let adjusted=sqrt(max(0.01,sigma*sigma-(divisor*divisor-1)/4))/divisor
    blur(adjusted).encode(commandBuffer:cb,sourceTexture:src,destinationTexture:dst)
    p.global.w=divisor
    dispatch(accumulate,[dst,frame.output],frame.width,frame.height,SIMD4(mode==0 ? [Float(0.5),0.32,0.18][i]:0,mode==0 ? 0:Float(i+1),0,0))
   }
  }
  dispatch(combine,[frame.source,frame.output],frame.width,frame.height)
 }
 @discardableResult func render(_ frame:CinematicGlowFrame,settings:CinematicGlowParameters)throws->(gpuMS:Double,wallMS:Double) {
  let start=CFAbsoluteTimeGetCurrent(),cb=queue.makeCommandBuffer()!
  try encode(frame,settings:settings,commandBuffer:cb);cb.commit();cb.waitUntilCompleted();if let e=cb.error{throw e}
  return ((cb.gpuEndTime-cb.gpuStartTime)*1000,(CFAbsoluteTimeGetCurrent()-start)*1000)
 }
 func image(_ t:MTLTexture)->CIImage {
  CIImage(mtlTexture:t,options:[.colorSpace:colorSpace])!.transformed(by:CGAffineTransform(scaleX:1,y:-1)).transformed(by:CGAffineTransform(translationX:0,y:Double(t.height)))
 }
 func export(_ t:MTLTexture,to url:URL,hdr:Bool=false)throws {
  if hdr {try context.writeTIFFRepresentation(of:image(t),to:url,format:.RGBAf,colorSpace:colorSpace,options:[:])}
  else {try context.writePNGRepresentation(of:image(t),to:url,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,options:[:])}
 }
 /// Validation/export only. Never called by the interactive canvas.
 func pixels(_ t:MTLTexture)->[Float] {
  var values=[Float](repeating:0,count:t.width*t.height*4)
  context.render(image(t),toBitmap:&values,rowBytes:t.width*16,bounds:CGRect(x:0,y:0,width:t.width,height:t.height),format:.RGBAf,colorSpace:colorSpace)
  return values
 }
}

struct CinematicGlowParameters {
 var intensity:Float
 let diffusion:Float=1, radius:Float=6, threshold:Float=0.32, softness:Float=0.18
 let halation:Float=0, halationRadius:Float=12, warmth:Float=0.85, mix:Float=1
}
