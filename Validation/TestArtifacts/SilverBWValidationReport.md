# Silver B&W — validation

**47 PASS, 0 WARN, 0 FAIL** (cas ; tous les hard invariants sont détaillés dans [checks.json](SilverBW/checks.json)). PASS n'est pas une approbation esthétique. WARN demande une inspection. Aucun Golden Master, aucun ajustement automatique après ce banc. GPU : Apple M2 Pro. OS : Version 26.6.2 (Build 25G83).

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
| Neutral Silver | 0.12, 0.06, 0.025, -0.02 | 0.13 | 0.16 | 0.8 |
| Fine Grain Response | 0.08, 0.1, -0.04, 0.025 | 0.09 | 0.2 | 0.65 |
| Portrait Silver | 0.34, 0.13, -0.035, 0.045 | 0.07 | 0.24 | 0.55 |
| Classic Panchromatic | 0.04, 0.025, 0.015, 0.01 | 0.19 | 0.18 | 0.85 |
| High Contrast Film | 0.14, -0.06, 0.045, -0.025 | 0.4 | 0.26 | 0.72 |
| Soft Orthochromatic | -0.48, 0.1, -0.06, 0.035 | 0.1 | 0.22 | 0.6 |
| Documentary Silver | -0.08, 0.16, 0.055, -0.04 | 0.28 | 0.2 | 0.95 |

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
| red | 0.05 | 0.05977114 | 0.07276403 | 0.04979621 | 0.02082865 |
| orange | 0.05 | 0.05396032 | 0.07024072 | 0.04820362 | 0.03080268 |
| yellow | 0.05 | 0.04959878 | 0.06325243 | 0.0463477 | 0.04546414 |
| green | 0.05 | 0.0468521 | 0.04340048 | 0.04292457 | 0.07710121 |
| cyan | 0.05 | 0.04365032 | 0.03842904 | 0.04408829 | 0.06539935 |
| blue | 0.05 | 0.03651623 | 0.03939913 | 0.04238103 | 0.07161926 |
| magenta | 0.05 | 0.04717952 | 0.05119581 | 0.04432234 | 0.0385347 |

## Filtres rouge, vert, jaune, orange et bleu

Rouge et vert : forces 0/25/50/75/100, progression mesurée sur les mêmes patches. Cyan contient du vert : il est transmis par le filtre vert. Jaune/orange/rouge : rapport ciel/peau explicitement comparé à None. Bleu : inclus dans le tableau coloré, le balayage continu et les mesures de neutralité de tous les profils. Hue est balayé au degré près de 0 à 360 ; le raccord est contrôlé exactement.

### SBW_red_filter_progression — PASS

| Mesure | Valeur |
|---|---:|
| blue-strength0-Y | 0.03651623 |
| blue-strength0-opticalDensity | 1.437514 |
| blue-strength100-Y | 0.01728018 |
| blue-strength100-opticalDensity | 1.762452 |
| blue-strength25-Y | 0.03025674 |
| blue-strength25-opticalDensity | 1.519178 |
| blue-strength50-Y | 0.02508745 |
| blue-strength50-opticalDensity | 1.600543 |
| blue-strength75-Y | 0.02081479 |
| blue-strength75-opticalDensity | 1.681628 |
| cyan-strength0-Y | 0.04365032 |
| cyan-strength0-opticalDensity | 1.360013 |
| cyan-strength100-Y | 0.0206047 |
| cyan-strength100-opticalDensity | 1.686034 |
| cyan-strength25-Y | 0.03614361 |
| cyan-strength25-opticalDensity | 1.441968 |
| cyan-strength50-Y | 0.02994918 |
| cyan-strength50-opticalDensity | 1.523615 |
| cyan-strength75-Y | 0.02483336 |
| cyan-strength75-opticalDensity | 1.604964 |
| green-strength0-Y | 0.0468521 |
| green-strength0-opticalDensity | 1.329271 |
| green-strength100-Y | 0.02209357 |
| green-strength100-opticalDensity | 1.655734 |
| green-strength25-Y | 0.03878433 |
| green-strength25-opticalDensity | 1.411344 |
| green-strength50-Y | 0.03212887 |
| green-strength50-opticalDensity | 1.493105 |
| green-strength75-Y | 0.02663405 |
| green-strength75-opticalDensity | 1.574563 |
| red-strength0-Y | 0.05977114 |
| red-strength0-opticalDensity | 1.223508 |
| red-strength100-Y | 0.278153 |
| red-strength100-opticalDensity | 0.5557163 |
| red-strength25-Y | 0.08756593 |
| red-strength25-opticalDensity | 1.057665 |
| red-strength50-Y | 0.1285824 |
| red-strength50-opticalDensity | 0.8908184 |
| red-strength75-Y | 0.1890879 |
| red-strength75-opticalDensity | 0.7233363 |

