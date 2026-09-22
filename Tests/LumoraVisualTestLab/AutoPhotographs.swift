import Foundation
import CoreImage
@testable import LumoraCore

extension AutoValidation {
    func photographs() async throws {
        lab.progress("Auto: eight photographs, fixed first-run heuristics, reduced/full analysis and real renderer comparisons")
        files=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("VisualTestAssets"),includingPropertiesForKeys:nil)
            .filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count==8 else { throw LabError.configuration }
        var contact:[(String,CIImage)]=[],matrix:[(String,CIImage)]=[],priority:[(String,CIImage)]=[],histograms:[(String,[Double])]=[]
        var bestScore=Double.infinity,bestItems:[(String,CIImage)]=[]
        var roundtrips:[(String,CIImage)]=[]
        resolutionRows="| Photo | Reference size | P50 delta | P95 delta | Black fraction delta | White fraction delta | RGB mean max delta | WB confidence delta | EV delta | Temperature delta | Tint delta |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
        for (index,file) in files.enumerated() {
            let name=file.deletingPathExtension().lastPathComponent
            lab.progress("Auto photograph "+name)
            guard let full=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else { throw LabError.render }
            await engine.clearCaches()
            let first=try await engine.autoAnalysis(url:file,state:EditState())
            timings["Analysis uncached + proposal",default:[]].append(first.milliseconds)
            let proposal=first.proposal,a=proposal.analysis
            let cached=try await engine.autoAnalysis(url:file,state:EditState())
            timings["Analysis cached",default:[]].append(cached.milliseconds)
            let input=reduced(full,side:1024),items=try await variants(input,proposal)
            let small=items.map{($0.0,reduced($0.1))},m=lab.gpu.compare(small[1].1,small[5].1)
            let out=analysis(items[1].1)
            var c=LabCase(name:"Auto photo "+name)
            c.check("Analysis cache",cached.cacheHit && cached.proposal.analysis==a,hard:true,"Same input source reuses shared analysis and all mappings")
            for run in 0..<3 {
                let fresh=RenderEngine(),r=try await fresh.autoAnalysis(url:file,state:EditState())
                c.check("Fresh session repeat \(run)",r.proposal.analysis==a && r.proposal.intent==proposal.intent && r.proposal.curves[.balanced]!.curve==proposal.curves[.balanced]!.curve,hard:true,"Bit-identical statistics, intent and points")
            }
            let start=ContinuousClock.now,_=ImageAnalysis.measure(pixels(full))
            timings["ImageAnalysis",default:[]].append(elapsed(start))
            let intentStart=ContinuousClock.now,intent=AutoCorrectionIntent(analysis:a)
            timings["Intent",default:[]].append(elapsed(intentStart))
            let lightStart=ContinuousClock.now,_=intent.light
            timings["Light mapping",default:[]].append(elapsed(lightStart))
            let colorStart=ContinuousClock.now,_=intent.color
            timings["Color mapping",default:[]].append(elapsed(colorStart))
            let curveStart=ContinuousClock.now,fit=AutoTonalMapping.fit(intent:intent)
            timings["Light→Curve",default:[]].append(elapsed(curveStart))
            for (title,image) in small {
                let stat=analysis(image)
                c.check(title+" finite",stat.nonFinite==0,hard:true,"Production graph, not a scalar proxy")
                let repeatImage=try await output(input,proposal.applying(title=="Auto Color" ? .color : .light,to:EditState()))
                if title=="Auto Light" { c.check("Render determinism",lab.gpu.compare(image,reduced(repeatImage)).maxError==0,hard:true,"Same production graph") }
            }
            c.metrics=["photoLightCurveMAE":m.mae,"photoLightCurveMax":m.maxError,
                       "originalMeanY":a.luminance.mean,"autoMeanY":out.luminance.mean,"originalP50":a.luminance.median,"autoP50":out.luminance.median,
                       "blackClipping":out.blackFraction,"whiteClipping":out.whiteFraction,"HDRFraction":a.hdrFraction]
            c.check("Light/Curve photographic agreement",m.mae<0.02 && m.maxError<0.12,"WARN above .02 mean/.12 max linear RGB; luminance-delta Light and per-channel Curves are not identical")
            c.check("Light/Curve neutral SDR fit",fit.sdr.maximum<0.05,"WARN for >.05 absolute max linear Y")
            c.check("Light/Curve neutral HDR fit",fit.hdr.maximum<0.05,"Report existing SDR curve-domain limitation")
            if index==4 {c.check("Night preserved",out.luminance.mean < max(0.14,a.luminance.mean*1.6),"Mean Y may increase moderately; inspect lamp/street/sky/pavement")}
            if index==6 {c.check("High key preserved",out.luminance.median > a.luminance.median*0.75,"Median must retain at least 75% of original bright scene")}
            if index==3 {c.check("Backlight compromise",out.whiteFraction-a.whiteFraction<0.02,"No >2% extra white-boundary occupancy; inspect face and sun")}
            // A reference read uses the full visible image; no thumbnail for the reference.
            let reference=analysis(full,maximum:Int(max(full.extent.width,full.extent.height))),refIntent=AutoCorrectionIntent(analysis:reference)
            let rgbDelta=zip(a.rgb,reference.rgb).map{abs($0.mean-$1.mean)}.max() ?? 0
            resolutionRows += "| \(name) | \(Int(max(full.extent.width,full.extent.height))) | \(abs(a.luminance.median-reference.luminance.median)) | \(abs(a.luminance.percentiles[4]-reference.luminance.percentiles[4])) | \(abs(a.blackFraction-reference.blackFraction)) | \(abs(a.whiteFraction-reference.whiteFraction)) | \(rgbDelta) | \(abs(a.neutralConfidence-reference.neutralConfidence)) | \(abs(intent.exposureShiftEV-refIntent.exposureShiftEV)) | \(abs(intent.temperatureIntent-refIntent.temperatureIntent)) | \(abs(intent.tintIntent-refIntent.tintIntent)) |\n"
            c.check("Analysis resolution decisions",abs(intent.exposureShiftEV-refIntent.exposureShiftEV)<0.15 && abs(intent.temperatureIntent-refIntent.temperatureIntent)<4 && abs(intent.tintIntent-refIntent.tintIntent)<4,"512px vs native reference: .15 EV and four color-slider units")
            for side in [1024,2048,4096] {
                let resized=full.transformed(by:CGAffineTransform(scaleX:Double(side)/full.extent.width,y:Double(side)/full.extent.width))
                let ri=AutoCorrectionIntent(analysis:analysis(resized))
                c.check("Resize \(side)",abs(ri.exposureShiftEV-intent.exposureShiftEV)<0.15 && abs(ri.temperatureIntent-intent.temperatureIntent)<4,"Sampling stability, same framing")
            }
            let root="Auto/RealPhotos/"+name
            try lab.artifacts.sheet(items,root+"/auto_comparison.png",cell:512,maxColumns:7)
            let regions=autoRegions(index)
            var crops:[(String,CIImage)]=[]
            for (label,x,y) in regions { for (title,image) in items { crops.append((label+" / "+title,autoCrop(image,x:x,y:y))) } }
            try lab.artifacts.sheet(crops,root+"/auto_crops.png",nativeCrop:true,cell:256,maxColumns:7)
            let comparison=[items[0],items[1],items[5],("Difference ×8",lab.artifacts.difference(items[1].1,items[5].1,gain:8))]
            try lab.artifacts.sheet(comparison,"Auto/LightToCurve/"+name+".png",cell:512,maxColumns:4)
            for j in [0,1,2,3,5] { contact.append((name+" / "+items[j].0,items[j].1)) }
            matrix += Array(comparison.dropFirst())
            if [0,2,3,4,6].contains(index) {priority += comparison}
            let principal=[items[0],items[1],items[2],items[3],items[5]]
            if let priorityName=[3:"backlight",4:"night",6:"high_key"][index] {
                try lab.artifacts.sheet(principal,"Auto/"+priorityName+"_intent_validation.png",cell:512,maxColumns:5)
                for (title,image) in principal {
                    let values=pixels(image);var bins=[Double](repeating:0,count:128)
                    for i in stride(from:0,to:values.count,by:4) {bins[min(127,max(0,Int(LabGPU.luma(values,i)*127)))]+=1}
                    let peak=max(1,bins.max() ?? 1);histograms.append((name+" "+title,bins.map{$0/peak}))
                }
            }
            let score=abs(intent.exposureShiftEV)+abs(intent.shadowLift)/100+abs(intent.highlightCompression)/100+abs(intent.temperatureIntent)/20+abs(intent.tintIntent)/20
            if score<bestScore {bestScore=score;bestItems=principal}
            let bestLight=AutoTonalMapping.approximate(fit.curve)
            let round=try await output(input,bestLight.settings)
            roundtrips += [(name+" Auto Light",items[1].1),("Equivalent Curve",items[5].1),("Best-fit Light",round)]
            let converted=proposal.applying(.curves,to:proposal.applying(.light,to:EditState()))
            let convertedImage=try await output(input,converted)
            c.check("No double correction rendered",lab.gpu.compare(reduced(convertedImage),small[5].1).maxError==0,hard:true,"Light→Auto Curve replaces, never adds equivalent correction")
            if index==0 {try lab.artifacts.sheet([items[1],("Light → Auto Curve",convertedImage),items[5]],"Auto/no_double_correction.png",cell:512,maxColumns:3)}
            records.append(.init(name:name,analysis:a,intent:intent,points:fit.curve.points,sdr:fit.sdr,hdr:fit.hdr,photoMAE:m.mae,photoMax:m.maxError,metrics:c.metrics))
            c.images=[root+"/auto_comparison.png",root+"/auto_crops.png","Auto/LightToCurve/"+name+".png"]
            lab.cases.append(c)
        }
        try lab.artifacts.sheet(contact,"Auto/real_photos_contact_sheet.png",cell:320,maxColumns:5)
        try lab.artifacts.sheet(matrix,"Auto/light_vs_curve_matrix.png",cell:384,maxColumns:3)
        try lab.artifacts.sheet(priority,"Auto/light_curve_equivalence_priority.png",cell:384,maxColumns:4)
        try lab.artifacts.sheet(bestItems,"Auto/already_good_validation.png",cell:512,maxColumns:5)
        try lab.artifacts.sheet(roundtrips,"Auto/light_curve_light_roundtrip.png",cell:320,maxColumns:3)
        try lab.artifacts.plot(histograms,"Auto/histogram_diagnostics.png",title:"Night / white subject / backlight: normalized Y distributions (SDR display boundary)")
        try lab.artifacts.json(records,"Auto/photo_measurements.json")
        try save(resolutionRows,"Auto/analysis_resolution_comparison.md")
    }
    func autoRegions(_ i:Int)->[(String,Double,Double)] {
        switch i {
        case 0:return [("skin",0.38,0.52),("eye",0.4,0.62),("lips",0.3,0.43),("hair",0.48,0.83)]
        case 1:return [("skin",0.47,0.54),("eyes",0.46,0.68),("hair",0.65,0.52),("clothing",0.74,0.2)]
        case 2:return [("clouds",0.61,0.78),("sky",0.3,0.92),("vegetation",0.5,0.3)]
        case 3:return [("face",0.45,0.72),("sun",0.65,0.7),("hair",0.25,0.57),("sea reflection",0.69,0.48)]
        case 4:return [("lamp",0.36,0.78),("sky",0.62,0.75),("stone",0.23,0.66),("wet pavement",0.55,0.17)]
        case 5:return [("deep shadows",0.3,0.59),("sunlit wall",0.75,0.72),("wood",0.56,0.33),("window",0.92,0.78)]
        case 6:return [("dress",0.37,0.43),("wall",0.9,0.43),("skin",0.44,0.73),("sky",0.75,0.81)]
        default:return [("skin",0.38,0.59),("hair",0.24,0.57),("fabric",0.36,0.4),("background",0.78,0.45)]
        }
    }
    func autoCrop(_ image:CIImage,x:Double,y:Double)->CIImage {
        let e=image.extent,s=min(256,e.width,e.height)
        return image.cropped(to:CGRect(x:floor(min(e.maxX-s,max(e.minX,e.minX+x*e.width-s/2))),y:floor(min(e.maxY-s,max(e.minY,e.minY+y*e.height-s/2))),width:s,height:s))
    }
}
