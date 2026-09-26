import Foundation
import CoreImage
import Testing
@testable import LumoraCore

/// Descriptive tables requested after the first frozen validation run.
/// This never changes a renderer, preset, threshold or original result.
@Test func silverToningDescriptiveTables() throws {
    let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let lab=try LumoraVisualTestLab(root:repo.appendingPathComponent("Validation/TestArtifacts"),full:true)
    try lab.toningDescriptiveTables(repo:repo)
}
private struct ToningStatistics: Codable {
    var meanY=0.0,p05=0.0,p50=0.0,p95=0.0,meanChroma=0.0
    var shadowChroma=0.0,midtoneChroma=0.0,highlightChroma=0.0
    var maxChroma=0.0,hueAtMaxChroma=0.0,yAtMaxChroma=0.0
    var meanAbsDeltaY=0.0,maxAbsDeltaY=0.0,clippedFraction=0.0
    var nonFinitePixels=0
    init(_ pixels:[Float],reference:[Float]) {
        var ys:[Double]=[],sumC=0.0,zones=[Double](repeating:0,count:3),counts=[Int](repeating:0,count:3),clipped=0
        for i in stride(from:0,to:pixels.count,by:4) {
            guard (0..<4).allSatisfy({pixels[i+$0].isFinite}) else {nonFinitePixels+=1;continue}
            let y=LabGPU.luma(pixels,i),original=LabGPU.luma(reference,i)
            let r=Double(pixels[i]),g=Double(pixels[i+1]),b=Double(pixels[i+2])
            let u=2*r-g-b,v=sqrt(3)*(g-b),chroma=y>1e-6 ? hypot(u,v)/y:0
            ys.append(y);sumC+=chroma
            let zone=original<0.1 ? 0:original<0.7 ? 1:2
            zones[zone]+=chroma;counts[zone]+=1
            if chroma>maxChroma {maxChroma=chroma;hueAtMaxChroma=atan2(v,u)*180/Double.pi;yAtMaxChroma=original}
            let delta=abs(y-original);meanAbsDeltaY+=delta;maxAbsDeltaY=max(maxAbsDeltaY,delta)
            if r>=1 || g>=1 || b>=1 || r<0 || g<0 || b<0 {clipped+=1}
        }
        let count=Double(max(1,ys.count));meanY=ys.reduce(0,+)/count;meanChroma=sumC/count;meanAbsDeltaY/=count
        clippedFraction=Double(clipped)/count;ys.sort()
        if !ys.isEmpty {p05=ys[Int(Double(ys.count-1)*0.05)];p50=ys[(ys.count-1)/2];p95=ys[Int(Double(ys.count-1)*0.95)]}
        shadowChroma=zones[0]/Double(max(1,counts[0]));midtoneChroma=zones[1]/Double(max(1,counts[1]));highlightChroma=zones[2]/Double(max(1,counts[2]))
    }
}
extension LumoraVisualTestLab {
    func toningDescriptiveTables(repo:URL) throws {
        let presets=CreativeFXPreset.all(for:.silverToning)
        var md="\n## Tableaux descriptifs complémentaires (sections 117–118)\n\nMesures ajoutées à la demande reçue pendant le premier banc ; aucun renderer, paramètre ni seuil modifié. Y et RGB sont lus en RGBAf extended linear sRGB avant export. Chroma relative = hypot(2R−G−B, √3(G−B))/Y pour Y>10⁻⁶, sinon 0. Teinte = atan2 de cet opposant en degrés. Ce ne sont pas des unités CIELAB ni des ΔE. Les zones sont définies sur l'entrée : shadows Y<0.1, midtones 0.1≤Y<0.7, highlights Y≥0.7. Une zone absente affiche une moyenne 0. La fraction clipped signale les pixels avec un canal RGB hors [0,1) susceptibles d'écrêtage à la sortie SDR ; le moteur n'écrête pas ces valeurs.\n\n"
        let ramp=silverRamp{SIMD3(repeating:Float($0))},input=silverPixels(ramp)
        var measured:[String:ToningStatistics]=[:]
        func f(_ x:Double)->String {String(format:"%.6g",x)}
        func distance(_ a:[Float],_ b:[Float])->Double {
            var sum=0.0
            for i in stride(from:0,to:a.count,by:4) {for channel in 0..<3 {sum+=abs(Double(a[i+channel]-b[i+channel]))}}
            return sum/Double(a.count/4*3)
        }
        for (group,configs) in [("Toners, Strength=100",SilverToner.allCases.map{($0.title,toningFX(["toner":Double($0.rawValue),"strength":100]))}),
                                ("Presets, paramètres inchangés",presets.map{($0.title,$0.makeEffect())})] {
            let outputs=try configs.map{silverPixels(try toningOutput(ramp,$0.1))}
            md += "### \(group)\n\nZone = luminance où la chroma relative atteint son maximum, sur rampe 0→1. Les courbes complètes donnent l'étendue réelle de la réponse ; Neutral n'a pas de hue défini. Distance = MAE RGB linéaire.\n\n| Toner / preset | Zone du maximum (Y) | Hue au maximum | Chroma max | meanAbsΔY | maxAbsΔY | Distance Neutral | Plus proche | Distance |\n|---|---|---:|---:|---:|---:|---:|---|---:|\n"
            for i in configs.indices {
                let stat=ToningStatistics(outputs[i],reference:input),name=configs[i].0
                measured[group+" / "+name]=stat
                let others=configs.indices.filter{$0 != i}.map{($0,distance(outputs[i],outputs[$0]))}
                let closest=others.min{$0.1<$1.1}!
                let zone=stat.yAtMaxChroma<0.1 ? "shadow":stat.yAtMaxChroma<0.3 ? "lower midtone":stat.yAtMaxChroma<0.7 ? "upper midtone":"highlight"
                md += "| \(name) | \(zone) (\(f(stat.yAtMaxChroma))) | \(stat.maxChroma<1e-6 ? "undefined":f(stat.hueAtMaxChroma)) | \(f(stat.maxChroma)) | \(f(stat.meanAbsDeltaY)) | \(f(stat.maxAbsDeltaY)) | \(f(distance(outputs[i],input))) | \(configs[closest.0].0) | \(f(closest.1)) |\n"
                #expect(stat.nonFinitePixels==0,"Descriptive ramp must remain finite")
            }
            md += "\n"
        }
        let files=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("Validation/VisualTestAssets"),includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        for file in files {
            progress("Silver Toning descriptive statistics: "+file.lastPathComponent)
            try autoreleasepool {
                guard let image=CIImage(contentsOf:file,options:[.applyOrientationProperty:true]) else {throw LabError.render}
                let neutral=try render(image,[silverPreset("Neutral Silver")]),base=silverFullFrame(neutral,side:512),reference=silverPixels(base)
                md += "### \(file.deletingPathExtension().lastPathComponent)\n\nCadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.\n\n| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
                for preset in presets {
                    let output=silverFullFrame(try toningOutput(neutral,preset.makeEffect()),side:512)
                    let stat=ToningStatistics(silverPixels(output),reference:reference)
                    measured[file.lastPathComponent+" / "+preset.title]=stat
                    md += "| \(preset.title) | "+[stat.meanY,stat.p05,stat.p50,stat.p95,stat.meanChroma,stat.shadowChroma,stat.midtoneChroma,stat.highlightChroma,stat.clippedFraction].map(f).joined(separator:" | ")+" | \(stat.nonFinitePixels) |\n"
                    #expect(stat.nonFinitePixels==0,"Photographic descriptive statistics finite")
                }
                md += "\n"
            }
        }
        try artifacts.json(measured,"SilverToning/descriptive_statistics.json")
        let cases=try JSONDecoder().decode([LabCase].self,from:Data(contentsOf:artifacts.url("SilverToning/checks.json")))
        md += "## Statut de chaque contrôle : hard invariant / quality heuristic\n\nLes PASS techniques ne valident pas l'esthétique. Un WARN est conservé pour inspection ; un FAIL interdit le commit.\n\n| Cas / contrôle | Type | État | Critère |\n|---|---|---|---|\n"
        for c in cases {for check in c.checks {
            md += "| \(c.name) / \(check.name) | \(check.hard ? "hard invariant":"quality heuristic") | \(check.status) | \(check.detail.replacingOccurrences(of:"|",with:"/")) |\n"
        }}
        let path=try artifacts.url("SilverToningValidationReport.md")
        var report=try String(contentsOf:path,encoding:.utf8)
        report=report.replacingOccurrences(of:"Aucun Golden Master ni commit automatique demandé pour cette étape.",with:"Aucun Golden Master. Commit autorisé uniquement si les builds passent et aucun FAIL/hard invariant n'échoue (fin de spécification reçue pendant le banc).")
        report += md
        try report.write(to:path,atomically:true,encoding:.utf8)
    }
}
