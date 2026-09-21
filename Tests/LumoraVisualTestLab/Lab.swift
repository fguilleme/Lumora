import Foundation
import CoreImage
import CryptoKit
@testable import LumoraCore

struct LabCheck:Codable {
    let name:String
    let status:String
    let hard:Bool
    let detail:String
}
struct LabCase:Codable {
    let name:String
    var metrics:[String:Double]=[:]
    var checks:[LabCheck]=[]
    var images:[String]=[]
    var notes:[String]=[]
    var status:String { checks.contains{$0.status=="FAIL"} ? "FAIL" : checks.contains{$0.status=="WARN"} ? "WARN":"PASS" }
    mutating func check(_ name:String,_ condition:Bool,hard:Bool=false,_ detail:String) {
        checks.append(.init(name:name,status:condition ? "PASS":hard ? "FAIL":"WARN",hard:hard,detail:detail))
    }
}
/// Test-only coordinator. All effect images go through the production stack compositor.
final class LumoraVisualTestLab {
    let gpu:LabGPU
    let artifacts:LabArtifacts
    let size:Int
    let full:Bool
    var cases:[LabCase]=[]
    let sourceIdentity:String
    init(root:URL,full:Bool) throws {
        self.full=full;size=full ? 4096:512
        gpu=try LabGPU();artifacts=LabArtifacts(root:root,gpu:gpu)
        let file=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("Chart.swift")
        sourceIdentity=SHA256.hash(data:try Data(contentsOf:file)).map{String(format:"%02x",$0)}.joined()
    }
    func effect(_ kind:CreativeEffectKind,_ parameters:[String:Double]=[:])->CreativeEffect {
        var fx=CreativeEffect(kind)
        for (key,value) in parameters { fx[key]=value }
        return fx
    }
    func render(_ image:CIImage,_ effects:[CreativeEffect],masks:[AdjustmentLayer]=[]) throws -> CIImage {
        try CreativeStackRenderer.apply(image,stack:.init(effects:effects),masks:masks)
    }
    func progress(_ message:String) {
        FileHandle.standardOutput.write(Data(("[VisualLab] " + message + "\n").utf8))
    }
    func run() async throws {
        try FileManager.default.createDirectory(at:artifacts.root,withIntermediateDirectories:true)
        let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let rendererData=try Data(contentsOf:repo.appendingPathComponent("Lumora/Creative/CreativeRenderer.swift"))
        let rendererHash=SHA256.hash(data:rendererData).map{String(format:"%02x",$0)}.joined()
        try artifacts.json(["chartSHA256":sourceIdentity,"rendererSHA256":rendererHash,"device":gpu.deviceName,"os":ProcessInfo.processInfo.operatingSystemVersionString,"mode":full ? "full":"quick","measurementSpace":"extended linear sRGB / RGBAf","timestamp":ISO8601DateFormatter().string(from:Date())],"Reports/environment.json")
        do {
            progress("Master charts and High/Low Key")
            try autoreleasepool { try keyTests() }
            progress("Low Key isolated Dynamic sweep")
            try autoreleasepool { try lowKeyDynamicSweep() }
            progress("Grain parameter matrix")
            try autoreleasepool { try grainTests() }
            progress("Edges, textures, masks and effect ordering")
            try autoreleasepool { try structuralTests() }
            progress("Synthetic scenes and optional photographs")
            try autoreleasepool { try scenesAndAssets() }
            progress("Resolution and performance")
            try autoreleasepool { try resolutionTests() }
            progress("Production preview/HQ/export")
            try await previewExportTests()
        } catch {
            var c=LabCase(name:"Harness execution")
            c.check("Completed",false,hard:true,String(describing:error));cases.append(c)
            try writeReport()
            throw error
        }
        try writeReport()
    }
    func baseline(_ output:CIImage,_ fx:CreativeEffect,_ id:String,_ result:inout LabCase) throws {
        let config: [String:Any] = ["kind":fx.kind.rawValue,"parameters":fx.validated.parameters,"seed":fx.seed,"opacity":fx.opacity,"monochromatic":fx.monochromatic]
        let data=try JSONSerialization.data(withJSONObject:config,options:.sortedKeys)
        let (note,comparison)=try GoldenStore.process(output,id:id,inputIdentity:sourceIdentity,configuration:String(decoding:data,as:UTF8.self),gpu:gpu)
        result.notes.append(note)
        if let comparison {
            result.metrics["goldenMAE"]=comparison.mae;result.metrics["goldenRMSE"]=comparison.rmse
            result.metrics["goldenMaxError"]=comparison.maxError;result.metrics["goldenSSIM"]=comparison.ssim
            result.check("Reviewed golden numerical agreement",comparison.maxError<0.002 && comparison.rmse<0.0002 && comparison.ssim>0.995,hard:true,"Floating GPU tolerance: max < .002, RMSE < .0002, SSIM > .995; source/settings must match the manifest.")
        }
    }
    func keyTests() throws {
        let chart=MasterChart.generate(size:size)
        try artifacts.json(chart.regions,"Reports/master-regions.json")
        try artifacts.png(chart.image,"Charts/master_input.png")
        // Float TIFF retains HDR values hidden by the SDR PNG contact sheets.
        try gpu.context.writeTIFFRepresentation(of:chart.image,to:artifacts.url("Charts/master_linear.tiff"),format:.RGBAh,colorSpace:gpu.linear,options:[:])
        for kind in [CreativeEffectKind.highKey,.lowKey] {
            let folder=kind == .highKey ? "HighKey":"LowKey",prefix=kind == .highKey ? "HK":"LK"
            let protection=kind == .highKey ? "lightProtection":"darkProtection"
            let configurations:[(String,[String:Double])] = [
                ("01_standard",["amount":50,"dynamic":0,"glow":0]),
                ("02_dynamic",["amount":50,"dynamic":50,"glow":0]),
                ("03_strong_dynamic",["amount":90,"dynamic":90,"glow":0]),
                ("04_protected",["amount":90,"dynamic":50,protection:100,"glow":0]),
                ("05_glow",["amount":50,"dynamic":50,"glow":50])]
            var sheet:[(String,CIImage)]=[("Original / linear source",chart.image)]
            for (name,params) in configurations {
                try autoreleasepool {
                    progress(prefix+name)
                    let id=prefix+name,fx=effect(kind,params),output=try render(chart.image,[fx])
                    try artifacts.json(fx.validated,"Reports/\(id)_settings.json")
                    let m=gpu.compare(chart.image,output)
                    var result=LabCase(name:id)
                    result.metrics=["meanInput":m.input.mean,"meanOutput":m.output.mean,"whiteClippingPercent":Double(m.whiteOutput)*100/Double(m.output.count),"blackClippingPercent":Double(m.blackOutput)*100/Double(m.output.count),"outsideSDRPercent":Double(m.outsideSDR)*100/Double(m.output.count),"nonFinitePixels":Double(m.nonFinite)]
                    result.check("Finite output",m.nonFinite==0,hard:true,"NaN/Inf pixel count must be zero, including alpha.")
                    let extraClipping=Double(m.whiteOutput-m.whiteInput)/Double(max(1,m.output.count))
                    result.metrics["inputWhiteClippingPercent"]=Double(m.whiteInput)*100/Double(max(1,m.input.count))
                    result.metrics["inputBlackClippingPercent"]=Double(m.blackInput)*100/Double(max(1,m.input.count))
                    result.metrics["additionalChannelClippingPercent"]=extraClipping*100
                    result.check("Additional SDR channel clipping",extraClipping<0.01,"WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.")
                    result.check("Mean tonal direction",kind == .highKey ? m.output.mean>m.input.mean:m.output.mean<m.input.mean,"High Key lifts; Low Key darkens. Includes the fixed HDR source regions.")
                    var regions:[String:Comparison]=[:]
                    for region in chart.regions {
                        regions[region.name]=gpu.compare(chart.image,output,region:region.rect,ramp:region.ramp)
                    }
                    let colorDrift=regions.filter { $0.key.contains("saturation") }.values.map(\.maxChromaticityError).max() ?? 0
                    result.metrics["maxColorPatchChromaticityDrift"]=colorDrift
                    if params["glow"] == 0 {
                        result.check("Neutral-saturation hue preservation",colorDrift<0.001,"Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.")
                    }
                    let ramp=regions["ramp-full"]!
                    result.metrics["monotonicityViolations"]=Double(ramp.monotonicityViolations)
                    result.metrics["flatRampSteps"]=Double(ramp.flatSteps)
                    result.metrics["maxAdjacentRampStep"]=ramp.maxAdjacentStep
                    result.check("Ramp monotonicity",ramp.monotonicityViolations<=max(1,size/1000),"Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).")
                    for zone in ["ramp-shadows","ramp-midtones","ramp-highlights"] {
                        let p=regions[zone]!
                        let label = kind == .lowKey && zone == "ramp-highlights" ? "legacy-specular-high-end-response" : zone
                        result.metrics[label+"-relativeChange"]=(p.output.mean-p.input.mean)/max(0.000001,p.input.mean)
                    }
                    if kind == .lowKey {
                        Self.recordLowKeyZones(ramp, into: &result)
                        result.notes.append("Historical ramp metrics retained: shadows [0,.10], midtones [.40,.60], specular/high-end response [.90,1]. The latter is not a general highlights measure. New photographic zones are reported separately; [.90,.95] is an intentionally unclassified transition.")
                    }
                    if name.contains("dynamic") {
                        let shadows=result.metrics["ramp-shadows-relativeChange"]!,highlights=result.metrics[kind == .lowKey ? "legacy-specular-high-end-response-relativeChange" : "ramp-highlights-relativeChange"]!
                        result.check(kind == .lowKey ? "Historical specular/high-end vs deep-shadow relative response" : "Dynamic relative response",kind == .highKey ? shadows>highlights : -highlights > -shadows,"Relative change = (mean output − mean input)/mean input. Historical shadow [0,.1] and high-end [.9,1] ramps; for Low Key this is specular/high-end response, not a general highlights contract. WARN retained for historical comparison.")
                    }
                    if name.contains("protected") {
                        var unprotected=fx;unprotected[protection]=0
                        let other=try render(chart.image,[unprotected])
                        let unprotectedMetrics=gpu.compare(chart.image,other)
                        let endpoint=kind == .highKey ? "gray-0.98":"gray-0.02"
                        let endpointRegion=chart.regions.first { $0.name==endpoint }!.rect
                        let endpointWithout=gpu.compare(chart.image,other,region:endpointRegion)
                        let endpointWith=regions[endpoint]!
                        result.metrics["protectedNearEndpointChange"]=endpointWith.residual.mean
                        result.metrics["unprotectedNearEndpointChange"]=endpointWithout.residual.mean
                        result.check("Protection preserves near-endpoint detail",abs(endpointWith.residual.mean)<abs(endpointWithout.residual.mean),"Compare gray .98 for High Key and .02 for Low Key at identical Amount/Dynamic; protected patch should move less even when no pixels clip.")

                        result.check("Protection clipping comparison",kind == .highKey ? m.whiteOutput<=unprotectedMetrics.whiteOutput : m.blackOutput<=unprotectedMetrics.blackOutput,"Compare identical settings except protection=0. Equality may be inconclusive when neither output clips.")
                        result.metrics["unprotectedWhiteClippingPixels"]=Double(unprotectedMetrics.whiteOutput)
                        result.metrics["unprotectedBlackClippingPixels"]=Double(unprotectedMetrics.blackOutput)
                        try artifacts.png(other,"\(folder)/unprotected.png")
                    }
                    // Endpoint identity is an analytic reference, independent of any renderer output.
                    if params["glow"] == 0 {
                        let black=regions["gray-0.0"]!,white=regions["gray-1.0"]!
                        result.check("Known black and white endpoints",black.maxError<2e-6 && white.maxError<2e-6,hard:true,"Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.")
                    }
                    try baseline(output,fx,id,&result)
                    try artifacts.png(output,"\(folder)/\(name).png")
                    try artifacts.png(artifacts.difference(chart.image,output),"\(folder)/\(name)_difference_x4.png")
                    try artifacts.plot([("Input (x: normalized luminance)",ramp.transferInput),("Output",ramp.transferOutput)],"\(folder)/\(name)_transfer_curve.png",title:"\(id) transfer curve — linear RGB",yRange:0...1)
                    try artifacts.plot([("Input",m.histogramInput.map(Double.init)),("Output",m.histogramOutput.map(Double.init))],"\(folder)/\(name)_histogram.png",title:"Luminance [0,1], HDR overflow in end bins")
                    try artifacts.json(regions,"Reports/\(id)_patches.json")
                    result.images=["\(folder)/\(name).png","\(folder)/\(name)_difference_x4.png","\(folder)/\(name)_transfer_curve.png"]
                    cases.append(result);sheet.append((id,output))
                }
            }
            try artifacts.sheet(sheet,"\(folder)/contact_sheet.png")
            try artifacts.sheet(sheet,"ContactSheets/\(folder)_100percent.png",nativeCrop:true)
            // Independent analytical expected for the neutral/zero-amount transform.
            let zero=try render(chart.image,[effect(kind,["amount":0])])
            let identity=gpu.compare(chart.image,zero)
            var c=LabCase(name:prefix+"00_identity")
            c.check("Amount zero identity",identity.maxError<2e-6,hard:true,"Expected = untouched analytic chart, not an effect render.")
            c.metrics=["identityMaxError":identity.maxError]
            try artifacts.png(chart.image,"\(folder)/identity_expected.png")
            try artifacts.png(zero,"\(folder)/identity_obtained.png")
            try artifacts.png(artifacts.difference(chart.image,zero),"\(folder)/identity_difference_x4.png")
            cases.append(c)
        }
    }
    func grainTests() throws {
        let chart=SyntheticCharts.grain(size:size)
        try artifacts.png(chart.image,"Grain/master_input.png")
        try artifacts.json(chart.regions,"Reports/grain-regions.json")
        let configurations:[(String,[String:Double])] = [
            ("fine",["size":12]),("medium",["size":40]),("large",["size":85]),
            ("soft",["hardness":0]),("hardness_medium",["hardness":50]),("hard",["hardness":100]),
            ("monochromatic",[:]),
            ("clumping_zero",["clumping":0]),("clumping_medium",["clumping":50]),("clumping_strong",["clumping":100]),
            ("softness_zero",["softness":0]),("softness_strong",["softness":100]),
            ("response_shadow",["shadowAmount":200,"midtoneAmount":0,"highlightAmount":0]),
            ("response_midtone",["shadowAmount":0,"midtoneAmount":200,"highlightAmount":0]),
            ("response_highlight",["shadowAmount":0,"midtoneAmount":0,"highlightAmount":200]),
            ("chromatic",["chromaAmount":100])]
        var structures:[String:Structure]=[:],stats:[String:[String:Comparison]]=[:]
        var sheet:[(String,CIImage)]=[("Original",chart.image)]
        let structuralInput=SyntheticCharts.gray(0.3,size:size)
        let analysisRegion=CGRect(x:size/2-128,y:size/2-128,width:256,height:256)
        for (name,params) in configurations {
            try autoreleasepool {
                progress("Grain " + name)
                var fx=effect(.grain,params);fx["amount"]=60
                if name=="chromatic" { fx.monochromatic=false }
                try artifacts.json(fx.validated,"Reports/grain_\(name)_settings.json")
                let output=try render(chart.image,[fx]),uniform=try render(structuralInput,[fx])
                let m=gpu.compare(chart.image,output)
                var patches:[String:Comparison]=[:]
                for p in chart.regions { patches[p.name]=gpu.compare(chart.image,output,region:p.rect) }
                stats[name]=patches
                let structure=gpu.structure(structuralInput,uniform,region:analysisRegion);structures[name]=structure
                var c=LabCase(name:"Grain_"+name)
                c.metrics=["meanResidual":m.residual.mean,"residualVariance":m.residual.variance,"residualSD":m.residualStd,"chromaVariance":m.chromaResidual.variance,"spectralCentroidCyclesPerPixel":structure.spectralCentroid,"peakFrequencyCyclesPerPixel":structure.peakFrequency,"highFrequencyEnergyFraction":structure.highFrequencyEnergy,"edgeRMS":structure.edgeRMS,"edgeP95":structure.edgeP95]
                c.check("Finite output",m.nonFinite==0,hard:true,"No non-finite pixels.")
                for (key,p) in patches {
                    c.check("Mean residual \(key)",abs(p.residual.mean)<0.001+0.01*p.input.mean,"Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.")
                    c.metrics[key+"-residualSD"]=p.residualStd
                }
                if name=="medium" {
                    // This is explicitly a repeatability property, NOT an expected-image oracle.
                    let repeatOutput=try render(chart.image,[fx])
                    let repeated=gpu.compare(output,repeatOutput)
                    c.metrics["repeatMaxError"]=repeated.maxError
                    c.check("Same-seed determinism",repeated.maxError<=1e-6,hard:true,"Two executions, same source/settings/seed; tolerance 1e-6.")
                    var changed=fx;changed.seed += 1
                    let other=try render(chart.image,[changed]),spatial=gpu.compare(output,other)
                    let otherResidual=gpu.compare(chart.image,other)
                    c.check("Different seed changes pattern",spatial.rmse>1e-6,hard:true,"Different seeds must change spatial content.")
                    let ratio=otherResidual.residualStd/max(m.residualStd,1e-12)
                    c.check("Seed distribution similarity",ratio>0.8 && ratio<1.2,"Residual SD ratio in [0.8,1.2], allowing finite sample variation.")
                    c.metrics["differentSeedRMSE"]=spatial.rmse;c.metrics["seedSDRatio"]=ratio
                    try artifacts.png(other,"Grain/different_seed.png")
                    try artifacts.plot([("Residual [-.25,.25]",m.histogramResidual.map(Double.init))],"Grain/residual_histogram.png",title:"Grain residual histogram; overflow in endpoints")
                }
                try baseline(output,fx,"grain_"+name,&c)
                try artifacts.png(output,"Grain/\(name).png")
                try artifacts.png(artifacts.difference(chart.image,output,gain:16),"Grain/\(name)_difference_x16.png")
                try artifacts.json(patches,"Reports/grain_\(name)_patches.json")
                try artifacts.json(structure,"Reports/grain_\(name)_structure.json")
                c.images=["Grain/\(name).png","Grain/\(name)_difference_x16.png"]
                cases.append(c)
                if ["fine","medium","large","soft","hard","clumping_strong"].contains(name) { sheet.append((name,output)) }
            }
        }
        try artifacts.sheet(sheet,"Grain/contact_sheet.png")
        // Uniform mid-gray crops reveal texture at one photo pixel per output PNG pixel.
        let cropSheet=try ["fine","medium","large","soft","hard","clumping_strong"].map { name -> (String,CIImage) in
            let params=configurations.first{$0.0==name}!.1
            var fx=effect(.grain,params);fx["amount"]=60
            return (name,try render(structuralInput,[fx]))
        }
        try artifacts.sheet(cropSheet,"ContactSheets/Grain_100percent.png",nativeCrop:true)
        try artifacts.plot([("Fine",structures["fine"]!.spectrum),("Medium",structures["medium"]!.spectrum),("Large",structures["large"]!.spectrum)],"Grain/spectrum.png",title:"Radial energy / frequency 0…0.5 cycles per pixel",xMaximum:0.5)
        let offsets=["1,0","0,1","1,1","2,0","0,2","4,0"]
        try artifacts.plot([("Fine",offsets.map{structures["fine"]!.autocorrelation[$0]!}),("Medium",offsets.map{structures["medium"]!.autocorrelation[$0]!}),("Large",offsets.map{structures["large"]!.autocorrelation[$0]!})],"Grain/autocorrelation.png",title:"Offsets (1,0) (0,1) (1,1) (2,0) (0,2) (4,0)",yRange:-1...1)
        for (title,a,b) in [("hardness","soft","hard"),("clumping","clumping_zero","clumping_strong"),("softness","softness_zero","softness_strong")] {
            try artifacts.plot([(a,structures[a]!.spectrum),(b,structures[b]!.spectrum)],"Grain/\(title)_spectrum.png",title:"\(title): normalized spectral energy",xMaximum:0.5)
        }
        var c=LabCase(name:"Grain_properties")
        c.check("Size moves energy to lower frequencies",structures["fine"]!.spectralCentroid>structures["medium"]!.spectralCentroid && structures["medium"]!.spectralCentroid>structures["large"]!.spectralCentroid,"Compare normalized radial energy centroids at fixed source dimensions and seed.")
        c.check("Spatial correlation",structures["medium"]!.autocorrelation["1,0"]!>0.1,"Adjacent residual correlation > .1; distinguishes from independent white noise, not proof of photographic quality.")
        c.check("Hardness changes edge distribution",abs(structures["hard"]!.edgeRMS-structures["soft"]!.edgeRMS)>1e-6,"Report high-frequency fraction and edge RMS/P95 separately.")
        c.check("Clumping changes normalized structure",abs(structures["clumping_zero"]!.spectralCentroid-structures["clumping_strong"]!.spectralCentroid)>0.001,"Centroid shift > .001 cycles/pixel; a pure amplitude change would not change normalized spectrum.")
        c.check("Softness changes normalized structure",abs(structures["softness_zero"]!.spectralCentroid-structures["softness_strong"]!.spectralCentroid)>0.001,"Centroid shift > .001 cycles/pixel; alert if this acts mostly as Amount.")
        let s=stats["response_shadow"]!,m=stats["response_midtone"]!,h=stats["response_highlight"]!
        c.check("Shadow response selectivity",s["uniform-0.05"]!.residualStd>s["uniform-0.85"]!.residualStd,"Isolated shadow response, others zero.")
        c.check("Midtone response selectivity",m["uniform-0.3"]!.residualStd>m["uniform-0.05"]!.residualStd && m["uniform-0.3"]!.residualStd>m["uniform-0.95"]!.residualStd,"Response weights operate in sqrt-linear lightness; representative midtone is linear .3.")
        c.check("Highlight response selectivity",h["uniform-0.85"]!.residualStd>h["uniform-0.05"]!.residualStd,"Isolated highlight response, others zero.")
        let neutralMono=stats["monochromatic"]!["uniform-0.3"]!,neutralColor=stats["chromatic"]!["uniform-0.3"]!
        c.check("Color grain has measurable chroma",neutralColor.chromaResidual.variance>neutralMono.chromaResidual.variance+1e-12,"Chroma proxy = residual R−G variance on neutral patch.")
        c.check("Color channels remain correlated",structures["chromatic"]!.rgbCorrelation.values.allSatisfy{$0>0.5},"Pairwise residual RGB correlation > .5; not independent RGB noise.")
        let zero=try render(chart.image,[effect(.grain,["amount":0])]),identity=gpu.compare(chart.image,zero)
        c.check("Amount zero identity",identity.maxError<2e-6,hard:true,"Expected is the original source, not another renderer output.")
        c.metrics["zeroAmountMaxError"]=identity.maxError
        try artifacts.png(chart.image,"Grain/identity_expected.png");try artifacts.png(zero,"Grain/identity_obtained.png")
        try artifacts.png(artifacts.difference(chart.image,zero),"Grain/identity_difference_x4.png")
        cases.append(c)
    }
    func structuralTests() throws {
        for (name,input) in [("Edges",SyntheticCharts.edges(size:size)),("Textures",SyntheticCharts.textures(size:size))] {
            var sheet=[("Original",input)]
            for (id,fx) in [("HighKey",effect(.highKey)),("HighKeyGlow",effect(.highKey,["glow":60])),("LowKey",effect(.lowKey)),("LowKeyGlow",effect(.lowKey,["glow":60])),("Grain",effect(.grain))] {
                let output=try render(input,[fx]),m=gpu.compare(input,output)
                try artifacts.png(output,"\(name)/\(id).png")
                sheet.append((id,output))
                var c=LabCase(name:name+"_"+id)
                c.check("Finite structure output",m.nonFinite==0,hard:true,"No NaN/Inf on edges or fine patterns.")
                c.metrics=["MAEFromInput":m.mae,"minimum":m.output.min,"maximum":m.output.max]
                if name=="Edges" {
                    let profile=gpu.compare(input,output,region:CGRect(x:0,y:Double(size)*0.9,width:Double(size),height:1),ramp:true)
                    try artifacts.plot([("Input",profile.transferInput),("Output",profile.transferOutput)],"Edges/\(id)_profile.png",title:"Hard edge profile; glow is intentionally nonlocal")
                    c.metrics["hardEdgeRangeOvershoot"]=max(0,max(profile.output.max-1,-profile.output.min))
                    c.check("Hard-edge overshoot",c.metrics["hardEdgeRangeOvershoot"]!<0.002,"Outside [0,1] overshoot > .002 is suspicious on this neutral edge. This does not score intentional glow spread.")
                }
                cases.append(c)
            }
            try artifacts.png(input,"\(name)/input.png")
            try artifacts.sheet(sheet,"ContactSheets/\(name).png")
            try artifacts.sheet(sheet,"ContactSheets/\(name)_100percent.png",nativeCrop:true)
        }
        let quadrants=SyntheticCharts.make(size:size) { x,y in SIMD3(repeating:Float(0.15+(x>0.5 ? 0.2:0)+(y>0.5 ? 0.1:0))) }
        var radial=RadialGradientMask();radial.center = .init(x:0.25,y:0.25);radial.radiusX=0.2;radial.radiusY=0.2
        let mask=LocalMask(name:"Upper left test region",components:[MaskComponent(shape:.radial(radial))])
        let inside=CGRect(x:Double(size)*0.23,y:Double(size)*0.73,width:Double(size)*0.04,height:Double(size)*0.04).integral
        let outside=CGRect(x:Double(size)*0.65,y:Double(size)*0.15,width:Double(size)*0.2,height:Double(size)*0.2).integral
        for kind in [CreativeEffectKind.highKey,.grain] {
            var fx=effect(kind);fx.maskID=mask.id
            let output=try render(quadrants,[fx],masks:[mask]),changed=gpu.compare(quadrants,output,region:inside),untouched=gpu.compare(quadrants,output,region:outside)
            var c=LabCase(name:"Mask_"+kind.rawValue)
            c.metrics=["insideRMSE":changed.rmse,"outsideMaxError":untouched.maxError]
            c.check("Inside changes",changed.rmse>1e-6,hard:true,"Known geometric center is inside the existing radial mask.")
            c.check("Outside unchanged",untouched.maxError<2e-6,hard:true,"Expected outside is the unmodified analytic quadrant source, independently of MaskRenderer.")
            try artifacts.sheet([("Original",quadrants),("Masked "+kind.rawValue,output),("Difference x4",artifacts.difference(quadrants,output))],"Masks/\(kind.rawValue).png")
            cases.append(c)
        }
        let high=effect(.highKey,["amount":85]),grain=effect(.grain,["amount":85])
        let a=try render(quadrants,[high,grain]),b=try render(quadrants,[grain,high]),comparison=gpu.compare(a,b)
        var c=LabCase(name:"EffectStack_order")
        c.check("Order affects output",comparison.rmse>1e-6,hard:true,"Compares two permitted orders, not an expected image.")
        c.metrics=["orderRMSE":comparison.rmse,"orderMaxError":comparison.maxError]
        try artifacts.sheet([("High Key > Grain",a),("Grain > High Key",b),("Difference x16",artifacts.difference(a,b,gain:16))],"EffectStack/comparison.png",nativeCrop:true)
        cases.append(c)
        // Sample the response envelope at constant luminance, separating it from random pattern variation.
        for parameter in ["shadowAmount","midtoneAmount","highlightAmount"] {
            var fx=effect(.grain,["amount":75,"shadowAmount":0,"midtoneAmount":0,"highlightAmount":0]);fx[parameter]=200
            var envelope:[Double]=[]
            for step in 0...64 {
                let input=SyntheticCharts.gray(Double(step)/64,size:512),output=try render(input,[fx])
                envelope.append(gpu.compare(input,output,region:CGRect(x:128,y:128,width:64,height:64)).residualStd)
            }
            let jump=zip(envelope.dropFirst(),envelope).map{abs($0-$1)}.max() ?? 0
            var c=LabCase(name:"Grain_continuity_"+parameter)
            c.metrics=["maximumSDJumpPer1over64Luminance":jump]
            c.check("Continuous response envelope",jump<0.01,"Heuristic: residual SD must not jump by > .01 linear across adjacent 1/64 luminance samples. Inspect the full curve for subtler changes.")
            try artifacts.plot([(parameter,envelope)],"Grain/\(parameter)_response.png",title:"Residual SD vs linear luminance [0,1]")
            cases.append(c)
        }
    }
    func scenesAndAssets() throws {
        for name in ["portrait","landscape","night","still-life"] {
            try renderScene(SyntheticCharts.scene(name,size:size),name:name,folder:"Scenes")
        }
        let env=ProcessInfo.processInfo.environment
        let assets=URL(fileURLWithPath:env["LUMORA_VISUAL_ASSETS"] ?? URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("VisualTestAssets").path)
        let files=(try? FileManager.default.contentsOfDirectory(at:assets,includingPropertiesForKeys:[.isRegularFileKey])) ?? []
        let candidates=files.filter{["png","jpg","jpeg","tif","tiff","heic","dng"].contains($0.pathExtension.lowercased())}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        if candidates.isEmpty { var c=LabCase(name:"User_photographs");c.notes=["No user photographs supplied; optional assets are not a failure."];cases.append(c) }
        for (index,file) in candidates.enumerated() {
            guard var input=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {
                var c=LabCase(name:"User_photo_\(index)");c.check("Readable optional asset",false,"Could not decode \(file.lastPathComponent); other assets continue.");cases.append(c);continue
            }
            input=input.transformed(by:CGAffineTransform(translationX:-input.extent.minX,y:-input.extent.minY))
            // User images remain full resolution for native crops; each graph is released after its sheet.
            try autoreleasepool { try renderScene(input,name:"photo-\(index)",folder:"Photographs") }
        }
    }
    func renderScene(_ input:CIImage,name:String,folder:String) throws {
        var items=[("Original",input)],c=LabCase(name:folder+"_"+name)
        for kind in CreativeEffectKind.allCases {
            let output=try render(input,[effect(kind)])
            let center=CGRect(x:floor(input.extent.midX-128),y:floor(input.extent.midY-128),width:256,height:256).intersection(input.extent)
            let m=gpu.compare(input,output,region:center)
            c.check("Finite "+kind.rawValue,m.nonFinite==0,hard:true,"Central native crop checked numerically; scene quality remains a visual judgment.")
            c.metrics[kind.rawValue+"-centerMeanChange"]=m.residual.mean
            items.append((kind.rawValue,output))
        }
        try artifacts.sheet(items,"\(folder)/\(name).png")
        try artifacts.sheet(items,"\(folder)/\(name)_100percent.png",nativeCrop:true)
        c.images=["\(folder)/\(name).png","\(folder)/\(name)_100percent.png"]
        cases.append(c)
    }
    func normalized(_ image:CIImage,to side:Int)->CIImage {
        image.applyingFilter("CILanczosScaleTransform",parameters:[kCIInputScaleKey:Double(side)/image.extent.width,kCIInputAspectRatioKey:1]).cropped(to:CGRect(x:0,y:0,width:side,height:side))
    }
    func correlation(_ a:CIImage,_ b:CIImage,region:CGRect)->Double {
        let aa=gpu.read(a,region),bb=gpu.read(b,region),n=aa.count/4
        let ma=(0..<n).reduce(0.0){$0+LabGPU.luma(aa,$1*4)}/Double(n),mb=(0..<n).reduce(0.0){$0+LabGPU.luma(bb,$1*4)}/Double(n)
        var xy=0.0,xx=0.0,yy=0.0
        for i in 0..<n { let x=LabGPU.luma(aa,i*4)-ma,y=LabGPU.luma(bb,i*4)-mb;xy+=x*y;xx+=x*x;yy+=y*y }
        return xx*yy>1e-30 ? xy/sqrt(xx*yy):0
    }
    func resolutionTests() throws {
        let dimensions=full ? [1024,2048,4096]:[256,512,1024]
        let target=dimensions[0],fx=effect(.grain,["amount":75,"size":60])
        var normalizedImages:[(String,CIImage)]=[],timings:[String:Double]=[:]
        for dimension in dimensions {
            let input=SyntheticCharts.gray(0.3,size:dimension),output=try render(input,[fx])
            let start=ContinuousClock.now
            // Forces complete materialization, includes CPU allocation and GPU readback.
            let buffer=gpu.read(output,output.extent)
            let duration=start.duration(to:.now)
            timings["\(dimension)-milliseconds"]=Double(duration.components.seconds)*1000+Double(duration.components.attoseconds)/1e15
            var c=LabCase(name:"Performance_\(dimension)")
            c.metrics=["millisecondsIncludingReadback":timings["\(dimension)-milliseconds"]!,"width":Double(dimension),"height":Double(dimension),"readbackBytes":Double(buffer.count*4)]
            c.notes=["Metal CIContext: \(gpu.deviceName). Wall time includes allocation/readback, not isolated GPU kernel time. No machine-dependent speed assertion."]
            cases.append(c)
            normalizedImages.append(("\(dimension) normalized to \(target)",normalized(output,to:target)))
            try artifacts.png(output,"Grain/resolution_\(dimension).png")
        }
        let roi=CGRect(x:0,y:0,width:target,height:target)
        var c=LabCase(name:"Grain_resolution_consistency")
        for i in 1..<normalizedImages.count {
            let a=normalizedImages[0].1,b=normalizedImages[i].1,m=gpu.compare(a,b),corr=correlation(a,b,region:roi)
            c.metrics["\(dimensions[i])-normalizedRMSE"]=m.rmse;c.metrics["\(dimensions[i])-normalizedSSIM"]=m.ssim
            c.metrics["\(dimensions[i])-patternCorrelation"]=corr
            c.check("Pattern correlation \(dimensions[i])",corr>0.75,"Compare equal photographic fields after Lanczos normalization, not fixed-size native crops. .75 is a diagnostic threshold allowing preview frequency attenuation.")
            let ref=gpu.compare(SyntheticCharts.gray(0.3,size:target),a),other=gpu.compare(SyntheticCharts.gray(0.3,size:target),b)
            let ratio=other.residualStd/max(ref.residualStd,1e-12)
            c.metrics["\(dimensions[i])-grainSDRatio"]=ratio
            c.check("Normalized grain strength \(dimensions[i])",ratio>0.65 && ratio<1.5,"SD ratio [0.65,1.5] flags substantial perceived-strength disagreement, independently of spatial alignment.")
        }
        try artifacts.sheet(normalizedImages,"Grain/resolution_comparison.png",nativeCrop:true)
        c.images=["Grain/resolution_comparison.png"];cases.append(c)
    }
    func previewExportTests() async throws {
        let dimension=full ? 4096:1024,input=SyntheticCharts.gray(0.3,size:dimension)
        let source=try artifacts.url("Pipeline/source.png");try artifacts.png(input,"Pipeline/source.png")
        let engine=RenderEngine()
        var state=EditState();state.creative.effects=[effect(.grain,["amount":75,"size":60])]
        var images:[(String,CIImage)]=[],c=LabCase(name:"Real_preview_HQ_export")
        for quality in [PreviewQuality.interactive,.high] {
            let result=try await engine.render(url:source,state:state,quality:quality)
            let name=quality == .interactive ? "preview":"hq"
            let image=CIImage(cgImage:result.image)
            images.append((name,image));c.metrics[name+"-milliseconds"]=result.milliseconds
            c.metrics[name+"-width"]=Double(result.image.width)
            c.notes.append(name+" execution path: "+(result.gpu ? "GPU":"CPU"))
        }
        var settings=ExportSettings();settings.format = .png;settings.colorSpace = .displayP3;settings.includeMetadata=false
        let start=ContinuousClock.now
        let exported=try await engine.export(request:ExportRequest(sourceURL:source,state:state,name:"lab"),settings:settings,directory:artifacts.url("Pipeline/Export"))
        let duration=start.duration(to:.now)
        c.metrics["export-milliseconds"]=Double(duration.components.seconds)*1000+Double(duration.components.attoseconds)/1e15
        guard let output=CIImage(contentsOf:exported.url) else { throw LabError.render }
        images.append(("export",output));c.metrics["export-width"]=Double(exported.width)
        let target=Int(images[0].1.extent.width),roi=CGRect(x:target/4,y:target/4,width:target/2,height:target/2)
        let comparable=images.map{($0.0,normalized($0.1,to:target))}
        for (name,image) in images {
            let extent=image.extent,crop=CGRect(x:extent.width/4,y:extent.height/4,width:extent.width/2,height:extent.height/2).integral
            try artifacts.png(image.cropped(to:crop),"Pipeline/\(name)_crop.png")
        }
        for i in 0..<2 {
            let name=comparable[i].0,a=comparable[i].1,b=comparable[2].1
            let m=gpu.compare(a,b,region:roi),corr=correlation(a,b,region:roi)
            c.metrics[name+"-exportRMSE"]=m.rmse;c.metrics[name+"-exportSSIM"]=m.ssim;c.metrics[name+"-exportCorrelation"]=corr
            c.check(name+" perceptual agreement",m.ssim>0.95 && corr>0.7,"Equal-field crops normalized to interactive preview dimensions; SSIM>.95 and correlation>.7 are quality heuristics, not byte-equality assertions.")
        }
        try artifacts.sheet(comparable,"Pipeline/comparison.png",nativeCrop:true)
        try artifacts.sheet(images,"Pipeline/native_crops.png",nativeCrop:true)
        c.images=["Pipeline/comparison.png","Pipeline/native_crops.png"];cases.append(c)
    }
    func writeReport() throws {
        try artifacts.json(cases,"Reports/metrics.json")
        var text="""
        # Lumora Creative FX Validation

        Mode: **\(full ? "FULL 4096²":"QUICK 512²")**. Metal device: **\(gpu.deviceName)**.
        Measurement: extended linear sRGB / RGBA Float32 before display conversion.
        Generated: \(ISO8601DateFormatter().string(from:Date())). Chart SHA256: `\(sourceIdentity)`.

        PASS means the listed property passed, not aesthetic approval. WARN is a quality heuristic requiring review; FAIL is a broken hard invariant. No effect algorithms were changed by this lab.
        No Golden Masters are recorded by default. Mathematical references are independent source/endpoint identities. Repeated renders test determinism only, never serve as expected-output oracles.

        ## Summary

        | Case | Status |
        | --- | --- |
        """
        for c in cases { text += "\n| \(c.name) | \(c.status) |" }
        text += "\n\n## Important comparison sheets\n\n"
        for path in ["HighKey/contact_sheet.png","LowKey/contact_sheet.png","LowKey/dynamic_luminance_absolute.png","LowKey/dynamic_luminance_relative.png","LowKey/dynamic_transfer.png","LowKey/dynamic_contact_sheet.png","Grain/contact_sheet.png","ContactSheets/Grain_100percent.png","Grain/spectrum.png","Grain/autocorrelation.png","Grain/resolution_comparison.png","Pipeline/comparison.png","ContactSheets/Edges.png","Masks/highKey.png","Masks/grain.png","EffectStack/comparison.png"] {
            text += "- [\(path)](\(path))\n"
        }
        text += "\n## Low Key photographic contract\n\n"
        text += "Five input-linear zones: deep shadows [0,.10), shadows [.10,.30), midtones [.30,.65), bright tones [.65,.90), specular whites [.95,1]. [.90,.95] is a transition excluded from zone averages, included in full-curve checks. Absolute change is signed mean(output-input), in linear luminance units; relative change is that value divided by mean(input). Legacy [.90,1] is specular/high-end response, not a general highlights measure. Historical WARN remains visible.\n\n"
        text += "Dynamic sweep: Amount=.60; Dynamic=0,.25,.50,.75,1; all other fields identical. Progressive shadow reduction, bright-tone increase and rightward loss centroid are quality expectations, reported honestly as WARN if absent. Specular protection is evaluated separately. Finiteness and no tonal inversions are hard invariants.\n\n"
        text += "| Dynamic | Zone | Absolute change | Relative change |\n| --- | --- | ---: | ---: |\n"
        for c in cases where c.name.hasPrefix("LK_DynamicSweep_") {
            for zone in Self.lowKeyZones {
                text += String(format: "| %.2f | %@ | %.6f | %.3f %% |\n", c.metrics["dynamic"]!, zone.name, c.metrics[zone.name + "-absoluteChange"]!, 100 * c.metrics[zone.name + "-relativeChange"]!)
            }
        }
        text += "\n## Interpretation and thresholds\n\n"
        text += "All tolerances are specified per check below. Hard invariants: finite pixels, neutral identity/endpoints (2e-6 linear RGB), same-seed repeatability (1e-6), outside-mask identity, nonzero inside-mask/order response, and separately reviewed golden agreement. Quality heuristics do not fail the test process. Clipping counts include known black/white/HDR sources: inspect increases relative to input, not absolute counts alone. SDR PNGs clip HDR for viewing; Charts/master_linear.tiff preserves source headroom. Histograms clamp overflow into endpoint bins. Residual histograms cover [-.25,.25]. SSIM is mean non-overlapping 8×8 luminance-window SSIM with L=1, C1=.0001, C2=.0009; not multiscale SSIM. Spectrum uses a mean-subtracted Hann-windowed 256px (or smaller power-of-two) residual and vDSP 2D FFT; radial bins contain total energy, normalized to unity. Physical runtime/thermal behavior requires an iPhone measurement.\n"
        for c in cases {
            text += "\n## \(c.name) — \(c.status)\n\n"
            for key in c.metrics.keys.sorted() { text += "- \(key): \(String(format:"%.8g",c.metrics[key]!))\n" }
            for check in c.checks { text += "- **\(check.status)** \(check.name) [\(check.hard ? "hard invariant":"quality heuristic")]: \(check.detail)\n" }
            for note in c.notes { text += "- \(note)\n" }
            for path in c.images { text += "- [\(path)](\(path))\n" }
        }
        text += "\nFull patch statistics (mean, M2/count for variance, range, residual, clipping and transfer samples) and structural measurements are in [Reports](Reports/). Performance values include full materialization/readback or the existing preview/export timing, not isolated GPU execution time.\n"
        try text.write(to:artifacts.url("CreativeFXValidationReport.md"),atomically:true,encoding:.utf8)
        try text.write(to:artifacts.url("report.md"),atomically:true,encoding:.utf8)
    }
}
