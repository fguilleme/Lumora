import Foundation

/// Smooth tonal masks in perceptual luminance. Endpoints remain stable except for black/white controls.
enum TonalResponse {
    static func smoothstep(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }
    static func map(_ x: Double, state: EditState) -> Double {
        let shadow = 1 - smoothstep(0.05, 0.65, x)
        let highlight = smoothstep(0.35, 0.95, x)
        let black = 1 - smoothstep(0, 0.3, x)
        let white = smoothstep(0.7, 1, x)
        let tonal = x + state.shadows / 100 * shadow * x * (1 - x) * 1.5
            + state.highlights / 100 * highlight * x * (1 - x) * 1.5
            + state.blacks / 100 * black * 0.12
            + state.whites / 100 * white * 0.18
        // Smooth S-curve: contrast does not simply add brightness.
        let contrast = state.contrast / 100 * (tonal - 0.5) * tonal * (1 - tonal) * 2.4
        return min(1, max(0, tonal + contrast))
    }

    /// LUT operates in perceptual sRGB; exposure/white balance happen upstream in linear light.
    static func color(_ r: Double, _ g: Double, _ b: Double, state: EditState, curves: CurveLookup? = nil) -> (Double, Double, Double) {
        let luminance = r * 0.2126 + g * 0.7152 + b * 0.0722
        let mapped = map(luminance, state: state)
        let delta = mapped - luminance
        var red = min(1, max(0, r + delta)), green = min(1, max(0, g + delta)), blue = min(1, max(0, b + delta))
        if let curves { (red, green, blue) = curves.apply(red, green, blue) }
        else if !state.curves.isIdentity {
            red = state.curves.red.evaluate(state.curves.rgb.evaluate(red))
            green = state.curves.green.evaluate(state.curves.rgb.evaluate(green))
            blue = state.curves.blue.evaluate(state.curves.rgb.evaluate(blue))
        }
        let colorLuma = red * 0.2126 + green * 0.7152 + blue * 0.0722
        let maximum = max(red, green, blue), minimum = min(red, green, blue)
        let saturation = maximum > 0 ? (maximum - minimum) / maximum : 0
        // Soft orange-sector protection, independent of any face/skin inference.
        let hue: Double
        let chroma = maximum - minimum
        if chroma < 0.00001 { hue = 0 }
        else if maximum == red { hue = ((green - blue) / chroma + 6).truncatingRemainder(dividingBy: 6) / 6 }
        else if maximum == green { hue = ((blue - red) / chroma + 2) / 6 }
        else { hue = ((red - green) / chroma + 4) / 6 }
        let distance = min(abs(hue - 0.075), 1 - abs(hue - 0.075))
        let skinProtection = 1 - 0.7 * exp(-pow(distance / 0.075, 2))
        let vibrance = state.vibrance / 100 * (1 - saturation) * skinProtection
        let factor = max(0, 1 + state.saturation / 100) * max(0, 1 + vibrance)
        let output = (min(1, max(0, colorLuma + (red - colorLuma) * factor)),
                min(1, max(0, colorLuma + (green - colorLuma) * factor)),
                min(1, max(0, colorLuma + (blue - colorLuma) * factor)))
        return state.colorMixer.isIdentity ? output : HSLMixer.apply(output.0, output.1, output.2, mixer: state.colorMixer)
    }
}
