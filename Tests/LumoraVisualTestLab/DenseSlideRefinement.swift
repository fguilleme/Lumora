import Foundation
import CoreImage
import CryptoKit
import Testing
@testable import LumoraCore

// Opt-in two-phase diagnostic. References are raw, unreviewed RGBAf buffers,
// captured before editing production; they are not Golden Masters.
private struct DenseReference: Codable {
    let commit: String
    let hashes: [String: String]
    let presets: [String: [String: Double]]
}
private struct DenseStats: Codable {
    let meanLuminance: Double, p05: Double, p50: Double, p95: Double
    let meanChroma: Double, highlightClippedFraction: Double, newClippedFraction: Double
    let shadowRMS: Double, shadowCount: Int, nonFinite: Int
}
private struct DensePhotoResult: Codable {
    let name: String
    let stats: [String: DenseStats]
    let legacyMAEBefore: Double, legacyMAEAfter: Double
    let fullFrameMAEBefore: Double, fullFrameMAEAfter: Double
    let regions: [String: [String: DenseStats]]
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["LUMORA_DENSE_PHASE"] != nil))
func denseSlideRefinementValidation() throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let lab = try LumoraVisualTestLab(root: repo.appendingPathComponent("TestArtifacts"), full: false)
    try lab.runDenseSlideRefinement(repo: repo)
    for c in lab.cases {
        for check in c.checks where check.hard {
            #expect(check.status != "FAIL", "\(c.name): \(check.name): \(check.detail)")
        }
    }
}

