import Foundation
import CoreImage
import Metal
import Darwin
@testable import LumoraCore

extension LumoraVisualTestLab {
    func dlcPerformance() throws {
        progress("DLC: isolated GPU command timing, CPU graph preparation, resolution and memory")
        guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {throw LabError.render}
        let context=CIContext(mtlDevice:device,options:[.workingColorSpace:gpu.linear,.workingFormat:CIFormat.RGBAf,.cacheIntermediates:false])
        var c=LabCase(name:"DLC_performance_resolution_memory")
        let fx=dlcPreset("Portrait Focus")
        var references:[Float] = []
        for side in [1024,2048,4096] {
            try autoreleasepool {
                let input=SyntheticCharts.make(size:side){x,y in SIMD3(repeating:Float(0.1+0.1*x+0.05*y))}
                let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:side,height:side,mipmapped:false)
                desc.usage=[.shaderRead,.shaderWrite,.renderTarget];desc.storageMode = .private
                guard let texture=device.makeTexture(descriptor:desc) else {throw LabError.render}
                var gpuMS:[Double]=[],cpuMS:[Double]=[],wallMS:[Double]=[]
                for iteration in 0..<6 {
                    let start=ProcessInfo.processInfo.systemUptime
                    let output=try render(input,[fx])
                    let prepared=ProcessInfo.processInfo.systemUptime
                    guard let command=queue.makeCommandBuffer() else {throw LabError.render}
                    context.render(output,to:texture,commandBuffer:command,bounds:input.extent,colorSpace:gpu.linear)
                    command.commit();command.waitUntilCompleted()
                    guard command.status == .completed else {throw LabError.render}
                    if iteration>0 {
                        gpuMS.append((command.gpuEndTime-command.gpuStartTime)*1000)
                        cpuMS.append((prepared-start)*1000)
                        wallMS.append((ProcessInfo.processInfo.systemUptime-start)*1000)
                    }
                }
                c.metrics["\(side)-GPU-medianMS"]=gpuMS.sorted()[2]
                c.metrics["\(side)-CPU-graph-medianMS"]=cpuMS.sorted()[2]
                c.metrics["\(side)-wall-medianMS"]=wallMS.sorted()[2]
                let sample=silverPixels(dlcFullFrame(try render(input,[fx]),side:256))
                if references.isEmpty {references=sample}
                let error=zip(sample,references).map{abs($0-$1)}.max() ?? 0
                c.metrics["\(side)-resolutionMaxError"]=Double(error)
                c.check("Resolution \(side)",error<0.002,hard:true,"Same normalized varying scene rendered natively, reduced to 256px")
            }
        }
        func rss()->Double {
            var info=mach_task_basic_info(),count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
            let result=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)}}
            return result==KERN_SUCCESS ? Double(info.resident_size):0
        }
        let source=DarkenLightenCenterTestChart.image(width:256,height:256)
        var memory:[Double]=[]
        for batch in 0..<4 {
            for i in 0..<36 {
                try autoreleasepool {
                    let f=dlc(["centerEV":0.4,"borderEV":-0.6,"centerX":Double(i%31)/30,"centerY":Double(i%23)/22,
                               "size":Double(5+i*7%146),"shape":Double(i*13%201-100),"rotation":Double(i*19%361-180),"feather":Double(i*17%101)])
                    c.check("Switch \(batch)/\(i)",silverPixels(try render(source,[f])).allSatisfy(\.isFinite),hard:true,"Geometry varied, no retained per-effect mask texture")
                }
            }
            memory.append(rss());c.metrics["RSS-batch\(batch)"]=memory.last!
        }
        c.check("Bounded post-warmup memory",memory.last!-memory[0]<64*1024*1024,"144 changes; RSS diagnostic, not a device leak instrument")
        c.notes=["GPU command timestamps include CI encoding execution and output writes, without CPU readback. CPU timing is settings validation/graph preparation; compile is warmed. No isolated kernel-only claim. Mac GPU, not iPhone thermal performance."]
        for count in [1,2,4] {
            let input=DarkenLightenCenterTestChart.image(width:1024,height:1024)
            let effects=(0..<count).map{i in dlc(["centerEV":0.2,"borderEV":-0.2,"centerX":0.2+Double(i)*0.15])}
            _=silverPixels(try render(input,effects))
            var times:[Double]=[]
            for _ in 0..<3 {
                let start=ProcessInfo.processInfo.systemUptime
                _=silverPixels(try render(input,effects))
                times.append((ProcessInfo.processInfo.systemUptime-start)*1000)
            }
            c.metrics["instances\(count)-materializationMedianMS"]=times.sorted()[1]
        }
        cases.append(c)
    }
}
