import Foundation
@testable import LumoraCore

extension LumoraVisualTestLab {
    func silverReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("SBW_")}
        try artifacts.json(selected,"SilverBW/checks.json")
        try artifacts.json(CreativeFXPreset.all(for:.silverBW).map{$0.makeEffect()},"SilverBW/presets.json")
        let count=["PASS","WARN","FAIL"].map{status in "\(selected.filter{$0.status==status}.count) \(status)"}.joined(separator:", ")
        func number(_ v:Double)->String {String(format:"%.7g",v)}
        var md="""
        # Silver B&W — validation

        **\(count)** (cas ; tous les hard invariants sont détaillés dans [checks.json](SilverBW/checks.json)). PASS n'est pas une approbation esthétique. WARN demande une inspection. Aucun Golden Master, aucun ajustement automatique après ce banc. GPU : \(gpu.deviceName). OS : \(ProcessInfo.processInfo.operatingSystemVersionString).

        ## Architecture et domaine

        Le moteur `SilverBWRenderer` est enregistré dans la pile Creative existante. Il réutilise les masques, l'opacité, le matcher Preset/Custom, l'historique et RenderEngine pour preview/HQ/export. Aucun renderer existant ni valeur de preset existant n'est modifié. `SilverBWSettings` représente le snapshot sérialisable des onze réglages.

        Ordre : RGB linéaire étendu → densité spectrale et filtre photographique → Brightness → Dynamic Brightness → réponse film et contrôles tonaux → Structure → Amount. La luminosité est appliquée avant la courbe pour conserver une réponse photographique dans le toe et le shoulder. Tous les calculs d'image sont GPU Core Image/Metal, sans readback CPU par frame dans le moteur. Les readbacks de ce rapport appartiennent seulement au Lab.

        ### Modèle spectral original

        Pour `p=max(RGB,0)`, `s=p.r+p.g+p.b+10⁻⁶`, les coordonnées continues sont `u=(2p.r−p.g−p.b)/s` et `v=√3(p.g−p.b)/s`. Elles s'annulent sur le gris ; elles tendent continûment vers zéro au noir. La sensibilité d'un film est `E=a·u+b·v+c·(u²−v²)+d·2uv`. Ces harmoniques différencient rouge, orange, jaune, vert, cyan, bleu et magenta sans secteurs HSV abrupts.

        La densité d'entrée est `D=Y·2^(E+F)`, avec `Y=0.2126R+0.7152G+0.0722B`. Y sert d'ancrage perceptuel ; la sortie n'est pas une simple conversion Y et n'est pas une désaturation. Les gains spectraux ne sont pas renormalisés entre les couleurs, ce qui conserverait mal l'intention d'un filtre photographique. Il s'agit d'une approximation RGB originale, pas d'une mesure de sensibilité physique d'une émulsion commerciale.

        Le filtre continu est `F=1.05·strength·(u·cos(hue)+v·sin(hue))`, strength dans [0,1]. Rouge=0°, orange=30°, jaune=60°, vert=120°, bleu=240°. Ces boutons ne changent que le même couple hue/strength. None met strength à zéro. La sensibilité du film reste active sans filtre. La sortie complète reste neutre ; seul Amount partiel conserve de la couleur d'origine.

        ### Réponses film

        Les coefficients suivants sont les valeurs originales choisies avant le banc, sans profil commercial ou LUT externe. Fine Grain Response ne génère aucun grain.

        | Réponse | Spectre a,b,c,d | Exposant toe p | Exposant shoulder q | Échelle shoulder h |
        |---|---|---:|---:|---:|
        """
        for response in SilverFilmResponse.allCases {
            let sp=response.spectrum,t=response.tone
            md += "\n| \(response.title) | \(sp.x), \(sp.y), \(sp.z), \(sp.w) | \(t.x) | \(t.y) | \(t.z) |"
        }
        md += """


        Classic Panchromatic utilise une faible déviation spectrale. Portrait Silver favorise modérément les couleurs chaudes des carnations. Soft Orthochromatic réduit le rouge relativement au bleu/vert sans seuil dur. High Contrast Film utilise un toe plus dense et une séparation tonale plus forte. Les autres réponses combinent des coefficients spectraux/tonaux différents sans texture ajoutée.

        ### Courbe, luminosité et HDR

        Brightness multiplie `|D|` par `2^(1.5·brightness)`. Dynamic Brightness applique ensuite `x ← x·2^(0.8·dynamic/(1+x/0.35))`. Cette adaptation dépend uniquement du ton et non du voisinage. Sa dérivée garde le signe puisque `1−0.8·ln(2)/4 > 0`.

        Soit `L(x,s)=ln((1+x/s)/(1+0.18/s))`. Le rendu tonal positif est

        `T(x)=x·exp(p·L(x,0.08)−q·L(x,h)+0.24·contrast·L(x,0.18)−0.16·softContrast·L(x,0.45)+0.18·blacks·L(x,0.04)+0.10·whites·L(x,0.85))`.

        Les réglages signés sont normalisés dans [−1,1]. Tous les profils ont `p>0` et `q≤0.26`. La dérivée logarithmique est la somme de 1 et de termes `coefficient·x/(s+x)`. Même en majorant séparément tous les termes négatifs, elle reste ≥ `1−0.26−0.24−0.16−0.18−0.10=0.06`. Cette borne porte sur la courbe tonale pointwise, pas sur une image spatiale avec Structure. Le test énumère les 64 combinaisons extrêmes des six contrôles tonaux/lumineux pour chacun des sept profils.

        Les zéros restent des zéros, les near-blacks conservent une pente, et la formule continue au-delà de 1 sans clamp ni épaule à plateau. Les valeurs monochromes négatives suivent l'extension impaire, de même pente finie à zéro. Le gris 0.18 est ancré pour les contrôles de forme à Brightness/Dynamic Brightness nuls. Le filtre peut déplacer une couleur par rapport à cet ancrage.

        Contrast et Soft Contrast ont des échelles distinctes : l'un accentue principalement la séparation médiane, l'autre élargit les transitions et réduit progressivement les hautes valeurs lorsqu'il est positif. Ce n'est ni une diffusion ni un alias de Glamour Glow. Le comparatif fixe Contrast +45 et Soft Contrast −70 pour rapprocher l'amplitude des deux augmentations de contraste ; Soft Contrast +70 montre aussi la compression douce, sans réglage après mesure.

        Blacks positif densifie le bas de la courbe tout en préservant sa pente. Whites module progressivement les lumières, sans écrêtage explicite. Les contrôles sont des formes larges et peuvent avoir un effet secondaire ailleurs dans la courbe.

        ### Structure

        Structure utilise directement `TonalContrastRenderer`, inchangé : globalAmount=Structure, shadows=22, midtones=48, highlights=28, radius=35, protectShadows/protectHighlights=85, saturation=0. Les rayons suivent le grand côté / 3000 de la primitive existante. Le traitement est appliqué après la conversion et la courbe, puis les canaux sont remis exactement à la même valeur pour éviter une dérive numérique. Les valeurs négatives de la conversion sont conservées puisque la primitive locale est conçue pour les luminances non négatives.

        Structure=0 contourne entièrement ce traitement spatial. Aucun lissage de peau, détection de visage, bruit, grain, sépia ou autre toning n'est ajouté. Soft Portrait n'utilise que Structure=8 ; les looks documentaires sont volontairement plus marqués. Les limites de halo, RMS et résolution reprennent les diagnostics existants, avec inspection photographique requise.

        ## Couleurs réellement équiluminantes

        Les patches sont construits avec Y=0.05 linéaire, puis leur luminance réellement rendue est mesurée. Cela permet même au bleu pur de rester sous RGB=1. Les pics RGB ne sont pas égaux. Le tableau donne la luminance de sortie avec Filter Strength=0 ; une valeur plus basse signifie une densité photographique plus forte. Le JSON des filtres fournit aussi `−log10(Y)`.

        | Couleur | Y réel entrée | Neutral | Portrait | Panchromatic | Orthochromatic |
        |---|---:|---:|---:|---:|---:|
        """
        if let c=selected.first(where:{$0.name=="SBW_equiluminant_colors"}) {
            for name in SilverBWTestChart.colorNames {
                md += "\n| \(name) | " + [name+"-actualY",name+"-Neutral Silver-Y",name+"-Portrait Silver-Y",name+"-Classic Panchromatic-Y",name+"-Soft Orthochromatic-Y"].map{number(c.metrics[$0] ?? 0)}.joined(separator:" | ")+" |"
            }
        }
        md += "\n\n## Filtres rouge, vert, jaune, orange et bleu\n\nRouge et vert : forces 0/25/50/75/100, progression mesurée sur les mêmes patches. Cyan contient du vert : il est transmis par le filtre vert. Jaune/orange/rouge : rapport ciel/peau explicitement comparé à None. Bleu : inclus dans le tableau coloré, le balayage continu et les mesures de neutralité de tous les profils. Hue est balayé au degré près de 0 à 360 ; le raccord est contrôlé exactement.\n\n"
        for c in selected where ["SBW_red_filter_progression","SBW_green_filter_progression","SBW_contrast_vs_soft_contrast"].contains(c.name) {
            md += "### \(c.name) — \(c.status)\n\n| Mesure | Valeur |\n|---|---:|\n"
            for key in c.metrics.keys.sorted() {md += "| \(key) | \(number(c.metrics[key]!)) |\n"}
            md += "\n"
        }
        md += "## Corpus et presets\n\nHuit originaux existants, SHA256 avant/après et crops vérifiés sur les sources. Les mesures comparent le cadre entier réduit sur le grand côté, sans recadrage involontaire des portraits. Les images exportées individuellement restent à leur résolution source. Chaque photo possède Original + les huit presets, des crops natifs et les réglages JSON. Les filtres sont comparés séparément sur les deux portraits, le paysage et le sujet blanc. Structure 0/25/50/75/100 est comparée sur peau, cheveux, pierre, tissu et nuages.\n\nPresets : " + CreativeFXPreset.all(for:.silverBW).map(\.title).joined(separator:", ") + ".\n\n"
        md += "| Photo | État | Inspection |\n|---|---|---|\n"
        for c in selected where c.name.hasPrefix("SBW_photo_") {
            md += "| \(c.name) | \(c.status) | " + c.images.map{"[image](\($0))"}.joined(separator:" · ")+" |\n"
        }
        md += "\nLa peau claire et sombre est mesurée dans des ROI distinctes : variation tonale/RMS, luminance et neutralité. Les yeux, lèvres, cheveux et vêtements sont des crops photographiques, sans aucun traitement sémantique. Les rapports RMS sont des heuristiques ; une image monochrome peut légitimement changer les contrastes liés à la couleur. Les chiffres par preset/ROI sont dans checks.json.\n\n"
        if let c=selected.first(where:{$0.name=="SBW_preset_diversity"}) {
            md += "### Diversité — \(c.status)\n\nMAE RGB linéaire sur la mire, puis moyenne non pondérée des huit photos. Seuil de proximité existant : 0.004. Aucun look n'est changé après les résultats. Les [matrices numériques](SilverBW/preset_distances.json) accompagnent la [figure photo](SilverBW/preset_distance_matrix.png) et la [figure synthétique](SilverBW/synthetic_preset_distance_matrix.png).\n\n"
        }
        md += "## Protocoles communs réutilisés\n\nLabGPU, LabArtifacts, TonalContrastTestChart, CreativeStackRenderer, MaskRenderer, HistoryManager, matcher central et RenderEngine sont utilisés directement. Simple/inverted/stacked/subtractive sont comparés aux mêmes ROI d'isolation que Film Emulation, tolérance 2×10⁻⁶. La description des infrastructures communes n'est pas recopiée ; résultats et métriques de cette intégration figurent dans checks.json.\n\n"
        md += "| Cas | État | MAE des deux ordres |\n|---|---|---:|\n"
        for c in selected where c.name.hasPrefix("SBW_stack_") {md += "| \(c.name) | \(c.status) | \(number(c.metrics["orderMAE"] ?? 0)) |\n"}
        md += "\nFilm Emulation/Cross Processing avant Silver : leurs couleurs participent à la conversion de densité. Après Silver : ils reçoivent du gris et peuvent réintroduire une coloration, ce qui n'est pas une violation de la neutralité de Silver seul. Les deux ordres sont matérialisés par la pile réelle.\n\n## Performance, résolution et mémoire\n\nLes médianes 1024/2048/4096 sont mesurées après chauffe, sur trois matérialisations RGBAf natives complètes ; elles incluent allocation et readback, pas seulement le temps du kernel GPU. Structure 0 et 50 sont distinguées. L'effet lui-même n'a pas de branche interactive/HQ : le RenderEngine règle les résolutions en amont. Les latences réelles preview/HQ sont indiquées séparément. Pas de LUT à reconstruire, profils fixes et kernels statiques ; aucun cache d'image détenu par Silver. RSS avant/après 28 changements donne un contrôle borné de processus et ne remplace pas une mesure thermique/mémoire sur iPhone.\n\n"
        for c in selected where c.name=="SBW_standard_resolution_performance_memory" || c.name=="SBW_standard_preview_HQ_export_cache" {
            md += "### \(c.name) — \(c.status)\n\n| Mesure | Valeur |\n|---|---:|\n"
            for key in c.metrics.keys.sorted(){md += "| \(key) | \(number(c.metrics[key]!)) |\n"}
            md += "\n"
        }
        md += "## Résultats et réserves\n\n| Cas | Statut | WARN / FAIL |\n|---|---|---|\n"
        for c in selected {
            let issues=c.checks.filter{$0.status != "PASS"}.map{$0.name+": "+$0.detail}.joined(separator:" ; ")
            md += "| \(c.name) | \(c.status) | \(issues) |\n"
        }
        md += "\n## Artefacts prioritaires\n\n"
        for path in ["SilverBW/film_response_color_chart.png","SilverBW/red_filter_response.png","SilverBW/skin_filter_matrix.png",
                     "SilverBW/RealPhotos/01_portrait_light_skin/portrait_silver_comparison.png",
                     "SilverBW/RealPhotos/02_portrait_dark_skin/portrait_silver_comparison.png",
                     "SilverBW/RealPhotos/03_landscape_clouds/landscape_silver_comparison.png",
                     "SilverBW/RealPhotos/07_white_subject/red_filter_comparison.png"] {
            md += "- [\(path)](\(path))\n"
        }
        md += "\nCompléments : [Structure photographique](SilverBW/structure_comparison.png), [Contraste doux](SilverBW/contrast_vs_soft_contrast.png), [Blacks/Whites](SilverBW/blacks_whites_response.png), [Hue continu](SilverBW/filter_hue_response.png), [courbes](SilverBW/characteristic_curves.png).\n"
        try md.write(to:artifacts.url("SilverBWValidationReport.md"),atomically:true,encoding:.utf8)
    }
}