### SBW_green_filter_progression — PASS

| Mesure | Valeur |
|---|---:|
| blue-strength0-Y | 0.03651623 |
| blue-strength0-opticalDensity | 1.437514 |
| blue-strength100-Y | 0.01728019 |
| blue-strength100-opticalDensity | 1.762452 |
| blue-strength25-Y | 0.03025675 |
| blue-strength25-opticalDensity | 1.519178 |
| blue-strength50-Y | 0.02508746 |
| blue-strength50-opticalDensity | 1.600543 |
| blue-strength75-Y | 0.0208148 |
| blue-strength75-opticalDensity | 1.681628 |
| cyan-strength0-Y | 0.04365032 |
| cyan-strength0-opticalDensity | 1.360013 |
| cyan-strength100-Y | 0.06380276 |
| cyan-strength100-opticalDensity | 1.195161 |
| cyan-strength25-Y | 0.04798255 |
| cyan-strength25-opticalDensity | 1.318917 |
| cyan-strength50-Y | 0.0527543 |
| cyan-strength50-opticalDensity | 1.277742 |
| cyan-strength75-Y | 0.058011 |
| cyan-strength75-opticalDensity | 1.23649 |
| green-strength0-Y | 0.0468521 |
| green-strength0-opticalDensity | 1.329271 |
| green-strength100-Y | 0.2171497 |
| green-strength100-opticalDensity | 0.6632408 |
| green-strength25-Y | 0.06851897 |
| green-strength25-opticalDensity | 1.164189 |
| green-strength50-Y | 0.1004719 |
| green-strength50-opticalDensity | 0.9979556 |
| green-strength75-Y | 0.1476275 |
| green-strength75-opticalDensity | 0.8308328 |
| red-strength0-Y | 0.05977114 |
| red-strength0-opticalDensity | 1.223508 |
| red-strength100-Y | 0.02808407 |
| red-strength100-opticalDensity | 1.55154 |
| red-strength25-Y | 0.04943282 |
| red-strength25-opticalDensity | 1.305985 |
| red-strength50-Y | 0.04091218 |
| red-strength50-opticalDensity | 1.388147 |
| red-strength75-Y | 0.03388468 |
| red-strength75-opticalDensity | 1.469997 |

### SBW_contrast_vs_soft_contrast — PASS

| Mesure | Valeur |
|---|---:|
| amplitudeRatio | 0.788334 |
| betweenMAE | 0.02341776 |
| contrastMAE | 0.1106354 |
| softContrastMAE | 0.08721767 |

## Corpus et presets

Huit originaux existants, SHA256 avant/après et crops vérifiés sur les sources. Les mesures comparent le cadre entier réduit sur le grand côté, sans recadrage involontaire des portraits. Les images exportées individuellement restent à leur résolution source. Chaque photo possède Original + les huit presets, des crops natifs et les réglages JSON. Les filtres sont comparés séparément sur les deux portraits, le paysage et le sujet blanc. Structure 0/25/50/75/100 est comparée sur peau, cheveux, pierre, tissu et nuages.

Presets : Neutral Silver, Soft Portrait, Fine Art, Classic Film, High Structure, Dark Drama, Soft Silver, Hard Documentary.

