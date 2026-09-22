import Foundation
import CoreImage
@testable import LumoraCore

extension GradingPresetValidation {
    func photographs() async throws {
        files=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("VisualTestAssets"),includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard files.count==8 else {throw LabError.configuration}
        var all:[(String,CIImage)]=[],portrait:[(String,CIImage)]=[],cinema:[(String,CIImage)]=[],atmosphere:[(String,CIImage)]=[],special:[(String,CIImage)]=[]
        var skin:[(String,CIImage)]=[],warm:[(String,CIImage)]=[],cool:[(String,CIImage)]=[],split:[(String,CIImage)]=[],strength:[(String,CIImage)]=[]
        var afterAuto:[(String,CIImage)]=[],workflow:[(String,CIImage)]=[]
        for (index,file) in files.enumerated() {
            let name=file.deletingPathExtension().lastPathComponent
            lab.progress("Grading presets photo: "+name)
            guard let full=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
            let input=helper.reduced(full,side:1024)
            var images:[CIImage]=[],buffers:[[Float]]=[]
            let regions=regions(index)
            for preset in presets {
                let out=try await render(input,preset.settings),m=metric(input,out)
                images.append(out);buffers.append(samples(out,side:128))
                all.append((name+" / "+preset.title,out))
                var c=LabCase(name:name+" / "+preset.id);c.metrics=m
                c.check("Finite",m["nonfinite"]==0,hard:true,"Production graph")
                c.check("Luminance drift",abs(m["meanY"]!)<0.02 && m["maxY"]!<0.12,"Heuristic linear mean .02 / max .12; inspect photo family sheet")
                c.check("Extra clipping",m["clip"]!<0.02,"More than two percent additional white-boundary pixels warrants inspection")
                photoTable += "| \(name) | \(preset.id) | \(m["rgb"]!) | \(m["meanY"]!) | \(m["maxY"]!) | \(m["p05"]!) | \(m["p50"]!) | \(m["p95"]!) | \(m["p99"]!) | \(m["chroma"]!) | \(m["clip"]!) | \(m["nonfinite"]!) |\n"
                for (label,x,y) in regions {
                    let source=helper.autoCrop(input,x:x,y:y),crop=helper.autoCrop(out,x:x,y:y),r=metric(source,crop)
                    roiTable += "| \(name) / \(label) | \(preset.id) | \(r["meanY"]!) | \(r["maxY"]!) | \(r["chroma"]!) | \(r["clip"]!) | \(r["rgb"]!) |\n"
                    if label=="skin",preset.family == .portrait || preset.family == .cinematic {
                        c.check("Skin chromatic change",abs(r["chroma"]!)<0.025 && r["rgb"]!<0.04,"Fixed skin crop, not a detector or universal hue target; Δchroma .025 / RGB MAE .04 inspection trigger")
                    }
                    if label.hasPrefix("white") {c.check(label+" coloration",r["chroma"]!<0.025,"More than .025 added mean linear RGB chroma in white crop warrants inspection")}
                    if label=="shadow" || label=="sky",[4,5].contains(index) {c.check(label+" coloration",r["chroma"]!<0.015,"Dark-region mean chroma increase >.015 requires inspection; not a universal hue rule")}
                    if ["sun","lamp","sea reflection","highlight"].contains(label) {c.check(label+" coloration",r["chroma"]!<0.03,"Highlight crop chroma increase >.03 requires inspection")}
                }
                c.images=[root+"all_presets_contact_sheet.png"];lab.cases.append(c)
            }
            for i in presets.indices {for j in presets.indices {photoDistances[i][j] += mae(buffers[i],buffers[j])/8}}
            func items(_ choices:[ColorGradingPreset],original:Bool=true)->[(String,CIImage)] {
                (original ? [(name+" Original",input)]:[]) + choices.map{(name+" "+$0.title,images[presets.firstIndex(of:$0)!])}
            }
            if [0,1,6].contains(index) {portrait += items([.neutral,.softPortrait,.warmPortrait,.coolPortrait])}
            cinema += items(presets.filter{$0.family == .cinematic})
            atmosphere += items(presets.filter{$0.family == .atmosphere})
            special += items([.bleachGrade,.splitWarmCool])
            warm += items([.warmPortrait,.warmCinema,.goldenHour,.autumn])
            cool += items([.coolPortrait,.coolCinema,.blueHour,.moody])
            split += items([.cinematic,.tealWarm,.splitWarmCool])
            if index<2 {
                for (label,x,y) in regions {for preset in presets.filter({$0 == .neutral || $0.family == .portrait || $0.family == .cinematic}) {
                    skin.append((name+" "+label+" "+preset.title,helper.autoCrop(images[presets.firstIndex(of:preset)!],x:x,y:y)))
                }}
            }
            if let path=[3:"backlight_crops.png",4:"night_crops.png",6:"white_subject_crops.png"][index] {
                var crops:[(String,CIImage)]=[]
                for (label,x,y) in regions {for (i,preset) in presets.enumerated() {crops.append((label+" "+preset.title,helper.autoCrop(images[i],x:x,y:y)))}}
                try sheet(crops,path,cell:256,columns:16)
            }
            if [0,3,4,6].contains(index) {
                let proposal=try await helper.engine.autoAnalysis(url:file,state:EditState())
                let auto=proposal.proposal.applying(.global,to:EditState()),autoImage=try await helper.output(input,auto)
                var c=LabCase(name:"Auto coexistence / "+name)
                afterAuto.append((name+" Auto",autoImage))
                for preset in [ColorGradingPreset.softPortrait,.cinematic,.goldenHour,.bleachGrade] {
                    let state=preset.applying(to:auto),rendered=try await helper.output(input,state)
                    var restored=state;restored.colorGrading=auto.colorGrading
                    c.check(preset.id+" leaves development",restored==auto,hard:true,"Only ColorGrading is replaced")
                    c.check(preset.id+" Auto preserves grading",proposal.proposal.applying(.global,to:state).colorGrading==state.colorGrading,hard:true,"No Auto changes")
                    afterAuto.append((preset.title,rendered))
                    if preset == .softPortrait {workflow += [(name+" Original",input),("Auto corrected",autoImage),("Auto + Soft Portrait",rendered)]}
                }
                let cached=try await helper.engine.autoAnalysis(url:file,state:ColorGradingPreset.cinematic.applying(to:auto))
                c.check("Shared analysis remains cached",cached.cacheHit && cached.proposal.intent==proposal.proposal.intent,hard:true,"Preset does not trigger or alter analysis")
                lab.cases.append(c)
            }
            if index==0 {
                let ramp=SyntheticCharts.make(size:256){x,_ in SIMD3<Float>(repeating:Float(x))}
                for (i,preset) in presets.enumerated() {
                    let out=try await render(ramp,preset.settings)
                    strength += [(preset.title+" Neutral ramp",ramp),("Preset ramp",out),("Difference ×8",lab.artifacts.difference(ramp,out,gain:8)),("Neutral photo",input),("Preset photo",images[i]),("Difference ×8",lab.artifacts.difference(input,images[i],gain:8))]
                }
            }
        }
        try sheet(all,"all_presets_contact_sheet.png",cell:320,columns:16)
        try sheet(portrait,"portrait_presets.png",cell:512,columns:5)
        try sheet(cinema,"cinematic_presets.png",cell:384,columns:6)
        try sheet(atmosphere,"atmosphere_presets.png",cell:384,columns:6)
        try sheet(special,"special_presets.png",cell:384,columns:3)
        try sheet(skin,"portrait_skin_crops.png",cell:256,columns:9)
        try sheet(warm,"warm_family_comparison.png",columns:5);try sheet(cool,"cool_family_comparison.png",columns:5);try sheet(split,"split_family_comparison.png",columns:4)
        try sheet(strength,"preset_strength_overview.png",columns:6)
        try sheet(afterAuto,"after_auto_comparison.png",columns:5);try sheet(workflow,"development_workflow.png",columns:3)
        try save(photoTable,"photo_metrics.md");try save(roiTable,"region_metrics.md")
    }
    func regions(_ i:Int)->[(String,Double,Double)] {
        switch i {
        case 0:return [("skin",0.38,0.52),("eye",0.4,0.62),("hair",0.48,0.83),("highlight",0.32,0.6),("shadow",0.6,0.4)]
        case 1:return [("skin",0.47,0.54),("eye",0.46,0.68),("hair",0.65,0.52),("highlight",0.4,0.58),("shadow",0.74,0.2)]
        case 3:return [("skin",0.45,0.72),("hair",0.25,0.57),("sun",0.65,0.7),("sea reflection",0.69,0.48),("shadow",0.22,0.3)]
        case 4:return [("lamp",0.36,0.78),("stone",0.23,0.66),("sky",0.62,0.75),("wet pavement",0.55,0.17)]
        case 5:return [("shadow",0.3,0.59),("highlight",0.75,0.72)]
        case 6:return [("white dress",0.37,0.43),("white wall",0.9,0.43),("skin",0.44,0.73),("sky",0.75,0.81)]
        default:return helper.autoRegions(i)
        }
    }
}
