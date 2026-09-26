import Foundation
import ImageIO
import UniformTypeIdentifiers

@main struct DebugHaloCorpusRunner {
    struct Row: Codable {
        let image: String
        let variant: String
        let sourceWidth: Int
        let sourceHeight: Int
        let metrics: DebugHaloDiagnostics.Metrics
    }
    static func save(_ image:CGImage,_ url:URL) {
        if let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) {
            CGImageDestinationAddImage(destination,image,nil)
            CGImageDestinationFinalize(destination)
        }
    }
    static func main() async throws {
        let output=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        let maximum=Int(CommandLine.arguments[2]) ?? 512
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        var rows:[Row]=[]
        for filename in CommandLine.arguments.dropFirst(3) {
            let input=URL(fileURLWithPath:filename)
            guard let source=CGImageSourceCreateWithURL(input as CFURL,nil),
                  let original=CGImageSourceCreateImageAtIndex(source,0,nil) else {continue}
            let raw=try DebugLabBitmap.linear(original,maximum:maximum)
            let preview=try DebugLabBitmap.display(raw.pixels,width:raw.width,height:raw.height)
            let scene=try await DebugSceneAnalyzer.shared.analyze(preview)
            let name=input.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of:"VisualTestAssets_",with:"")
            let directory=output.appendingPathComponent(name,isDirectory:true)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            for variant in DebugToneVariant.allCases {
                let safe=variant.rawValue.replacingOccurrences(of:" / ",with:"_")
                    .replacingOccurrences(of:" · ",with:"_")
                    .replacingOccurrences(of:" ",with:"_")
                do {
                    let result=try await DebugAdaptiveToneLab.shared.render(preview,variant:variant,amount:100,scene:scene)
                    save(result.image,directory.appendingPathComponent(safe+".png"))
                    let diagnostic=try DebugHaloDiagnostics.evaluate(original:preview,processed:result.image,
                                                                      scene:scene,makeOverlays:false)
                    rows.append(Row(image:name,variant:variant.rawValue,sourceWidth:original.width,
                                    sourceHeight:original.height,metrics:diagnostic.metrics))
                    let m=diagnostic.metrics
                    print(name,variant.rawValue,
                          String(format:"meanY %.4f P95 %.4f halo %.3f asym %.4f",
                                 m.meanAbsoluteY,m.p95AbsoluteY,
                                 m.brightHaloFraction+m.darkHaloFraction,m.leftRightExcessAsymmetry))
                    fflush(stdout)
                } catch {print("FAIL",name,variant.rawValue,error);fflush(stdout)}
            }
        }
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try encoder.encode(rows).write(to:output.appendingPathComponent("metrics.json"))
        print("ROWS",rows.count)
    }
}