| Photo | État | Inspection |
|---|---|---|
| SBW_photo_01_portrait_light_skin | PASS | [image](SilverBW/RealPhotos/01_portrait_light_skin/SilverBW_contact_sheet.png) · [image](SilverBW/RealPhotos/01_portrait_light_skin/portrait_silver_comparison.png) · [image](SilverBW/RealPhotos/01_portrait_light_skin/color_filter_comparison.png) |
| SBW_photo_02_portrait_dark_skin | PASS | [image](SilverBW/RealPhotos/02_portrait_dark_skin/SilverBW_contact_sheet.png) · [image](SilverBW/RealPhotos/02_portrait_dark_skin/portrait_silver_comparison.png) · [image](SilverBW/RealPhotos/02_portrait_dark_skin/color_filter_comparison.png) |
| SBW_photo_03_landscape_clouds | PASS | [image](SilverBW/RealPhotos/03_landscape_clouds/SilverBW_contact_sheet.png) · [image](SilverBW/RealPhotos/03_landscape_clouds/landscape_silver_comparison.png) · [image](SilverBW/RealPhotos/03_landscape_clouds/color_filter_comparison.png) |
| SBW_photo_04_backlight | PASS | [image](SilverBW/RealPhotos/04_backlight/SilverBW_contact_sheet.png) · [image](SilverBW/RealPhotos/04_backlight/backlight_silver_comparison.png) |
| SBW_photo_05_night | PASS | [image](SilverBW/RealPhotos/05_night/SilverBW_contact_sheet.png) · [image](SilverBW/RealPhotos/05_night/night_silver_comparison.png) |
| SBW_photo_06_indoor_high_contrast | PASS | [image](SilverBW/RealPhotos/06_indoor_high_contrast/SilverBW_contact_sheet.png) · [image](SilverBW/RealPhotos/06_indoor_high_contrast/indoor_silver_comparison.png) |
| SBW_photo_07_white_subject | PASS | [image](SilverBW/RealPhotos/07_white_subject/SilverBW_contact_sheet.png) · [image](SilverBW/RealPhotos/07_white_subject/white_subject_silver_comparison.png) · [image](SilverBW/RealPhotos/07_white_subject/red_filter_comparison.png) |
| SBW_photo_08_fine_texture | PASS | [image](SilverBW/RealPhotos/08_fine_texture/SilverBW_contact_sheet.png) · [image](SilverBW/RealPhotos/08_fine_texture/fine_texture_silver_comparison.png) |

La peau claire et sombre est mesurée dans des ROI distinctes : variation tonale/RMS, luminance et neutralité. Les yeux, lèvres, cheveux et vêtements sont des crops photographiques, sans aucun traitement sémantique. Les rapports RMS sont des heuristiques ; une image monochrome peut légitimement changer les contrastes liés à la couleur. Les chiffres par preset/ROI sont dans checks.json.

### Diversité — PASS

MAE RGB linéaire sur la mire, puis moyenne non pondérée des huit photos. Seuil de proximité existant : 0.004. Aucun look n'est changé après les résultats. Les [matrices numériques](SilverBW/preset_distances.json) accompagnent la [figure photo](SilverBW/preset_distance_matrix.png) et la [figure synthétique](SilverBW/synthetic_preset_distance_matrix.png).

## Protocoles communs réutilisés

LabGPU, LabArtifacts, TonalContrastTestChart, CreativeStackRenderer, MaskRenderer, HistoryManager, matcher central et RenderEngine sont utilisés directement. Simple/inverted/stacked/subtractive sont comparés aux mêmes ROI d'isolation que Film Emulation, tolérance 2×10⁻⁶. La description des infrastructures communes n'est pas recopiée ; résultats et métriques de cette intégration figurent dans checks.json.

| Cas | État | MAE des deux ordres |
|---|---|---:|
| SBW_stack_grain | PASS | 0.0007667587 |
| SBW_stack_tonal_contrast | PASS | 0.0002210033 |
| SBW_stack_detail_extractor | PASS | 0.0002097507 |
| SBW_stack_glamour_glow | PASS | 0.02281142 |
| SBW_stack_film_emulation | PASS | 0.01437618 |
| SBW_stack_cross_processing | PASS | 0.02763358 |

Film Emulation/Cross Processing avant Silver : leurs couleurs participent à la conversion de densité. Après Silver : ils reçoivent du gris et peuvent réintroduire une coloration, ce qui n'est pas une violation de la neutralité de Silver seul. Les deux ordres sont matérialisés par la pile réelle.

## Performance, résolution et mémoire

Les médianes 1024/2048/4096 sont mesurées après chauffe, sur trois matérialisations RGBAf natives complètes ; elles incluent allocation et readback, pas seulement le temps du kernel GPU. Structure 0 et 50 sont distinguées. L'effet lui-même n'a pas de branche interactive/HQ : le RenderEngine règle les résolutions en amont. Les latences réelles preview/HQ sont indiquées séparément. Pas de LUT à reconstruire, profils fixes et kernels statiques ; aucun cache d'image détenu par Silver. RSS avant/après 28 changements donne un contrôle borné de processus et ne remplace pas une mesure thermique/mémoire sur iPhone.

### SBW_standard_preview_HQ_export_cache — PASS

| Mesure | Valeur |
|---|---:|
| HQ-exportMAE | 3.872084e-05 |
| HQ-exportMaxError | 0.0001357375 |
| HQ-exportRMSE | 4.741218e-05 |
| HQ-milliseconds | 176.4147 |
| HQ-width | 2048 |
| export-neutralError | 0.0004631281 |
| interactive-exportMAE | 0.0005539806 |
| interactive-exportMaxError | 0.05829197 |
| interactive-exportRMSE | 0.002325674 |
| interactive-milliseconds | 155.7533 |
| interactive-width | 960 |

