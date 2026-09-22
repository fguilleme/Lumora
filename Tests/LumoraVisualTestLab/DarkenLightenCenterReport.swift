import Foundation
@testable import LumoraCore

extension LumoraVisualTestLab {
    func dlcReport() throws {
        let selected=cases.filter{$0.name.hasPrefix("DLC_")}
        try artifacts.json(selected,"DarkenLightenCenter/checks.json")
        try artifacts.json(CreativeFXPreset.all(for:.darkenLightenCenter).map{$0.makeEffect()},"DarkenLightenCenter/presets.json")
        let counts=["PASS","WARN","FAIL"].map{s in "\(selected.filter{$0.status==s}.count) \(s)"}.joined(separator:", ")
        var md="""
        # Darken / Lighten Center — validation

        **\(counts)** — cas du banc. Les contrôles hard et les quality heuristics sont distingués ci-dessous. Un PASS technique ne vaut pas approbation photographique. Pas de Golden Master ni de retouche automatique après mesure. Matériel : \(gpu.deviceName), \(ProcessInfo.processInfo.operatingSystemVersionString).

        ## Architecture et géométrie

        Effet indépendant `DarkenLightenCenterSettings` / `DarkenLightenCenterRenderer`, enregistré dans CreativeEffectStack. Même compositor de masques, opacité, snapshots preset/Custom, historique et RenderEngine. Un kernel analytique GPU, aucun bitmap de masque CPU par frame, aucun flou, voisinage, sharpening ou bruit. Les autres renderers restent inchangés.

        Center X/Y sont normalisés sur **l’image développée reçue par l’effet**, de (0,0) en haut à gauche à (1,1) en bas à droite, après orientation EXIF et géométrie du document. Ils sont bornés à [0,1] comme les poignées d’image ; le champ peut néanmoins déborder de l’image. Un crop appliqué avant DLC change son repère ; un crop après conserve le champ précédent. Aucun recentrage automatique près des bords.

        Pour l’extent (ox,oy,w,h) et un échantillon CI (x,y), `p=((x−ox−Cx·w),(oy+h−y−Cy·h))/min(w,h)`. Le repère y est ainsi inversé du CI bas-gauche vers l’UI haut-gauche. Après rotation inverse `q=R(−θ)p`, les rayons sont `rx=(Size/100)·2^(Shape/100)` et `ry=(Size/100)/2^(Shape/100)`. Distance `d=sqrt((qx/rx)²+(qy/ry)²)`. Un cercle a donc le même rayon physique en x et y quel que soit le ratio d’image ; l’aire elliptique reste constante à Size fixe. Pour Shape=0, l’angle du kernel est canonisé à zéro, sans modification des settings.

        `width=0.15+0.85·Feather/100`, `t=clamp((d−(1−width))/width,0,1)`, `M=1−(6t⁵−15t⁴+10t³)`. La transition est C2 aux plateaux, y compris à Feather=0 (largeur minimale 15 % du rayon). Size=5…150 % du petit côté permet des régions dépassant l’image, sans rayon nul. Shape=−100…100 donne des axes réciproques ×0.5…2. Rotation=−180…180°, positive dans le sens horaire à l’écran.

        ## Exposition et couleur

        `EV=BorderEV+(CenterEV−BorderEV)·M`, puis `gain=1+Amount/100·(2^EV−1)` et `RGBout=RGBin·gain`, alpha inchangé. Center et Border, chacun −2…+2 EV, sont indépendants. Amount est le blend final en RGB linéaire, pas une interpolation des stops. Amount=0 et Center=Border=0 retournent strictement l’entrée. Center=Border=E correspond à l’exposition uniforme E, indépendamment de toute géométrie.

        Gain positif : les petites valeurs négatives gardent leur signe, les valeurs HDR restent au-delà de 1, sans clamp. Un RGB positif conserve ses rapports colorimétriques avant la conversion d’affichage. Les PNG sont des vues SDR : un éclaircissement peut légitimement créer de l’écrêtage à la sortie. Les tableaux distinguent clipping initial et nouveaux pixels atteignant un canal ≥1 ; aucun roll-off caché ne compense les presets.

        ## Interaction UI

        Poignée centrale 48×48 points avec dessin discret de 22 points, contour extérieur et limite intérieure du feather. Le drag inverse la même transformation aspect-fit/zoom/pan que le canvas via `DLCViewport`. L’état d’overlay et la sélection sont uniquement UI, jamais dans les settings, le cache ou l’export. Il apparaît seulement dans Creative pour l’instance DLC sélectionnée, activée et visible, hors comparaison Original et bypass. L’ellipse suit le zoom, les paramètres restent en coordonnées normalisées. Un begin/end par drag réutilise le regroupement Undo/Redo existant.

        Size, Shape, Feather et Rotation utilisent les curseurs standards. Aucun handle de rotation/taille supplémentaire ; les coordonnées fines X/Y sont dans « Position précise X / Y ». La poignée porte un label, sa valeur normalisée et une indication des curseurs accessibles. Le catalogue et les presets utilisent les boutons/menu/chips existants, pas des titres décoratifs. Les vérifications simulateur sont consignées à la fin de la campagne.

        ## Seuils et interprétation

        Oracle géométrique Float64 indépendant : max erreur RGB <3×10⁻⁶ sur les mires uniformes. Identités : zéro exact. Rotation cercle : zéro exact ; symétries/axes/extent : 2×10⁻⁶. Profils à 4096 échantillons : première différence EV <.025, seconde <.001 ; aucune sortie hors enveloppe EV. Profils radiaux GPU échantillonnés au pixel le plus proche : erreur EV <.015 pour une empreinte ≤.71 pixel. Centroïde subpixel : erreur normalisée <10⁻⁵. Transformée UI aller-retour : <10⁻¹².

        Preview/export : centre/rayon normalisés <.003, angle <1°, profil MAE <.002, avec codec 8 bits et normalisation commune. Orientations EXIF 1…8 : comparaison à l’orientation CI indépendante avec coins colorés asymétriques, MAE <.003. Les tolérances couvrent les arrondis et l’échantillonnage ; aucune n’est ajustée en réaction à une qualité esthétique.

        Qualité : nouveaux pixels SDR écrêtés >2 points de pourcentage → WARN à inspecter. Presets non subtils proches sur photos et mire uniforme (MAE≤.003 dans les deux) → WARN ; Subtle Focus volontairement exempt. Les métriques ne servent pas à uniformiser ou renforcer artificiellement les presets.

        ## Presets

        """
        md += CreativeFXPreset.all(for:.darkenLightenCenter).map(\.title).joined(separator:", ")+".\n\n"
        md += "## Tableau géométrique\n\nErreur RGB sur champ uniforme mesurée face à l’oracle ; les déplacements, rayons et angles preview/export sont reportés séparément dans leurs unités.\n\n"
        if let data=try? Data(contentsOf:artifacts.url("DarkenLightenCenter/geometry_table.json")),let rows=try? JSONDecoder().decode([[String:Double]].self,from:data) {
            md += "| Ratio | Centre X/Y | Size | Shape | Rotation | Feather | Center/Border EV | Erreur max | État |\n|---|---|---:|---:|---:|---:|---|---:|---|\n"
            for r in rows {md += "| \(r["width"]!)/\(r["height"]!) | \(r["centerX"]!), \(r["centerY"]!) | \(r["size"]!) | \(r["shape"]!) | \(r["rotation"]!) | \(r["feather"]!) | 1 / −1 | \(r["maxRGBError"]!) | \(r["maxRGBError"]!<3e-6 ? "PASS":"FAIL") |\n"}
        }
        md += "\n## Résultats et type de chaque contrôle\n\n"
        for c in selected {
            md += "### \(c.name) — \(c.status)\n\n| Contrôle | Type | État | Critère |\n|---|---|---|---|\n"
            for check in c.checks {md += "| \(check.name) | \(check.hard ? "hard invariant":"quality heuristic") | \(check.status) | \(check.detail) |\n"}
            if !c.metrics.isEmpty {
                md += "\n| Mesure | Valeur |\n|---|---:|\n"
                for key in c.metrics.keys.sorted() {md += "| \(key) | \(String(format:"%.8g",c.metrics[key]!)) |\n"}
            }
            md += "\n"+c.notes.joined(separator:"\n")+"\n\n"
        }
        md += "## Tableau photographique\n\nOriginaire et réglages positionnés séparés ; `fixed_photo_settings.json` documente tous les centres choisis une seule fois, sans détection. Statistiques en RGBAf après réduction pleine image à 512px. Shadow RMS = écart-type de Y de sortie pour les pixels dont Y d’entrée <.1. Chromaticité = erreur maximale des ratios RGB/somme. Le redimensionnement après un gain variable peut produire une très faible différence de ratios sur des couleurs voisines ; les hard checks utilisent des ROI natives sans ce rééchantillonnage.\n\n"
        if let data=try? Data(contentsOf:artifacts.url("DarkenLightenCenter/photo_statistics.json")),let rows=try? JSONDecoder().decode([String:[String:Double]].self,from:data) {
            md += "| Photo / preset | Mean Y | P01 | P05 | P50 | P95 | Clipped | New clipped | Shadow RMS | Chroma drift | Nonfinite |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
            for key in rows.keys.sorted() {
                md += "| \(key) | "+["meanLuminance","P01","P05","P50","P95","clippedFraction","newClippedFraction","shadowRMS","chromaticityDrift","nonFinitePixels"].map{String(format:"%.7g",rows[key]![$0]!)}.joined(separator:" | ")+" |\n"
            }
        }
        md += "\n## Performance et limites\n\nGPU command timestamps sur entrée variable (pas un simple générateur uniforme), cinq répétitions après chauffe, sortie texture RGBA32Float sans readback dans la mesure GPU. CPU : validation/préparation du graphe, séparée du temps mur d’encodage/synchronisation. Multi-instance : matérialisation complète avec readback, protocole explicitement différent. RSS par lots de changements ne remplace pas Instruments. Mesures Mac, pas certification iPhone 48MP/thermique. Aucun masque raster ni cache d’image propre à DLC.\n\n## Priority Visual Inspection\n\nPremière planche : **off_center_real_photos.png**. Les planches réelles restent locales ; les résultats ne sont pas des Golden Masters.\n\n"
        for path in ["off_center_real_photos.png","ev_field_map.png","ev_field_isolines.png","circle_aspect_ratio.png","rotation.png","feather_response.png","center_border_independence.png","not_just_a_vignette.png","compositional_examples.png","RealPhotos/01_portrait_light_skin/portrait_light_focus_comparison.png","RealPhotos/02_portrait_dark_skin/portrait_dark_focus_comparison.png","RealPhotos/03_landscape_clouds/landscape_focus_comparison.png","RealPhotos/04_backlight/backlight_focus_comparison.png","RealPhotos/05_night/night_focus_comparison.png","RealPhotos/07_white_subject/white_subject_focus_comparison.png"] {md += "- [\(path)](DarkenLightenCenter/\(path))\n"}
        try md.write(to:artifacts.url("DarkenLightenCenterValidationReport.md"),atomically:true,encoding:.utf8)
    }
}
