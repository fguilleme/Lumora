import Foundation
import CoreImage

struct ChartRegion: Codable {
    let name: String
    let x: Int, y: Int, width: Int, height: Int
    let ramp: Bool
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
struct MasterChart {
    let image: CIImage
    let regions: [ChartRegion]
    let size: Int
    static let wedge: [Float] = [0, 0.02, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.98, 1]
    static func generate(size: Int) -> Self {
        precondition(size >= 256 && size <= 4096 && size % 16 == 0)
        // Coordinates and percentages describe LINEAR sRGB, not display-encoded gray.
        let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let colors: [SIMD3<Float>] = [.init(0.8,0.04,0.04), .init(0.9,0.3,0.03), .init(0.8,0.8,0.03),
            .init(0.04,0.8,0.04), .init(0.03,0.8,0.8), .init(0.04,0.04,0.8), .init(0.8,0.03,0.8),
            .init(0.72,0.43,0.3), .init(0.38,0.18,0.1), .init(0.12,0.055,0.03)]
        var data = Data(count: size * size * 16)
        data.withUnsafeMutableBytes { raw in
            let p = raw.bindMemory(to: Float.self)
            for y in 0..<size { for x in 0..<size {
                let u = Float(x) / Float(size-1)
                let band = y * 16 / size
                var c = SIMD3<Float>(repeating: 0)
                if band < 4 {
                    let ranges: [(Float,Float)] = [(0,1),(0,0.1),(0.4,0.6),(0.9,1)]
                    c = .init(repeating: ranges[band].0 + u * (ranges[band].1-ranges[band].0))
                } else if band < 6 { c = .init(repeating: wedge[min(14,x*15/size)]) }
                else if band < 12 {
                    let base = colors[min(9,x*10/size)]
                    let saturation: Float = [0.2,0.55,1][(band-6)/2]
                    let gray = base.x*0.2126 + base.y*0.7152 + base.z*0.0722
                    c = SIMD3(repeating: gray) + (base-SIMD3(repeating: gray))*saturation
                } else {
                    let zone = min(5,x*6/size)
                    let base: Float = [0,0.015,0.3,0.8,0.98,1.6][zone]
                    let modulation: Float = [0,0.007,0.08,0.06,0.015,0.2][zone]
                    let texture = Float(sin(Double(x)/Double(size)*4096*0.19) * cos(Double(y)/Double(size)*4096*0.23))
                    let local = Float(x*6%size)/Float(size)
                    let smooth = local*local*(3-2*local)
                    let bridge = max(0,(local-0.8)/0.2)
                    let blend = bridge*bridge*(3-2*bridge)
                    let next: Float = [0,0.015,0.3,0.8,0.98,1.6][min(5,zone+1)]
                    c = .init(repeating: base+(next-base)*blend + modulation*(0.6*texture+0.4*(smooth-0.5)))
                }
                let i = (y*size+x)*4
                p[i]=c.x; p[i+1]=c.y; p[i+2]=c.z; p[i+3]=1
            } }
        }
        // CI bitmap first row is the upper row. Regions below use lower-left CI coordinates.
        var regions: [ChartRegion] = []
        func add(_ name: String, _ x: Int, _ top: Int, _ width: Int, _ height: Int, ramp: Bool = false) {
            regions.append(.init(name: name, x: x, y: size-top-height, width: width, height: height, ramp: ramp))
        }
        for (i,name) in ["ramp-full","ramp-shadows","ramp-midtones","ramp-highlights"].enumerated() {
            add(name,0,i*size/16,size,size/16,ramp:true)
        }
        for i in 0..<15 { let x = (i*size+14)/15, end = ((i+1)*size+14)/15
            add("gray-\(wedge[i])", x, size/4, min(size,end)-x, size/8)
        }
        let names = ["red","orange","yellow","green","cyan","blue","magenta","skin-light","skin-medium","skin-dark"]
        for row in 0..<3 { for i in 0..<10 {
            let x = (i*size+9)/10, end = ((i+1)*size+9)/10
            add("\(names[i])-saturation-\(row)",x,(6+row*2)*size/16,min(size,end)-x,size/8)
        } }
        for (i,name) in ["deep-black","dark-texture","mid-texture","bright-texture","near-white","specular-HDR"].enumerated() {
            let x = (i*size+5)/6, end = ((i+1)*size+5)/6
            add(name,x,3*size/4,min(size,end)-x,size/4)
        }
        return Self(image: CIImage(bitmapData: data, bytesPerRow: size*16, size: CGSize(width:size,height:size), format:.RGBAf, colorSpace:space), regions:regions,size:size)
    }
}

/// All patterns are analytic/seeded sources; no effect output is used to construct a source.
enum SyntheticCharts {
    static let linearSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    static func make(size: Int, pixel: (Double, Double) -> SIMD3<Float>) -> CIImage {
        var data = Data(count: size*size*16)
        data.withUnsafeMutableBytes { raw in
            let p = raw.bindMemory(to: Float.self)
            for y in 0..<size { for x in 0..<size {
                let c = pixel((Double(x)+0.5)/Double(size), (Double(y)+0.5)/Double(size))
                let i = (y*size+x)*4
                p[i]=c.x; p[i+1]=c.y; p[i+2]=c.z; p[i+3]=1
            } }
        }
        return CIImage(bitmapData: data, bytesPerRow:size*16,size:CGSize(width:size,height:size),format:.RGBAf,colorSpace:linearSpace)
    }
    static func gray(_ value: Double, size: Int) -> CIImage {
        CIImage(color: CIColor(red:value,green:value,blue:value,colorSpace:linearSpace)!).cropped(to:CGRect(x:0,y:0,width:size,height:size))
    }
    static func grain(size: Int) -> MasterChart {
        let levels = [0.05,0.15,0.3,0.5,0.7,0.85,0.95]
        let image = make(size:size) { x,y in
            if y < 0.7 { return SIMD3(repeating:Float(levels[min(6,Int(x*7))])) }
            let zone = min(4,Int(x*5))
            let t = x*5-Double(zone)
            switch zone {
            case 0: return SIMD3(repeating:Float(t))
            case 1: return SIMD3(repeating:Float(0.4+0.03*sin(x*4096)*sin(y*4096)))
            case 2: return SIMD3(repeating:Float(0.4+0.08*sin(x*512)*sin(y*512)))
            case 3: return SIMD3(0.5,0.27,0.16)
            default: return SIMD3(repeating:0.18)
            }
        }
        let regions = levels.enumerated().map { i,v in
            let x = Int(ceil(Double(i)*Double(size)/7)), end = Int(ceil(Double(i+1)*Double(size)/7))
            return ChartRegion(name:"uniform-\(v)",x:x+2,y:size-Int(Double(size)*0.7)+2,width:end-x-4,height:Int(Double(size)*0.7)-4,ramp:false)
        }
        return .init(image:image,regions:regions,size:size)
    }
    static func edges(size:Int) -> CIImage {
        make(size:size) { x,y in
            let row = min(4,Int(y*5))
            switch row {
            case 0: return SIMD3(repeating:x < 0.5 ? 0 : 1)
            case 1: return SIMD3(repeating:x < 0.5 ? 0.05 : 0.8)
            case 2: return x < 0.5 ? SIMD3(0.8,0.1,0.03) : SIMD3(repeating:0.3)
            default:
                let line = Int(x*Double(size)) % 32 < 2
                return SIMD3(repeating:line ? (row == 3 ? 0 : 1) : 0.4)
            }
        }
    }
    static func textures(size:Int) -> CIImage {
        make(size:size) { x,y in
            let row=min(5,Int(y*6)), ix=UInt32(x*4096), iy=UInt32(y*4096)
            if row < 3 {
                let cell: UInt32 = [2,16,64][row]
                return SIMD3(repeating:((ix/cell+iy/cell)%2 == 0) ? 0.3 : 0.6)
            }
            if row == 3 { return SIMD3(repeating:Float(0.4+0.1*sin(x*512))) }
            if row == 4 {
                var h=ix &* 374761393 &+ iy &* 668265263 &+ 137
                h=(h ^ (h >> 13)) &* 1274126177; h ^= h >> 16
                return SIMD3(repeating:0.3+Float(h & 65535)/65535*0.2)
            }
            return SIMD3(repeating:0.4)
        }
    }
    static func scene(_ name:String,size:Int) -> CIImage {
        make(size:size) { x,y in
            let noise=Float(sin(x*400)*cos(y*370))*0.007
            switch name {
            case "portrait":
                let face=pow((x-0.5)/0.24,2)+pow((y-0.45)/0.35,2)
                if face < 1 {
                    if (abs(x-0.41)<0.025 || abs(x-0.59)<0.025) && abs(y-0.4)<0.013 { return SIMD3(repeating:0.015) }
                    return SIMD3<Float>(0.58,0.31,0.19)*Float(0.5+x)+SIMD3(repeating:noise)
                }
                return SIMD3<Float>(0.07,0.09,0.12)*Float(1-y)
            case "landscape":
                let hill=0.48+0.12*sin(x*9)
                if y < hill { return SIMD3<Float>(0.28,0.52,0.83)*Float(1-y*0.4) }
                return SIMD3<Float>(0.08,0.2,0.04)*Float(1.4-y)+SIMD3(repeating:noise)
            case "night":
                let lamp=exp(-(pow(x-0.7,2)+pow(y-0.3,2))*900)
                return SIMD3<Float>(0.007,0.012,0.03)*Float(0.4+y)+SIMD3<Float>(1.8,1.2,0.5)*Float(lamp)+SIMD3(repeating:noise*0.2)
            default:
                let sphere=pow((x-0.4)/0.23,2)+pow((y-0.5)/0.23,2)
                if sphere < 1 { return SIMD3<Float>(0.7,0.12,0.04)*Float(sqrt(1-sphere))+SIMD3(repeating:noise) }
                return SIMD3(repeating:Float(0.12+0.25*y))
            }
        }
    }
}