### SBW_standard_resolution_performance_memory — PASS

| Mesure | Valeur |
|---|---:|
| 1024-structure0-materializationMedianMS | 7.365125 |
| 1024-structure50-materializationMedianMS | 15.65171 |
| 2048-structure0-materializationMedianMS | 26.67875 |
| 2048-structure0-resolutionRMSE | 0.0001271694 |
| 2048-structure50-materializationMedianMS | 40.31446 |
| 2048-structure50-resolutionRMSE | 0.0001330131 |
| 4096-structure0-materializationMedianMS | 123.1975 |
| 4096-structure0-resolutionRMSE | 0.0001617362 |
| 4096-structure50-materializationMedianMS | 172.8452 |
| 4096-structure50-resolutionRMSE | 0.0001796476 |
| residentAfterBytes | 9.419162e+07 |
| residentBeforeBytes | 9.399501e+07 |

## Résultats et réserves

| Cas | Statut | WARN / FAIL |
|---|---|---|
| SBW_equiluminant_colors | PASS |  |
| SBW_red_filter_progression | PASS |  |
| SBW_green_filter_progression | PASS |  |
| SBW_continuous_filter_hue | PASS |  |
| SBW_skin_filter_matrix | PASS |  |
| SBW_amount_identity_and_blend | PASS |  |
| SBW_neutrality_Neutral Silver | PASS |  |
| SBW_neutrality_Fine Grain Response | PASS |  |
| SBW_neutrality_Portrait Silver | PASS |  |
| SBW_neutrality_Classic Panchromatic | PASS |  |
| SBW_neutrality_High Contrast Film | PASS |  |
| SBW_neutrality_Soft Orthochromatic | PASS |  |
| SBW_neutrality_Documentary Silver | PASS |  |
| SBW_tone_HDR_Neutral Silver | PASS |  |
| SBW_tone_HDR_Fine Grain Response | PASS |  |
| SBW_tone_HDR_Portrait Silver | PASS |  |
| SBW_tone_HDR_Classic Panchromatic | PASS |  |
| SBW_tone_HDR_High Contrast Film | PASS |  |
| SBW_tone_HDR_Soft Orthochromatic | PASS |  |
| SBW_tone_HDR_Documentary Silver | PASS |  |
| SBW_extended_color_HDR | PASS |  |
| SBW_uniform_no_grain_and_alpha | PASS |  |
| SBW_structure_0 | PASS |  |
| SBW_structure_25 | PASS |  |
| SBW_structure_50 | PASS |  |
| SBW_structure_75 | PASS |  |
| SBW_structure_100 | PASS |  |
| SBW_contrast_vs_soft_contrast | PASS |  |
| SBW_standard_masks | PASS |  |
| SBW_standard_preset_history_persistence | PASS |  |
| SBW_stack_grain | PASS |  |
| SBW_stack_tonal_contrast | PASS |  |
| SBW_stack_detail_extractor | PASS |  |
| SBW_stack_glamour_glow | PASS |  |
| SBW_stack_film_emulation | PASS |  |
| SBW_stack_cross_processing | PASS |  |
| SBW_standard_preview_HQ_export_cache | PASS |  |
| SBW_standard_resolution_performance_memory | PASS |  |
| SBW_photo_01_portrait_light_skin | PASS |  |
| SBW_photo_02_portrait_dark_skin | PASS |  |
| SBW_photo_03_landscape_clouds | PASS |  |
| SBW_photo_04_backlight | PASS |  |
| SBW_photo_05_night | PASS |  |
| SBW_photo_06_indoor_high_contrast | PASS |  |
| SBW_photo_07_white_subject | PASS |  |
| SBW_photo_08_fine_texture | PASS |  |
| SBW_preset_diversity | PASS |  |

## Exécution finale et inspection

