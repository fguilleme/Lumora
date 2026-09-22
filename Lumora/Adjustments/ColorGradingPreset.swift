import Foundation

/// Starting values only. Documents persist complete ColorGrading settings, never an ID.
enum ColorGradingPreset: String, CaseIterable, Identifiable, Sendable {
    case neutral, softPortrait, warmPortrait, coolPortrait
    case cinematic, tealWarm, coolCinema, warmCinema, mutedCinema
    case goldenHour, blueHour, moody, pastel, autumn, bleachGrade, splitWarmCool
    var id: String { rawValue }
    enum Family: String, CaseIterable { case portrait, cinematic, atmosphere, special
        var title: String { switch self {
        case .portrait: String(localized:"Portrait")
        case .cinematic: String(localized:"Cinéma")
        case .atmosphere: String(localized:"Atmosphère")
        case .special: String(localized:"Spécial")
        } }
    }
    var family: Family? { switch self {
    case .neutral: nil
    case .softPortrait,.warmPortrait,.coolPortrait: .portrait
    case .cinematic,.tealWarm,.coolCinema,.warmCinema,.mutedCinema: .cinematic
    case .goldenHour,.blueHour,.moody,.pastel,.autumn: .atmosphere
    case .bleachGrade,.splitWarmCool: .special
    } }
    var title: String { switch self {
    case .neutral: String(localized:"Neutral")
    case .softPortrait: String(localized:"Soft Portrait")
    case .warmPortrait: String(localized:"Warm Portrait")
    case .coolPortrait: String(localized:"Cool Portrait")
    case .cinematic: String(localized:"Cinematic")
    case .tealWarm: String(localized:"Teal & Warm")
    case .coolCinema: String(localized:"Cool Cinema")
    case .warmCinema: String(localized:"Warm Cinema")
    case .mutedCinema: String(localized:"Muted Cinema")
    case .goldenHour: String(localized:"Golden Hour")
    case .blueHour: String(localized:"Blue Hour")
    case .moody: String(localized:"Moody")
    case .pastel: String(localized:"Pastel")
    case .autumn: String(localized:"Autumn")
    case .bleachGrade: String(localized:"Bleach Grade")
    case .splitWarmCool: String(localized:"Split Warm/Cool")
    } }
    var settings: ColorGrading {
        func make(_ s: (Double,Double),_ m: (Double,Double),_ h: (Double,Double),_ balance: Double,_ blending: Double) -> ColorGrading {
            var g=ColorGrading()
            g.shadows=GradingWheel(hue:s.0,saturation:s.1)
            g.midtones=GradingWheel(hue:m.0,saturation:m.1)
            g.highlights=GradingWheel(hue:h.0,saturation:h.1)
            g.balance=balance;g.blending=blending
            return g
        }
        switch self {
        case .neutral: return ColorGrading()
        case .softPortrait: return make((220,3),(30,3),(42,4),8,60)
        case .warmPortrait: return make((215,2),(28,7),(38,8),12,65)
        case .coolPortrait: return make((225,7),(28,3),(210,3),-5,45)
        case .cinematic: return make((205,8),(32,2),(40,8),0,45)
        case .tealWarm: return make((185,14),(30,2),(32,12),-8,35)
        case .coolCinema: return make((220,11),(215,4),(45,2),-12,50)
        case .warmCinema: return make((230,6),(28,5),(38,13),16,45)
        case .mutedCinema: return make((195,5),(35,1),(48,4),-6,70)
        case .goldenHour: return make((218,4),(38,6),(46,16),20,55)
        case .blueHour: return make((230,14),(215,8),(205,3),-10,55)
        case .moody: return make((172,10),(195,2),(38,4),-20,35)
        case .pastel: return make((265,3),(345,2),(48,3),10,75)
        case .autumn: return make((28,7),(22,8),(48,10),-5,50)
        case .bleachGrade: return make((215,4),(0,0),(45,1),-10,30)
        case .splitWarmCool: return make((225,16),(0,0),(48,16),0,25)
        }
    }
    static func matching(_ settings: ColorGrading) -> Self? { allCases.first { $0.settings == settings } }
    func applying(to source: EditState) -> EditState { var result=source;result.colorGrading=settings;return result }
}
