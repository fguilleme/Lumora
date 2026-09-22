import Foundation
@testable import LumoraCore

extension LumoraVisualTestLab {
    func toningReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("ST_")}
        try artifacts.json(selected,"SilverToning/checks.json")
        try artifacts.json(CreativeFXPreset.all(for:.silverToning).map{$0.makeEffect()},"SilverToning/presets.json")
        let counts=["PASS","WARN","FAIL"].map{s in "\(selected.filter{$0.status==s}.count) \(s)"}.joined(separator:", ")
        var md="""
        # Silver Toning — validation

        **\(counts)**. Mesures techniques et inspection photographique sont distinctes. Aucun réglage corrigé automatiquement après mesure ; aucun Golden Master créé. GPU : \(gpu.deviceName). OS : \(ProcessInfo.processInfo.operatingSystemVersionString).

        ## Architecture et modèle original Lumora

        Effet indépendant `SilverToningRenderer`, `SilverToningSettings` Codable, même pile, masques, matcher Preset/Custom, historique et RenderEngine. Silver B&W et les moteurs existants restent inchangés. Un kernel GPU pointwise, sans bruit, texture, blur, glow, sharpen, lookup de voisinage ni readback CPU. Amount est le mélange final calculé dans le même kernel.

        RGB linéaire extended sRGB → Y → densité continue → contributions argent/papier → déplacement chromatique dans le plan de luminance constante → Amount. `Y=0.2126R+0.7152G+0.0722B`, `p=max(Y,0)`, `s=0.18×2^(2×Balance/100)`, `D=log2(1+s/(p+10⁻⁶))`. Le kernel utilise directement `t=2⁻ᴰ=(p+10⁻⁶)/(p+10⁻⁶+s)`. Cela évite le logarithme et reste stable au noir. Balance positif augmente s : la contribution argent/ombre s'étend vers les luminances claires. Aucun Density Bias supplémentaire n'est nécessaire.

        Pour une teinte h, `v=(cos h,cos(h−120°),cos(h+120°))` puis `q(h)=v−Y(v)·(1,1,1)`. Cette projection analytique satisfait `Y(q)=0`. Il s'agit d'un cercle RGB continu, pas d'un espace perceptuellement uniforme ni d'une simulation spectrale du papier.

        Argent : `S=q(hs)·cs·(1−t)^e·ShadowStrength + q(hh)·ch·t²·HighlightStrength`. Paper : `P=q(45° si chaud,215° si froid)·0.12·|PaperTone|·(p/(p+0.35))⁴`. Les contrôles d'intensité sont normalisés à [0,1]. Paper Tone est signé [-1,1], 0 neutre ; sa teinte est sans effet à zéro et la réponse chromatique reste continue au changement de signe.

        `RGBout=RGBin + Amount·Strength·[p²/(p+0.02)]·(SilverTone·S+P)`. Ainsi la chroma d'origine est conservée puis modifiée, sans conversion N&B implicite. Un canal négatif peut subsister pour une couleur saturée : aucune compression de gamut ni clamp n'est imposé avant la conversion de sortie. L'alpha prémultiplié est conservé. À Y≤0 le déplacement est nul ; l'amplitude et sa dérivée tendent vers zéro à droite, donc extension C1 autour de zéro sans log négatif ni explosion. L'amplitude relative reste bornée en HDR ; t et la contribution papier convergent progressivement vers leurs limites highlight/papier.

        Amount=0, Strength=0 et Toner=Neutral retournent strictement l'image source, y compris Paper Tone nonzero. Strength gouverne toutes les contributions. Silver Tone=0 isole le papier ; Paper Tone=0 isole l'argent. Neutral est volontairement une référence totalement neutre ; pour tester un papier seul choisir un autre toner avec Silver Tone=0.

        ## Toners et presets

        Modèles artistiques originaux, sans constante ni formulation d'une marque ou de chimie physique reproduite. Valeurs définies avant validation :

        | Toner | h ombre / lumière | chroma ombre / lumière | exposant densité |
        |---|---|---|---:|
        """
        for t in SilverToner.allCases {
            let v=t.colors
            md += "\n| \(t.title) | \(v.x) / \(v.y) | \(v.z) / \(v.w) | \(t.densityExponent) |"
        }
        md += """


        Selenium : violet froid concentré dans les densités, faible coloration des blancs. Sepia : brun chaud plus étendu ; Copper : plus rouge et plus concentré. Gold : bleu avec une inflexion violette claire ; Cool Silver : cyan/bleu. Platinum : faible chroma étendue. Warm Silver : gris chaud. Split Silver expose deux teintes continues avec intensités séparées et la même transition de densité, sans seuil à Y=0.5. Le preset Split Warm/Cool utilise des ombres froides et lumières chaudes.

        Presets :
        """
        md += CreativeFXPreset.all(for:.silverToning).map(\.title).joined(separator:", ")+".\n"
        md += """

        ## Mesures et seuils

        Les rampes de référence contiennent 4096 échantillons RGBAf. Les courbes utilisent R/Y−1, G/Y−1, B/Y−1 ; la chroma est la norme de l'opposant (2R−G−B,√3(G−B)) divisée par Y. Hue est atan2 de ce même opposant, avec différence angulaire modulo 2π ; il est ignoré sous chroma .001. Ces mesures diagnostiques ne sont pas ΔE perceptuels.

        Identité : erreur RGB exactement nulle après bypass. Luminance : max |ΔY| < 2×10⁻⁵ linéaire pour les rampes SDR/HDR mesurées, marge d'arrondi GPU nettement inférieure à une variation photographique visible. Cette borne est justifiée par la projection analytique à Y constant, pas une correction des mesures. Continuité : pas adjacent de ratio < .02, angle < .08 rad à ΔY=1/4095. Les quatre premiers points ne servent pas au test de ratios pour éviter la division near-black ; les valeurs négatives/noires sont testées séparément. Les valeurs complètes figurent dans les courbes et checks.json.

        Le meilleur overlay constant est ajusté par moindres carrés : pour chaque canal `gain−1=Σ input·(output−input)/Σ input²`. Ce baseline est plus favorable qu'un simple aplat arbitraire. Le résidu vérifie la composante dépendante de la densité. WARN si le ratio varie de moins de .001 ou le résidu MAE tombe sous .0001 hors Neutral. Voir [comparaison quantitative](SilverToning_vs_constant_overlay.md).

        Diversité : MAE RGB sur mire SDR/HDR/near-black puis moyenne non pondérée des huit photos. WARN uniquement lorsque deux presets sont proches à la fois sur synthétique (≤.001) et photos (≤.0005). Neutral, Subtle Selenium et Platinum Print ne subissent pas ce seuil d'expressivité ; leurs amplitudes restent mesurées. Les matrices ne constituent pas une approbation visuelle.

        ## Photographies

        Chaque original passe exactement une fois par Neutral Silver, réglages inchangés pour toutes les variantes. Les onze presets partent de cette même base. Huit photos, hashes avant/après, contacts, différences ×8 et crops natifs 384px ; mesures locales sur 128px. Les portraits incluent peau, yeux, lèvres, cheveux ; peau sombre, vêtement sombre et reflet cutané sont mesurés séparément. Le sujet blanc compare papier neutre, chaud, froid et chaud fort avec argent désactivé. Les crops et la planche de référence restent soumis à inspection esthétique humaine.

        Les fréquences/RMS de luminance utilisent LabGPU.structure existant. Un traitement pointwise non linéaire peut transformer les fréquences de chroma liées au signal d'entrée : l'invariant spatial concerne l'absence de mélange de voisins et de nouveau bruit, avec luminance/textures intactes. Aucun prétendu invariant FFT RGB impossible n'est imposé.

        ## Infrastructure commune

        Protocoles existants réutilisés : simple/inverted/stacked/subtractive (erreur hors masque <2×10⁻⁶), transition douce, état Codable, preset→Custom→preset, Undo/Undo/Redo, ordre des piles, cache preview et export. Silver B&W placé après le toning supprime la coloration ; placé avant fournit la base neutre. Les autres permutations ne sont pas forcées à commuter.

        Performance : cinq commandes GPU après chauffe, timestamp Metal `gpuEndTime−gpuStartTime`, sortie RGBA32Float privée, sans readback dans la mesure GPU. Temps CPU distinct pour validation des réglages/préparation du graphe ; temps mur inclut encodage/synchronisation. Ces temps ne sont pas des mesures isolées du kernel ni des performances iPhone. Le moteur possède uniquement un kernel statique, pas de cache de textures propre. Quatre lots de 36 changements contrôlent la croissance RSS après chauffe, sans prétendre remplacer Instruments.

        ## Résultats détaillés

        """
        for c in selected {
            md += "### \(c.name) — \(c.status)\n\n"
            let issues=c.checks.filter{$0.status != "PASS"}
            for issue in issues {md += "- **\(issue.status)** \(issue.name) : \(issue.detail)\n"}
            if !issues.isEmpty {md += "\n"}
            if c.name.hasPrefix("ST_photo_") || c.name=="ST_preset_diversity" {
                md += "Mesures détaillées dans [checks.json](SilverToning/checks.json).\n\n"
            } else {
                md += "| Mesure | Valeur |\n|---|---:|\n"
                for key in c.metrics.keys.sorted() {md += "| \(key) | \(String(format:"%.8g",c.metrics[key]!)) |\n"}
                md += "\n"
            }
        }
        md += "## Artefacts prioritaires\n\n"
        for p in ["SilverToning/reference_triptych.png","SilverToning/not_an_overlay.png","SilverToning/all_density_responses.png",
                  "SilverToning/RealPhotos/01_portrait_light_skin/portrait_light_toning_comparison.png",
                  "SilverToning/RealPhotos/02_portrait_dark_skin/portrait_dark_toning_comparison.png",
                  "SilverToning/RealPhotos/05_night/night_toning_comparison.png",
                  "SilverToning/RealPhotos/07_white_subject/paper_tone_white_subject.png"] {
            md += "- [\(p)](\(p))\n"
        }
        md += "\n## Arrêt\n\nParamètres et seuils figés avant exécution. Tout WARN/FAIL est à documenter puis inspecter, sans correction automatique. Aucun Golden Master ni commit automatique demandé pour cette étape. Les artefacts photographiques restent dans TestArtifacts selon la convention locale.\n"
        try md.write(to:artifacts.url("SilverToningValidationReport.md"),atomically:true,encoding:.utf8)
    }
}