extension LumoraVisualTestLab {
    private func denseBuffer(_ image: CIImage) -> [Float] { gpu.read(image, image.extent.integral) }
    private func denseMAE(_ a: [Float], _ b: [Float]) -> Double {
        precondition(a.count == b.count)
        var sum = 0.0
        for i in stride(from: 0, to: a.count, by: 4) {
            for c in 0..<3 { sum += abs(Double(a[i+c]) - Double(b[i+c])) }
        }
        return sum / Double(a.count / 4 * 3)
    }
    private func denseStats(_ p: [Float], input: [Float]) -> DenseStats {
        precondition(p.count == input.count)
        var ys: [Double] = [], chroma = 0.0, clipped = 0, newClipped = 0, invalid = 0
        var shadows: [Double] = []
        for i in stride(from: 0, to: p.count, by: 4) {
            guard (0..<4).allSatisfy({ p[i+$0].isFinite && input[i+$0].isFinite }) else { invalid += 1; continue }
            // Ignore transparent padding, including that in the legacy square sample.
            guard input[i+3] > 0.99 else { continue }
            let y = LabGPU.luma(p, i), sourceY = LabGPU.luma(input, i)
            ys.append(y)
            chroma += Double(max(p[i], p[i+1], p[i+2]) - min(p[i], p[i+1], p[i+2]))
            let clips = (0..<3).contains { p[i+$0] >= 1 - 1e-6 }
            clipped += clips ? 1 : 0
            if clips && !(0..<3).contains(where: { input[i+$0] >= 1 - 1e-6 }) { newClipped += 1 }
            if sourceY >= 0.005 && sourceY < 0.10 { shadows.append(y) }
        }
        ys.sort()
        let n = Double(max(1, ys.count)), sn = Double(max(1, shadows.count))
        let meanShadow = shadows.reduce(0, +) / sn
        func percentile(_ q: Double) -> Double { ys.isEmpty ? 0 : ys[Int(Double(ys.count-1)*q)] }
        return DenseStats(meanLuminance: ys.reduce(0,+)/n, p05: percentile(0.05), p50: percentile(0.5),
            p95: percentile(0.95), meanChroma: chroma/n, highlightClippedFraction: Double(clipped)/n,
            newClippedFraction: Double(newClipped)/n,
            shadowRMS: sqrt(shadows.reduce(0) { $0 + pow($1-meanShadow, 2) } / sn),
            shadowCount: shadows.count, nonFinite: invalid)
    }
    private func denseRamp(width: Int = 8192, _ color: (Double) -> SIMD3<Float>) -> CIImage {
        var p = [Float](repeating: 1, count: width*4)
        for x in 0..<width {
            let c = color(Double(x)/Double(width-1))
            p[x*4] = c.x; p[x*4+1] = c.y; p[x*4+2] = c.z
        }
        let data = p.withUnsafeBytes { Data($0) }
        return CIImage(bitmapData: data, bytesPerRow: width*16, size: CGSize(width: width, height: 1),
                       format: .RGBAf, colorSpace: SyntheticCharts.linearSpace)
    }
    // Source-inspected centers in normalized Core Image coordinates (bottom-left).
    private func denseRegions(_ i: Int) -> [(String, Double, Double)] {
        switch i {
        case 1: return [("skin",0.47,0.54),("skin highlight",0.34,0.60),("hair",0.65,0.52),("dark clothing",0.74,0.20)]
        case 2: return [("clouds",0.61,0.78),("blue sky",0.30,0.92),("green foliage",0.50,0.30),("mountain ridge",0.71,0.51)]
        case 3: return [("sun",0.65,0.70),("hair",0.25,0.57),("face",0.45,0.72),("shoulder",0.46,0.54),("sea reflection",0.69,0.48)]
        case 4: return [("lamp",0.36,0.78),("stone",0.23,0.66),("dark sky",0.62,0.75),("wet pavement",0.55,0.17)]
        case 5: return [("dark interior",0.30,0.59),("sunlit wall",0.75,0.72),("wood table",0.56,0.33)]
        case 6: return [("white dress",0.37,0.43),("white wall",0.90,0.43),("skin",0.44,0.73),("sky",0.75,0.81)]
        default: return []
        }
    }
    private func denseCrop(_ image: CIImage, x: Double, y: Double, side: Int) -> CIImage {
        let e = image.extent, s = min(CGFloat(side), e.width, e.height)
        let xx = min(e.maxX-s, max(e.minX, e.minX + e.width*x-s/2))
        let yy = min(e.maxY-s, max(e.minY, e.minY + e.height*y-s/2))
        return image.cropped(to: CGRect(x: floor(xx), y: floor(yy), width: s, height: s))
    }
    func runDenseSlideRefinement(repo: URL) throws {
        let env = ProcessInfo.processInfo.environment
        guard let referencePath = env["LUMORA_DENSE_REFERENCE"] else { throw LabError.configuration }
        let recording = env["LUMORA_DENSE_PHASE"] == "reference"
        let referenceURL = URL(fileURLWithPath: referencePath)
        let manifestURL = referenceURL.appendingPathComponent("manifest.json")
        let presets = CreativeFXPreset.all(for: .filmEmulation)
        let films = presets.map { $0.makeEffect().validated }
        let currentParameters = Dictionary(uniqueKeysWithValues: zip(presets.map(\.title), films.map(\.parameters)))
        let files = try FileManager.default.contentsOfDirectory(at: repo.appendingPathComponent("VisualTestAssets"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard files.count == 8 else { throw LabError.configuration }
        var hashes: [String: String] = [:]
        let enumerator = FileManager.default.enumerator(at: repo.appendingPathComponent("Lumora"), includingPropertiesForKeys: nil)!
        let production = enumerator.allObjects.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        for file in production + files {
            hashes[String(file.path.dropFirst(repo.path.count+1))] = SHA256.hash(data: try Data(contentsOf: file))
                .map { String(format: "%02x", $0) }.joined()
        }
        let reference: DenseReference
        if recording {
            guard !FileManager.default.fileExists(atPath: manifestURL.path), let commit = env["LUMORA_DENSE_BASE_COMMIT"] else { throw LabError.configuration }
            try FileManager.default.createDirectory(at: referenceURL, withIntermediateDirectories: true)
            reference = DenseReference(commit: commit, hashes: hashes, presets: currentParameters)
        } else {
            reference = try JSONDecoder().decode(DenseReference.self, from: Data(contentsOf: manifestURL))
            var c = LabCase(name: "Production scope and frozen films")
            for (path, hash) in reference.hashes where path != "Lumora/Creative/CreativeEffect.swift" {
                c.check(path, hashes[path] == hash, hard: true, "SHA256 against pre-edit source at \(reference.commit)")
            }
            for title in presets.map(\.title) where title != "Dense Slide" {
                c.check(title + " parameters", currentParameters[title] == reference.presets[title], hard: true, "Exact parameter snapshot")
            }
            cases.append(c)
        }
        func referencePixels(_ p: [Float], key: String) throws -> [Float] {
            let url = referenceURL.appendingPathComponent(key + ".rgba32f")
            if recording { try p.withUnsafeBytes { try Data($0).write(to: url, options: .atomic) }; return p }
            let data = try Data(contentsOf: url)
            guard data.count == p.count*4 else { throw LabError.configuration }
            return data.withUnsafeBytes { raw in (0..<p.count).map { raw.loadUnaligned(fromByteOffset: $0*4, as: Float.self) } }
        }
        func verify(_ p: [Float], key: String, title: String, old: [Float]) {
            guard !recording, title != "Dense Slide" else { return }
            var c = LabCase(name: "Non-regression " + key)
            let maxError = zip(p, old).map { abs(Double($0)-Double($1)) }.max() ?? 0
            c.metrics["maxRGBAError"] = maxError
            c.check("Bit-identical", p.map(\.bitPattern) == old.map(\.bitPattern), hard: true, "Raw RGBAf captured before production edit")
            cases.append(c)
        }
        var beforeDense = films[6]
        beforeDense.parameters = reference.presets["Dense Slide"]!
        let chart = normalized(FilmEmulationTestChart.generate(size: 2048).image, to: 512)
        var chartBuffers: [[Float]] = [], oldChartBuffers: [[Float]] = []
        for (i, fx) in films.enumerated() {
            let p = denseBuffer(try render(chart, [fx])), key = "chart_\(i)"
            let old = try referencePixels(p, key: key)
            verify(p, key: key, title: presets[i].title, old: old)
            chartBuffers.append(p); oldChartBuffers.append(old)
        }
        let syntheticBefore = denseMAE(oldChartBuffers[2], oldChartBuffers[6])
        let syntheticAfter = denseMAE(chartBuffers[2], chartBuffers[6])
        var photos: [DensePhotoResult] = []
        let comparisons = [2:"03_landscape_vivid_vs_dense.png",3:"04_backlight_vivid_vs_dense.png",
                          4:"05_night_vivid_vs_dense.png",6:"07_white_subject_vivid_vs_dense.png",1:"02_dark_skin_vivid_vs_dense.png"]
        // Targeted photographs and contact sheets first, then remaining corpus metrics only.
        for index in [2,3,4,6,1,0,5,7] {
            let file = files[index]
            progress("Dense Slide \(recording ? "reference" : "comparison"): \(file.lastPathComponent)")
            try autoreleasepool {
                guard var input = CIImage(contentsOf: file, options: [.applyOrientationProperty:true]) else { throw LabError.render }
                input = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX, y: -input.extent.minY))
                func fullSample(_ image: CIImage) -> CIImage {
                    let scale = 512 / max(input.extent.width, input.extent.height)
                    return image.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey:scale,kCIInputAspectRatioKey:1])
                        .cropped(to: CGRect(x:0,y:0,width:floor(input.extent.width*scale),height:floor(input.extent.height*scale)))
                }
                var samples: [[Float]] = [], oldSamples: [[Float]] = [], outputs: [CIImage] = []
                for (i, fx) in films.enumerated() {
                    let output = try render(input, [fx]), p = denseBuffer(fullSample(output)), key = "photo_\(index)_\(i)"
                    let old = try referencePixels(p, key: key)
                    verify(p, key:key, title:presets[i].title, old:old)
                    outputs.append(output); samples.append(p); oldSamples.append(old)
                }
                if recording { return }
                let oldDense = try render(input, [beforeDense])
                let oldReplayed = denseBuffer(fullSample(oldDense))
                var replay = LabCase(name: "Baseline replay \(index+1)")
                replay.check("Old Dense reproduced", oldReplayed.map(\.bitPattern) == oldSamples[6].map(\.bitPattern), hard:true,
                             "Old preset snapshot through unchanged production kernel")
                cases.append(replay)
                let nativeInput = denseBuffer(input)
                let variants = [("Original",input),("Vivid Chrome",outputs[2]),("Dense before",oldDense),("Dense after",outputs[6])]
                var stats: [String:DenseStats] = [:], regional: [String:[String:DenseStats]] = [:]
                for (name, output) in variants { stats[name] = denseStats(denseBuffer(output), input:nativeInput) }
                var sheet: [(String,CIImage)] = [("Original",fullSample(input)),("Vivid Chrome",fullSample(outputs[2])),("Dense Slide",fullSample(outputs[6]))]
                for (label,x,y) in denseRegions(index) {
                    let roiInput = denseBuffer(denseCrop(input,x:x,y:y,side:128))
                    var measured: [String:DenseStats] = [:]
                    for (name, output) in variants {
                        measured[name] = denseStats(denseBuffer(denseCrop(output,x:x,y:y,side:128)),input:roiInput)
                        if name != "Dense before" {
                            sheet.append((name + " / " + label,denseCrop(output,x:x,y:y,side:384)))
                        }
                    }
                    regional[label] = measured
                }
                if let name = comparisons[index] {
                    try artifacts.sheet(sheet,"DenseSlideRefinement/"+name,cell:384,maxColumns:3)
                }
                let legacyVivid = denseBuffer(normalized(outputs[2],to:512))
                let result = DensePhotoResult(name:file.deletingPathExtension().lastPathComponent,stats:stats,
                    legacyMAEBefore:denseMAE(legacyVivid,denseBuffer(normalized(oldDense,to:512))),
                    legacyMAEAfter:denseMAE(legacyVivid,denseBuffer(normalized(outputs[6],to:512))),
                    fullFrameMAEBefore:denseMAE(oldSamples[2],oldSamples[6]),fullFrameMAEAfter:denseMAE(samples[2],samples[6]),regions:regional)
                photos.append(result)
                var c = LabCase(name:"Photograph " + result.name)
                c.check("Finite",stats.values.allSatisfy{$0.nonFinite == 0},hard:true,"Native full-frame RGBAf")
                if comparisons[index] != nil || index == 5 {
                    let v = stats["Vivid Chrome"]!, d = stats["Dense after"]!
                    c.check("Denser median",d.p50 < v.p50,"Quality heuristic; fixed 18% gray anchor limits density changes around midgray")
                    c.check("Contained chroma",d.meanChroma < v.meanChroma,"Dense should be less vivid on average")
                    c.check("Shadow separation",d.shadowRMS > 0.65*v.shadowRMS,"Input-selected shadows 0.005 ≤ Y < 0.10")
                }
                cases.append(c)
            }
        }
        if recording {
            try JSONEncoder().encode(reference).write(to:manifestURL,options:.atomic)
            progress("Pre-edit reference complete: " + referenceURL.path)
            return
        }
        try denseCurvesAndInvariants(before:beforeDense,after:films[6],vivid:films[2],chart:chart)
        let oldDistance = photos.map(\.legacyMAEBefore).reduce(0,+)/8
        let newDistance = photos.map(\.legacyMAEAfter).reduce(0,+)/8
        var diversity = LabCase(name:"Photographic diversity")
        diversity.metrics = ["syntheticBefore":syntheticBefore,"syntheticAfter":syntheticAfter,"photoBefore":oldDistance,"photoAfter":newDistance]
        diversity.check("Clear increase",newDistance > oldDistance*1.5,"Quality diagnostic only, no fitting or second preset iteration")
        cases.append(diversity)
        try artifacts.json(photos,"DenseSlideRefinement/measurements.json")
        try artifacts.json(cases,"DenseSlideRefinement/checks.json")
        try artifacts.json(reference,"DenseSlideRefinement/reference_manifest.json")
        try artifacts.json(currentParameters["Dense Slide"]!,"DenseSlideRefinement/dense_slide_after.json")
        try denseReport(reference:reference,parameters:currentParameters["Dense Slide"]!,photos:photos,
                        syntheticBefore:syntheticBefore,syntheticAfter:syntheticAfter)
    }
    private func denseCurvesAndInvariants(before:CreativeEffect,after:CreativeEffect,vivid:CreativeEffect,chart:CIImage) throws {
        var identity = LabCase(name:"Identity bypasses")
        for key in ["amount","filmStrength"] {
            var fx = after; fx[key] = 0
            let m = gpu.compare(chart,try render(chart,[fx]))
            identity.check(key + "=0",m.maxError == 0 && m.nonFinite == 0,hard:true,"Exact zero error at exposure 0, including negative/HDR chart filtering")
        }
        cases.append(identity)
        var curveData: [String:[Double]] = [:]
        for (name, maximum) in [("SDR",1.0),("toe",0.12),("HDR",8.0)] {
            let source = denseRamp { SIMD3(repeating:Float($0*maximum)) }
            let inputs = denseBuffer(source)
            var series: [(String,[Double])] = [("Identity",(0..<inputs.count/4).map{LabGPU.luma(inputs,$0*4)})]
            for (label,fx) in [("Vivid Chrome",vivid),("Dense before",before),("Dense after",after)] {
                let p = denseBuffer(try render(source,[fx]))
                let ys = (0..<p.count/4).map { LabGPU.luma(p,$0*4) }
                series.append((label,ys)); curveData[name+" "+label] = ys
                var c = LabCase(name:"Curve \(name) \(label)")
                c.check("Finite",p.allSatisfy(\.isFinite),hard:true,"8192 evenly spaced samples, extended linear RGB")
                for channel in 0..<3 {
                    let values = (0..<p.count/4).map { Double(p[$0*4+channel]) }
                    let steps = zip(values.dropFirst(),values).map(-)
                    c.check("Monotone channel \(channel)",steps.allSatisfy{$0 > 0},hard:true,"Strictly positive sampled slope; no plateau")
                    let derivativeJumps = zip(steps.dropFirst(),steps).map { abs($0-$1) }
                    c.metrics["maxAdjacentStepChange\(channel)"] = derivativeJumps.max() ?? 0
                    c.check("Continuous sampled slope \(channel)",(derivativeJumps.max() ?? 0) < 0.0001,hard:true,"8192-sample continuity diagnostic, not an analytic proof")
                }
                cases.append(c)
            }
            let path = name == "SDR" ? "FilmEmulation/dense_slide_vs_vivid_curves.png" : "DenseSlideRefinement/curves_"+name+".png"
            try artifacts.plot(series,path,title:"Dense Slide / Vivid Chrome — " + name,xMaximum:maximum)
        }
        try artifacts.json(curveData,"DenseSlideRefinement/curves.json")
        var separation = LabCase(name:"Near-black separation and density")
        for (label,fx) in [("Vivid Chrome",vivid),("Dense before",before),("Dense after",after)] {
            var previous = -Double.infinity
            for value in [0.0,0.02,0.03,0.04,0.05,0.10,0.18,0.30,0.50,0.70,1.0,2.0,4.0,8.0] {
                let p = denseBuffer(try render(SyntheticCharts.gray(value,size:8),[fx]))
                let y = LabGPU.luma(p,0)
                separation.metrics["\(label) at \(value)"] = y
                separation.check("\(label) separates \(value)",y > previous,hard:true,"Distinct luminance values")
                previous = y
            }
        }
        separation.check("Firmer shadows than Vivid",[0.02,0.03,0.04,0.05].allSatisfy {
            separation.metrics["Dense after at \($0)"]! < separation.metrics["Vivid Chrome at \($0)"]!
        },"Quality heuristic at four near-black gray values")
        separation.check("Denser upper midtones than Vivid",[0.3,0.5,0.7].allSatisfy {
            separation.metrics["Dense after at \($0)"]! < separation.metrics["Vivid Chrome at \($0)"]!
        },"18% stays anchored by unchanged renderer")
        cases.append(separation)
        let extended = denseRamp { t in .init(Float(-0.15+8.15*t),Float(-0.03+4.03*t),Float(-0.08+16.08*t)) }
        var hdr = LabCase(name:"Extended RGB and HDR continuation")
        hdr.check("Finite negative/HDR",denseBuffer(try render(extended,[after])).allSatisfy(\.isFinite),hard:true,"Mixed channels -0.15…16, no early clamp")
        for boundary in [0.0,0.15,0.55,1.0] {
            let ramp = denseRamp(width:1025) { SIMD3(repeating:Float(boundary-0.0001+0.0002*$0)) }
            let p = denseBuffer(try render(ramp,[after]))
            let ys = (0..<p.count/4).map { LabGPU.luma(p,$0*4) }
            let steps = zip(ys.dropFirst(),ys).map(-)
            hdr.check("Continuous around \(boundary)",steps.allSatisfy{$0 >= -1e-6 && $0 < 1e-5},hard:true,"Local float precision probe across toe, shoulder, SDR/HDR boundary and zero")
        }
        cases.append(hdr)
        let gradients: [(String,(Double)->SIMD3<Float>)] = [
            ("gray",{SIMD3(repeating:Float($0))}),
            ("blue",{let t=Float($0);return .init(0.18+0.45*t,0.35+0.43*t,0.58+0.40*t)}),
            ("skin",{let t=Float($0);return .init(0.25+0.46*t,0.15+0.31*t,0.09+0.23*t)}),
            ("sunset",{let t=Float($0);return .init(0.28+0.67*t,0.08+0.57*t,0.26+0.35*t)})]
        for (name,make) in gradients {
            let source = denseRamp(width:2048,make)
            let old = denseBuffer(try render(source,[before])), new = denseBuffer(try render(source,[after]))
            var c = LabCase(name:"Banding " + name)
            c.check("Finite",new.allSatisfy(\.isFinite),hard:true,"2048-column color ramp")
            for channel in 0..<3 {
                let a = (0..<2048).map{Double(old[$0*4+channel])}, b = (0..<2048).map{Double(new[$0*4+channel])}
                let steps = zip(b.dropFirst(),b).map(-)
                let oldLevels = Set(a.map{Int(($0*65535).rounded())}).count
                let newLevels = Set(b.map{Int(($0*65535).rounded())}).count
                c.metrics["beforeLevels\(channel)"] = Double(oldLevels); c.metrics["afterLevels\(channel)"] = Double(newLevels)
                c.metrics["maxStep\(channel)"] = steps.map(abs).max() ?? 0
                c.check("No inversion \(channel)",steps.allSatisfy{$0 >= 0},hard:true,"Float RGB ramp")
                c.check("No new quantized plateau \(channel)",newLevels >= oldLevels,hard:true,"At least as many distinct 16-bit linear values as baseline")
                c.check("No abrupt jump \(channel)",(steps.map(abs).max() ?? 0) < 0.015,hard:true,"Existing Film Emulation banding bound")
            }
            cases.append(c)
        }
    }
    private func denseReport(reference:DenseReference,parameters:[String:Double],photos:[DensePhotoResult],syntheticBefore:Double,syntheticAfter:Double) throws {
        func n(_ v:Double)->String { String(format:"%.6f",v) }
        let sorted = photos.sorted{$0.name < $1.name}
        let counts = ["PASS","WARN","FAIL"].map { status in "\(cases.filter{$0.status == status}.count) \(status)" }.joined(separator:", ")
        var md = """
        # Dense Slide — une seule itération

        Référence : `\(reference.commit)`. Production modifiée uniquement dans le snapshot Dense Slide de `CreativeEffect.swift`. Renderer, coefficients internes des sept styles, domaine logarithmique, HDR, coupling, six autres presets, UI et pile inchangés. Aucun commit ni Golden Master. Une seule variante évaluée, sans recherche de distance maximale.

        ## Paramètres et justification

        | Paramètre | Avant | Après | Intention |
        |---|---:|---:|---|
        """
        let reasons = ["shadowDensity":"Raffermir le pied de courbe. Avec l'ancrage à 0.18, diminuer ce coefficient réduit les faibles valeurs ; le sens effectif est expliqué par l'équation existante, sans corriger le renderer.",
                       "contrast":"Densifier les tons moyens au-dessus du gris ancré ; le film conserve une pente interne supérieure à 1.",
                       "highlightRollOff":"Renforcer progressivement le shoulder, contenir blancs et couleurs lumineuses sans plafond SDR.",
                       "saturation":"Contenir légèrement la richesse chromatique ; réponse par zone et canaux conservée."]
        for key in parameters.keys.sorted() {
            md += "\n| \(key) | \(reference.presets["Dense Slide"]![key]!) | \(parameters[key]!) | \(reasons[key] ?? "Inchangé") |"
        }
        md += """


        L'exposition reste à zéro. Les paramètres effectifs deviennent toe `0.1805` (avant `0.2945`), pente médiane `1.30115` (avant `1.323`), shoulder `0.58235` (avant `0.437`) ; quantité 85 %, force 95 %, couleur 82 %. Les centres, largeurs, offsets RGB et coupling restent identiques. La pente près du noir augmente avant normalisation, donnant une sortie normalisée plus dense sous le gris ancré. La saturation globale interne passe de 1 à 0.943, ajoutée à la réponse zonale existante.

        **Limite structurelle :** le gris neutre à 0.18 est ancré. Aucune modification de ces contrôles à exposition nulle ne peut assombrir ce point. L'objectif de midtones plus denses est donc évalué sur les tons moyens supérieurs et les régions photographiques, et ne signifie pas une baisse uniforme de tout l'intervalle.

        [Courbes Identity / Vivid / Dense avant / Dense après](FilmEmulation/dense_slide_vs_vivid_curves.png) · [Toe](DenseSlideRefinement/curves_toe.png) · [HDR](DenseSlideRefinement/curves_HDR.png). Données intégrales dans [curves.json](DenseSlideRefinement/curves.json).

        ## Méthode et distances

        Distances : MAE RGB linéaire étendu, mêmes sources et même pipeline GPU. La méthode historique `normalized(...,512)` met la largeur à 512 puis prélève un carré : elle recadre les portraits et inclut du transparent sur les paysages horizontaux. Elle est conservée UNIQUEMENT pour comparer honnêtement au précédent 0.002318. Une seconde mesure respecte le cadre entier (grand côté 512, aucun padding). Les statistiques photographiques ci-dessous utilisent tous les pixels natifs opaques, avant conversion PNG ; aucun écrêtage anticipé.

        | Corpus | Avant | Après |
        |---|---:|---:|
        | Synthétique historique, mire complète 512 | \(n(syntheticBefore)) | \(n(syntheticAfter)) |
        | 8 photos, méthode historique | \(n(photos.map(\.legacyMAEBefore).reduce(0,+)/8)) | \(n(photos.map(\.legacyMAEAfter).reduce(0,+)/8)) |
        | 8 photos, cadres entiers | \(n(photos.map(\.fullFrameMAEBefore).reduce(0,+)/8)) | \(n(photos.map(\.fullFrameMAEAfter).reduce(0,+)/8)) |

        | Photo | MAE historique avant | après | MAE cadre entier avant | après |
        |---|---:|---:|---:|---:|
        """
        for p in sorted { md += "\n| \(p.name) | \(n(p.legacyMAEBefore)) | \(n(p.legacyMAEAfter)) | \(n(p.fullFrameMAEBefore)) | \(n(p.fullFrameMAEAfter)) |" }
        let variants = ["Original","Vivid Chrome","Dense before","Dense after"]
        md += "\n\n## Statistiques natives\n\nP05/P50/P95 : luminance linéaire. Chroma : max(R,G,B)−min(R,G,B). Clipping : fraction avec au moins un canal ≥ 1−10⁻⁶, pas un diagnostic esthétique. Nouveau clipping : ces pixels dont aucun canal de l'entrée n'était déjà écrêté. Shadow RMS : écart type de Y en sortie sur la sélection FIXE des pixels d'entrée 0.005 ≤ Y < 0.10 ; il mesure la dispersion tonale de cette zone, pas uniquement la texture locale.\n\n"
        func table(_ stats:[String:DenseStats]) -> String {
            var t = "| Variante | Y moyen | P05 | P50 | P95 | Chroma | Clip fraction | Nouveau clip | Shadow RMS | N shadows |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
            for label in variants {
                let s = stats[label]!
                t += "| \(label) | \(n(s.meanLuminance)) | \(n(s.p05)) | \(n(s.p50)) | \(n(s.p95)) | \(n(s.meanChroma)) | \(n(s.highlightClippedFraction)) | \(n(s.newClippedFraction)) | \(n(s.shadowRMS)) | \(s.shadowCount) |\n"
            }
            return t
        }
        for p in sorted { md += "### \(p.name)\n\n" + table(p.stats) + "\n" }
        md += "## Clipping agrégé\n\nMoyenne non pondérée des fractions des huit photos ; ne pas confondre avec une fraction calculée sur tous les pixels concaténés.\n\n| Variante | Clip fraction moyen | Nouveau clip moyen |\n|---|---:|---:|\n"
        for label in variants {
            md += "| \(label) | \(n(photos.map{$0.stats[label]!.highlightClippedFraction}.reduce(0,+)/8)) | \(n(photos.map{$0.stats[label]!.newClippedFraction}.reduce(0,+)/8)) |\n"
        }
        md += "\n## Régions ciblées : peau sombre, blanc, contre-jour, nuit, paysage et intérieur\n\nCentres revérifiés sur les originaux, coordonnées Core Image en bas à gauche. Crops visuels 384×384 à taille native ; mesures locales 128×128 pour isoler les matières. Une ligne de vues complètes précède les crops, dans l'ordre Original / Vivid Chrome / Dense Slide. Un N shadows nul signifie qu'aucun pixel de cette ROI ne répond à la sélection des ombres ; le RMS à zéro n'est alors pas une perte de détail.\n\n"
        for p in sorted where !p.regions.isEmpty {
            md += "### \(p.name)\n\n"
            for name in p.regions.keys.sorted() { md += "**\(name)**\n\n" + table(p.regions[name]!) + "\n" }
        }
        md += "## Validation et non-régression\n\n**\(counts)** (cas, pas assertions). Six films figés comparés bit à bit sur RGBAf : mire et huit cadres photographiques, références capturées avant modification ; paramètres et SHA256 des sources de production/photographies également contrôlés. Les buffers sont des références techniques temporaires, pas des Golden Masters approuvés.\n\n| Cas | État | Détail non PASS |\n|---|---|---|\n"
        for c in cases {
            md += "| \(c.name) | \(c.status) | \(c.checks.filter{$0.status != "PASS"}.map{$0.name+": "+$0.detail}.joined(separator:" ; ")) |\n"
        }
        if let c = cases.first(where:{$0.name == "Near-black separation and density"}) {
            md += "\n### Réponse aux points de gris\n\n| Entrée | Vivid Chrome | Dense avant | Dense après |\n|---|---:|---:|---:|\n"
            for v in [0.0,0.02,0.03,0.04,0.05,0.10,0.18,0.30,0.50,0.70,1.0,2.0,4.0,8.0] {
                md += "| \(v) | \(n(c.metrics["Vivid Chrome at \(v)"]!)) | \(n(c.metrics["Dense before at \(v)"]!)) | \(n(c.metrics["Dense after at \(v)"]!)) |\n"
            }
        }
        md += "\n## Fichiers pour inspection manuelle\n\n"
        for name in ["03_landscape","04_backlight","05_night","07_white_subject","02_dark_skin"] {
            md += "- [\(name)](DenseSlideRefinement/\(name)_vivid_vs_dense.png)\n"
        }
        md += "\n[Mesures JSON](DenseSlideRefinement/measurements.json) · [Contrôles et métriques](DenseSlideRefinement/checks.json) · [Manifeste référence](DenseSlideRefinement/reference_manifest.json).\n\nArrêt après cette variante. Validation visuelle manuelle attendue ; aucune seconde modification ni commit.\n"
        try md.write(to:artifacts.url("DenseSlideRefinementReport.md"),atomically:true,encoding:.utf8)
    }
}