- Build iOS Simulator Debug : **réussi** (`xcodebuild`, signature désactivée).
- Compilation LumoraVisualTestLab et smoke test Metal Silver : **réussis**.
- Cœur partagé : **97 tests réussis**.
- Silver B&W : **47 cas PASS, 0 WARN, 0 FAIL ; 1 406 contrôles PASS**, dont tous les hard invariants. Exécution complète unique, environ 302 s.
- Protocoles communs : **3 tests réussis** — `visualCreativeValidation`, `chartCoordinatesAndMeasurementsAreIndependent`, `fftAndCorrelationRecoverKnownSine`. Le rapport QUICK contient 58 cas PASS, 9 WARN et 0 FAIL. Les 9 cas WARN concernent High Key (5 cas : clipping SDR supplémentaire), Low Key (2 cas : comparaison historique de réponse relative entre spéculaires et ombres), et Grain (2 cas : taille/fréquence et résolution 512/1024). Ces effets ne sont pas modifiés ; aucun hard invariant n'échoue. Le banc signale aussi en notes l'absence de Golden Masters revus, attendue ici. Détail dans le [rapport commun](Quick/CreativeFXValidationReport.md).
- Sources et seuils gelés avant le banc, empreintes SHA256 vérifiées après : [manifeste](SilverBW/validation_source_manifest.json). Aucun ajustement de moteur, réponse, filtre, preset, Structure ou seuil après exécution.
- Les corps des renderers existants et les presets Film Emulation, dont Dense Slide approuvé, sont identiques au commit parent ; seules l'entrée de registre et les branches Silver sont ajoutées.
- `git diff --check` : réussi. Aucun Golden Master créé.

### Lecture visuelle technique

Les planches du portrait clair, du portrait sombre, des filtres sur paysage, du sujet blanc, de la mire colorée et de la matrice de diversité ont été ouvertes. Les carnations gardent des nuances ; la peau sombre ne devient pas une masse uniforme. Les boucles et le tissu restent visibles. Soft Portrait donne une séparation douce ; Soft Silver est plus réservé ; les looks documentaires rendent les contrastes plus marqués. Cette lecture ne constitue pas l'approbation esthétique finale.

Sur le sujet blanc, la ROI de ciel passe de Y=0.34044 sans filtre à 0.25359 avec Orange et 0.27022 avec Rouge (force 50). La robe reste proche : 0.62498 sans filtre, 0.62894 avec Orange et 0.63109 avec Rouge. Les textures du mur et de la robe restent visibles sur les crops. L'intensité exacte de l'effet dépend de la couleur source ; Orange peut assombrir ce ciel plus que Rouge, sans ordre artificiellement forcé entre filtres.

Les couleurs rouges/vertes/bleues de la mire ont toutes Y=0.05 en entrée. Neutral Silver sans filtre produit respectivement Y=0.05977 / 0.04685 / 0.03652 : la réponse est bien spectrale, et non une simple égalisation à la luminance.

La distance minimale entre les huit presets vaut **0.036623 sur la mire** et **0.012747 sur les huit photos**. Aucun couple n'atteint le seuil de proximité 0.004. Aucune métrique n'a été maximisée par itération.

La neutralité float mesurée est exacte (maxChannelDifference=0) ; après conversion/encodage PNG Display P3, l'écart maximal mesuré vaut 0.000463, sous la tolérance de sortie 0.001. Les performances et la RSS ont été mesurées sur Apple M2 Pro ; elles ne constituent pas un profil de performances sur iPhone. Le contenu photographique complet reste dans `Validation/TestArtifacts/SilverBW/RealPhotos` ; le commit suit la pratique du projet en conservant le rapport, les données du banc et les figures synthétiques, sans les rendus photographiques volumineux.

## Artefacts prioritaires

- [SilverBW/film_response_color_chart.png](SilverBW/film_response_color_chart.png)
- [SilverBW/red_filter_response.png](SilverBW/red_filter_response.png)
- [SilverBW/skin_filter_matrix.png](SilverBW/skin_filter_matrix.png)
- [SilverBW/RealPhotos/01_portrait_light_skin/portrait_silver_comparison.png](SilverBW/RealPhotos/01_portrait_light_skin/portrait_silver_comparison.png)
- [SilverBW/RealPhotos/02_portrait_dark_skin/portrait_silver_comparison.png](SilverBW/RealPhotos/02_portrait_dark_skin/portrait_silver_comparison.png)
- [SilverBW/RealPhotos/03_landscape_clouds/landscape_silver_comparison.png](SilverBW/RealPhotos/03_landscape_clouds/landscape_silver_comparison.png)
- [SilverBW/RealPhotos/07_white_subject/red_filter_comparison.png](SilverBW/RealPhotos/07_white_subject/red_filter_comparison.png)

Compléments : [Structure photographique](SilverBW/structure_comparison.png), [Contraste doux](SilverBW/contrast_vs_soft_contrast.png), [Blacks/Whites](SilverBW/blacks_whites_response.png), [Hue continu](SilverBW/filter_hue_response.png), [courbes](SilverBW/characteristic_curves.png).
