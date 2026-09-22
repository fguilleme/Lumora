import Foundation
import Testing
@testable import LumoraCore

@Test func gradingPresetsStateAndHistory() throws {
    #expect(ColorGradingPreset.allCases.count==16)
    #expect(Set(ColorGradingPreset.allCases.map(\.id)).count==16)
    for preset in ColorGradingPreset.allCases {
        let g=preset.settings
        #expect(g==g.validated)
        #expect(ColorGradingPreset.matching(g)==preset)
        var custom=g;custom.balance += 0.1
        #expect(ColorGradingPreset.matching(custom)==nil)
        custom.balance=g.balance
        #expect(ColorGradingPreset.matching(custom)==preset)
        var original=EditState();original.exposure=1.2;original.temperature=13
        original.colorGrading.shadows=GradingWheel(hue:320,saturation:99,luminance:80)
        original.colorGrading.balance = -100;original.colorGrading.blending=100
        let applied=preset.applying(to:original)
        var stripped=applied;stripped.colorGrading=original.colorGrading
        #expect(stripped==original)
        #expect(applied.colorGrading==g)
        var history=HistoryManager();history.begin("Grading",state:original);history.commit(applied)
        #expect(history.undo()==original);#expect(history.redo()==applied)
        let decoded=try JSONDecoder().decode(EditState.self,from:JSONEncoder().encode(applied))
        #expect(decoded==applied)
        var duplicate=decoded;duplicate.colorGrading.balance += 1
        #expect(applied.colorGrading==g && duplicate != applied)
        for previous in ColorGradingPreset.allCases {
            #expect(preset.applying(to:previous.applying(to:original))==applied)
        }
        #expect(ColorGradingPreset.neutral.applying(to:applied).colorGrading==ColorGrading())
    }
}
