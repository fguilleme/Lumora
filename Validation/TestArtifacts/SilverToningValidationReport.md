# Silver Toning — validation

**Synthèse Silver Toning : 33 cas automatiques PASS, 1 cas d’inspection photographique WARN, 0 FAIL.** Le banc automatisé contient 1 201 contrôles PASS (1 129 hard invariants et 72 quality heuristics). Le WARN visuel séparé ne modifie pas les résultats originaux du banc. Mesures techniques et inspection photographique sont distinctes. Aucun réglage corrigé automatiquement après mesure ; aucun Golden Master créé. GPU : Apple M2 Pro. OS : Version 26.6.2 (Build 25G83).

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
| Neutral | 0.0 / 0.0 | 0.0 / 0.0 | 1.0 |
| Selenium | 285.0 / 255.0 | 0.2 / 0.008 | 1.8 |
| Sepia | 28.0 / 48.0 | 0.48 / 0.09 | 0.65 |
| Copper | 9.0 / 33.0 | 0.55 / 0.035 | 1.15 |
| Gold | 235.0 / 265.0 | 0.32 / 0.055 | 0.95 |
| Platinum | 38.0 / 50.0 | 0.065 / 0.018 | 0.55 |
| Cool Silver | 195.0 / 215.0 | 0.2 / 0.025 | 1.4 |
| Warm Silver | 40.0 / 52.0 | 0.18 / 0.035 | 0.85 |
| Split Silver | 220.0 / 40.0 | 0.38 / 0.26 | 1.0 |

Selenium : violet froid concentré dans les densités, faible coloration des blancs. Sepia : brun chaud plus étendu ; Copper : plus rouge et plus concentré. Gold : bleu avec une inflexion violette claire ; Cool Silver : cyan/bleu. Platinum : faible chroma étendue. Warm Silver : gris chaud. Split Silver expose deux teintes continues avec intensités séparées et la même transition de densité, sans seuil à Y=0.5. Le preset Split Warm/Cool utilise des ombres froides et lumières chaudes.

Presets :Neutral Print, Subtle Selenium, Deep Selenium, Classic Sepia, Soft Sepia, Copper Print, Cool Gold, Platinum Print, Warm Silver, Cool Silver, Split Warm/Cool.

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
### ST_Neutral — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.0099999998 |
| HDR-Y0.05 | 0.050000001 |
| HDR-Y0.18 | 0.18000001 |
| HDR-Y0.5 | 0.5 |
| HDR-Y1.0 | 1 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 3 |
| HDR-Y4.0 | 4 |
| HDR-Y6.0 | 6 |
| HDR-Y8.0 | 8 |
| P95AbsDeltaY | 0 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0 |
| highlightChroma | 0 |
| lowerMidtoneChroma | 0 |
| maxAbsDeltaY | 0 |
| maxAdjacentRatioStep | 4.4408921e-16 |
| maxHueStepRadians | 0 |
| meanAbsDeltaY | 0 |
| ratioRange | 4.4408921e-16 |
| shadowChroma | 0 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | 0 |
| strength25-meanDeltaY | 0 |
| strength50-meanDeltaY | 0 |
| strength75-meanDeltaY | 0 |
| upperMidtoneChroma | 0 |

### ST_Selenium — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.0099999998 |
| HDR-Y0.05 | 0.050000002 |
| HDR-Y0.18 | 0.18 |
| HDR-Y0.5 | 0.5 |
| HDR-Y1.0 | 0.99999999 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 3.0000001 |
| HDR-Y4.0 | 3.9999999 |
| HDR-Y6.0 | 5.9999998 |
| HDR-Y8.0 | 8 |
| P95AbsDeltaY | 2.0229816e-08 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0.0028997596 |
| highlightChroma | 0.038331815 |
| lowerMidtoneChroma | 0.15978898 |
| maxAbsDeltaY | 3.6597252e-08 |
| maxAdjacentRatioStep | 0.002771625 |
| maxHueStepRadians | 7.9174207e-05 |
| meanAbsDeltaY | 7.4476654e-09 |
| ratioRange | 0.10838258 |
| shadowChroma | 0.27647983 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | 5.0267106e-10 |
| strength25-meanDeltaY | 2.0866692e-10 |
| strength50-meanDeltaY | 9.3915401e-11 |
| strength75-meanDeltaY | 3.4250863e-10 |
| upperMidtoneChroma | 0.063859533 |

### ST_Sepia — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.01 |
| HDR-Y0.05 | 0.050000001 |
| HDR-Y0.18 | 0.18000001 |
| HDR-Y0.5 | 0.49999999 |
| HDR-Y1.0 | 1 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 3.0000001 |
| HDR-Y4.0 | 4 |
| HDR-Y6.0 | 5.9999999 |
| HDR-Y8.0 | 7.9999999 |
| P95AbsDeltaY | 2.0927191e-08 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0.0062294945 |
| highlightChroma | 0.61515216 |
| lowerMidtoneChroma | 0.88326145 |
| maxAbsDeltaY | 3.3462048e-08 |
| maxAdjacentRatioStep | 0.0049604813 |
| maxHueStepRadians | 4.0106376e-05 |
| meanAbsDeltaY | 7.44541e-09 |
| ratioRange | 0.2760262 |
| shadowChroma | 0.88512162 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | 3.5048454e-10 |
| strength25-meanDeltaY | -5.2167261e-11 |
| strength50-meanDeltaY | 5.1654103e-10 |
| strength75-meanDeltaY | 1.385703e-10 |
| upperMidtoneChroma | 0.71716359 |

### ST_Copper — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.01 |
| HDR-Y0.05 | 0.050000001 |
| HDR-Y0.18 | 0.18 |
| HDR-Y0.5 | 0.49999999 |
| HDR-Y1.0 | 0.99999999 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 3 |
| HDR-Y4.0 | 4 |
| HDR-Y6.0 | 6.0000001 |
| HDR-Y8.0 | 7.9999998 |
| P95AbsDeltaY | 2.0873547e-08 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0.0082742013 |
| highlightChroma | 0.27235664 |
| lowerMidtoneChroma | 0.69086564 |
| maxAbsDeltaY | 3.2007694e-08 |
| maxAdjacentRatioStep | 0.0064207757 |
| maxHueStepRadians | 3.3678459e-05 |
| meanAbsDeltaY | 7.2965666e-09 |
| ratioRange | 0.29390015 |
| shadowChroma | 0.89215617 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | -4.9677989e-11 |
| strength25-meanDeltaY | -6.5721754e-12 |
| strength50-meanDeltaY | 7.9831319e-11 |
| strength75-meanDeltaY | -8.4675489e-11 |
| upperMidtoneChroma | 0.39460731 |

### ST_Gold — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.0099999997 |
| HDR-Y0.05 | 0.049999999 |
| HDR-Y0.18 | 0.18000001 |
| HDR-Y0.5 | 0.50000001 |
| HDR-Y1.0 | 0.99999998 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 3 |
| HDR-Y4.0 | 4.0000001 |
| HDR-Y6.0 | 6.0000001 |
| HDR-Y8.0 | 8 |
| P95AbsDeltaY | 2.0027161e-08 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0.0039637004 |
| highlightChroma | 0.27407066 |
| lowerMidtoneChroma | 0.47976185 |
| maxAbsDeltaY | 3.4880638e-08 |
| maxAdjacentRatioStep | 0.0046785251 |
| maxHueStepRadians | 7.3097647e-05 |
| meanAbsDeltaY | 7.2094415e-09 |
| ratioRange | 0.23054928 |
| shadowChroma | 0.54790029 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | 8.5585525e-11 |
| strength25-meanDeltaY | -7.896731e-11 |
| strength50-meanDeltaY | 2.6483406e-10 |
| strength75-meanDeltaY | 2.0281117e-10 |
| upperMidtoneChroma | 0.33818069 |

### ST_Platinum — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.0099999997 |
| HDR-Y0.05 | 0.050000001 |
| HDR-Y0.18 | 0.18000001 |
| HDR-Y0.5 | 0.49999999 |
| HDR-Y1.0 | 1 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 2.9999999 |
| HDR-Y4.0 | 4 |
| HDR-Y6.0 | 5.9999998 |
| HDR-Y8.0 | 8.0000003 |
| P95AbsDeltaY | 2.0682812e-08 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0.00059991527 |
| highlightChroma | 0.10736112 |
| lowerMidtoneChroma | 0.13177963 |
| maxAbsDeltaY | 2.8455257e-08 |
| maxAdjacentRatioStep | 0.00079845582 |
| maxHueStepRadians | 5.0245156e-05 |
| meanAbsDeltaY | 7.2798159e-09 |
| ratioRange | 0.047243883 |
| shadowChroma | 0.12341517 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | 1.3781726e-10 |
| strength25-meanDeltaY | -2.314164e-11 |
| strength50-meanDeltaY | 4.6486757e-10 |
| strength75-meanDeltaY | 9.1031219e-13 |
| upperMidtoneChroma | 0.11787332 |

### ST_Cool Silver — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.0099999997 |
| HDR-Y0.05 | 0.050000002 |
| HDR-Y0.18 | 0.18 |
| HDR-Y0.5 | 0.49999998 |
| HDR-Y1.0 | 1 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 3 |
| HDR-Y4.0 | 4.0000001 |
| HDR-Y6.0 | 6 |
| HDR-Y8.0 | 8.0000003 |
| P95AbsDeltaY | 2.0587444e-08 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0.0023127278 |
| highlightChroma | 0.097231848 |
| lowerMidtoneChroma | 0.22056809 |
| maxAbsDeltaY | 4.3046474e-08 |
| maxAdjacentRatioStep | 0.0021492479 |
| maxHueStepRadians | 6.3884479e-05 |
| meanAbsDeltaY | 7.4619592e-09 |
| ratioRange | 0.092370633 |
| shadowChroma | 0.3064607 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | 7.3708939e-11 |
| strength25-meanDeltaY | 3.0949263e-11 |
| strength50-meanDeltaY | 7.2005353e-11 |
| strength75-meanDeltaY | -7.5850378e-11 |
| upperMidtoneChroma | 0.12709627 |

### ST_Warm Silver — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.0099999998 |
| HDR-Y0.05 | 0.050000001 |
| HDR-Y0.18 | 0.18 |
| HDR-Y0.5 | 0.50000001 |
| HDR-Y1.0 | 0.99999998 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 3 |
| HDR-Y4.0 | 4 |
| HDR-Y6.0 | 6.0000001 |
| HDR-Y8.0 | 8.0000002 |
| P95AbsDeltaY | 2.0372868e-08 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0.00219792 |
| highlightChroma | 0.18556497 |
| lowerMidtoneChroma | 0.29278329 |
| maxAbsDeltaY | 3.2413006e-08 |
| maxAdjacentRatioStep | 0.0022645782 |
| maxHueStepRadians | 3.0581893e-05 |
| meanAbsDeltaY | 7.428102e-09 |
| ratioRange | 0.11596485 |
| shadowChroma | 0.31649545 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | -2.7297393e-11 |
| strength25-meanDeltaY | -3.6203843e-11 |
| strength50-meanDeltaY | 2.4477239e-11 |
| strength75-meanDeltaY | -2.6976855e-10 |
| upperMidtoneChroma | 0.22146816 |

### ST_Split Silver — PASS

| Mesure | Valeur |
|---|---:|
| Amount zero-maxRGBError | 0 |
| Amount zero-maxYError | 0 |
| Amount zero-meanRGBError | 0 |
| Amount zero-nonFinitePixels | 0 |
| HDR-Y-0.001 | -0.001 |
| HDR-Y-0.01 | -0.0099999998 |
| HDR-Y-0.05 | -0.050000001 |
| HDR-Y0.0 | 0 |
| HDR-Y0.01 | 0.0099999995 |
| HDR-Y0.05 | 0.050000001 |
| HDR-Y0.18 | 0.18 |
| HDR-Y0.5 | 0.5 |
| HDR-Y1.0 | 1 |
| HDR-Y1.5 | 1.5 |
| HDR-Y2.0 | 2 |
| HDR-Y3.0 | 2.9999999 |
| HDR-Y4.0 | 4 |
| HDR-Y6.0 | 6 |
| HDR-Y8.0 | 7.9999998 |
| P95AbsDeltaY | 2.0968914e-08 |
| Strength zero-maxRGBError | 0 |
| Strength zero-maxYError | 0 |
| Strength zero-meanRGBError | 0 |
| Strength zero-nonFinitePixels | 0 |
| bestOverlayResidualMAE | 0.013461694 |
| highlightChroma | 0.34397609 |
| lowerMidtoneChroma | 0.33755171 |
| maxAbsDeltaY | 3.2758713e-08 |
| maxAdjacentRatioStep | 0.0047713187 |
| maxHueStepRadians | 7.1662608e-05 |
| meanAbsDeltaY | 7.3587468e-09 |
| ratioRange | 0.38231677 |
| shadowChroma | 0.61095036 |
| strength0-meanDeltaY | 0 |
| strength100-meanDeltaY | -1.0314855e-09 |
| strength25-meanDeltaY | -3.0770199e-10 |
| strength50-meanDeltaY | -4.3124304e-10 |
| strength75-meanDeltaY | -7.9638765e-10 |
| upperMidtoneChroma | 0.11522998 |

### ST_control_isolation — PASS

| Mesure | Valeur |
|---|---:|
| balance-100.0-transitionY | 0.096703297 |
| balance-25.0-transitionY | 0.27350427 |
| balance-50.0-transitionY | 0.19340659 |
| balance-75.0-transitionY | 0.13675214 |
| balance0.0-transitionY | 0.38583639 |
| balance100.0-transitionY | 1.5433455 |
| balance25.0-transitionY | 0.54603175 |
| balance50.0-transitionY | 0.77167277 |
| balance75.0-transitionY | 1.0920635 |
| paper-0.0-maxError | 0 |
| paper-0.01-maxError | 0 |
| paper-0.05-maxError | 1.2889504e-06 |
| paper-0.18-maxError | 0.00031854212 |
| paper-0.5-maxError | 0.0085074604 |
| paper-0.9-maxError | 0.03496927 |
| paper-1.0-maxError | 0.043623865 |
| paper-2.0-maxError | 0.15353823 |
| paper-4.0-maxError | 0.42056823 |
| paper-8.0-maxError | 0.99375439 |
| spatialLuminanceResidualRMS | 7.4011953e-09 |
| spatialResidualHighFrequency | 0.76445632 |

### ST_extended_controls_alpha — PASS

| Mesure | Valeur |
|---|---:|
| Cool Silver-HDR-maxRatioStep | 6.3602347e-05 |
| Copper-HDR-maxRatioStep | 7.9998265e-05 |
| Gold-HDR-maxRatioStep | 0.0001191499 |
| Neutral-HDR-maxRatioStep | 4.4408921e-16 |
| Platinum-HDR-maxRatioStep | 4.4834995e-05 |
| Selenium-HDR-maxRatioStep | 7.2619083e-05 |
| Sepia-HDR-maxRatioStep | 6.5251278e-05 |
| Split Silver-HDR-maxRatioStep | 0.00026577092 |
| Warm Silver-HDR-maxRatioStep | 2.4267495e-05 |
| highlight-hueDegrees | 40.000006 |
| midtone-hueDegrees | -140.00003 |
| shadow-hueDegrees | -140.00001 |

### ST_standard_masks — PASS

| Mesure | Valeur |
|---|---:|
| inverted-outsideMaskMaxError | 0 |
| inverted-outsideMaskMeanError | 0 |
| simple-outsideMaskMaxError | 0 |
| simple-outsideMaskMeanError | 0 |
| stacked-outsideMaskMaxError | 0 |
| stacked-outsideMaskMeanError | 0 |
| subtractive-outsideMaskMaxError | 0 |
| subtractive-outsideMaskMeanError | 0 |

### ST_standard_preset_history_persistence — PASS

| Mesure | Valeur |
|---|---:|

### ST_stack_silver_bw — PASS

| Mesure | Valeur |
|---|---:|
| nonFinite | 0 |
| orderMAE | 0.055447593 |
| toningLastChannelError | 1.9771948 |

### ST_stack_film_grain — PASS

| Mesure | Valeur |
|---|---:|
| nonFinite | 0 |
| orderMAE | 0.00011755922 |
| toningLastChannelError | 1.814889 |

### ST_stack_glamour_glow — PASS

| Mesure | Valeur |
|---|---:|
| nonFinite | 0 |
| orderMAE | 0.0060029042 |
| toningLastChannelError | 1.814889 |

### ST_stack_film_emulation — PASS

| Mesure | Valeur |
|---|---:|
| nonFinite | 0 |
| orderMAE | 0.0038626882 |
| toningLastChannelError | 2.3827262 |

### ST_stack_cross_processing — PASS

| Mesure | Valeur |
|---|---:|
| nonFinite | 0 |
| orderMAE | 0.0034739259 |
| toningLastChannelError | 0.51352501 |

### ST_multi_step_history — PASS

| Mesure | Valeur |
|---|---:|

### ST_soft_mask_edge — PASS

| Mesure | Valeur |
|---|---:|
| luminanceResidualRMS | 2.7396885e-09 |

### ST_pipeline_Subtle Selenium — PASS

| Mesure | Valeur |
|---|---:|
| HQ-exportMAE | 3.6865789e-05 |
| HQ-exportMaxError | 0.00018405914 |
| HQ-exportRMSE | 5.7551642e-05 |
| HQ-milliseconds | 86.521708 |
| HQ-width | 2048 |
| interactive-exportMAE | 0.0003336683 |
| interactive-exportMaxError | 0.024310052 |
| interactive-exportRMSE | 0.001158302 |
| interactive-milliseconds | 92.120542 |
| interactive-width | 960 |

### ST_pipeline_Classic Sepia — PASS

| Mesure | Valeur |
|---|---:|
| HQ-exportMAE | 5.5192142e-05 |
| HQ-exportMaxError | 0.00019347668 |
| HQ-exportRMSE | 7.0608777e-05 |
| HQ-milliseconds | 75.76575 |
| HQ-width | 2048 |
| interactive-exportMAE | 0.00033173376 |
| interactive-exportMaxError | 0.024379671 |
| interactive-exportRMSE | 0.001109343 |
| interactive-milliseconds | 52.527084 |
| interactive-width | 960 |

### ST_pipeline_Split Warm/Cool — PASS

| Mesure | Valeur |
|---|---:|
| HQ-exportMAE | 3.7309444e-05 |
| HQ-exportMaxError | 0.00017905235 |
| HQ-exportRMSE | 5.2312615e-05 |
| HQ-milliseconds | 86.893167 |
| HQ-width | 2048 |
| interactive-exportMAE | 0.00032554366 |
| interactive-exportMaxError | 0.024309993 |
| interactive-exportRMSE | 0.0011227845 |
| interactive-milliseconds | 115.19267 |
| interactive-width | 960 |

### ST_performance_resolution_memory — PASS

| Mesure | Valeur |
|---|---:|
| 1024-CPU-graph-medianMS | 0.03825 |
| 1024-GPU-medianMS | 0.1042916 |
| 1024-wall-medianMS | 0.57720835 |
| 2048-CPU-graph-medianMS | 0.042125001 |
| 2048-GPU-medianMS | 0.37066673 |
| 2048-wall-medianMS | 0.89575001 |
| 4096-CPU-graph-medianMS | 0.047749956 |
| 4096-GPU-medianMS | 1.4247084 |
| 4096-wall-medianMS | 2.0214583 |
| RSS-batch0 | 1.5171584e+08 |
| RSS-batch1 | 1.5173222e+08 |
| RSS-batch2 | 1.5173222e+08 |
| RSS-batch3 | 1.5173222e+08 |

### ST_photo_01_portrait_light_skin — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

### ST_photo_02_portrait_dark_skin — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

### ST_photo_03_landscape_clouds — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

### ST_photo_04_backlight — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

### ST_photo_05_night — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

### ST_photo_06_indoor_high_contrast — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

### ST_photo_07_white_subject — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

### ST_photo_08_fine_texture — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

### ST_preset_diversity — PASS

Mesures détaillées dans [checks.json](SilverToning/checks.json).

## Artefacts prioritaires

- [SilverToning/reference_triptych.png](SilverToning/reference_triptych.png)
- [SilverToning/not_an_overlay.png](SilverToning/not_an_overlay.png)
- [SilverToning/all_density_responses.png](SilverToning/all_density_responses.png)
- [SilverToning/RealPhotos/01_portrait_light_skin/portrait_light_toning_comparison.png](SilverToning/RealPhotos/01_portrait_light_skin/portrait_light_toning_comparison.png)
- [SilverToning/RealPhotos/02_portrait_dark_skin/portrait_dark_toning_comparison.png](SilverToning/RealPhotos/02_portrait_dark_skin/portrait_dark_toning_comparison.png)
- [SilverToning/RealPhotos/05_night/night_toning_comparison.png](SilverToning/RealPhotos/05_night/night_toning_comparison.png)
- [SilverToning/RealPhotos/07_white_subject/paper_tone_white_subject.png](SilverToning/RealPhotos/07_white_subject/paper_tone_white_subject.png)

## Arrêt

Paramètres et seuils figés avant exécution. Tout WARN/FAIL est à documenter puis inspecter, sans correction automatique. Aucun Golden Master. Commit autorisé uniquement si les builds passent et aucun FAIL/hard invariant n'échoue (fin de spécification reçue pendant le banc). Les artefacts photographiques restent dans TestArtifacts selon la convention locale.

## Tableaux descriptifs complémentaires (sections 117–118)

Mesures ajoutées à la demande reçue pendant le premier banc ; aucun renderer, paramètre ni seuil modifié. Y et RGB sont lus en RGBAf extended linear sRGB avant export. Chroma relative = hypot(2R−G−B, √3(G−B))/Y pour Y>10⁻⁶, sinon 0. Teinte = atan2 de cet opposant en degrés. Ce ne sont pas des unités CIELAB ni des ΔE. Les zones sont définies sur l'entrée : shadows Y<0.1, midtones 0.1≤Y<0.7, highlights Y≥0.7. Une zone absente affiche une moyenne 0. La fraction clipped signale les pixels avec un canal RGB hors [0,1) susceptibles d'écrêtage à la sortie SDR ; le moteur n'écrête pas ces valeurs.

### Toners, Strength=100

Zone = luminance où la chroma relative atteint son maximum, sur rampe 0→1. Les courbes complètes donnent l'étendue réelle de la réponse ; Neutral n'a pas de hue défini. Distance = MAE RGB linéaire.

| Toner / preset | Zone du maximum (Y) | Hue au maximum | Chroma max | meanAbsΔY | maxAbsΔY | Distance Neutral | Plus proche | Distance |
|---|---|---:|---:|---:|---:|---:|---|---:|
| Neutral | shadow (0) | undefined | 0 | 0 | 0 | 0 | Selenium | 0.00810589 |
| Selenium | shadow (0.0407814) | -75.0564 | 0.279215 | 7.44767e-09 | 3.65973e-08 | 0.00810589 | Neutral | 0.00810589 |
| Sepia | shadow (0.0913309) | 28.5298 | 0.928346 | 7.44541e-09 | 3.3462e-08 | 0.0693173 | Copper | 0.0339098 |
| Copper | shadow (0.0556777) | 9.11235 | 0.894355 | 7.29657e-09 | 3.20077e-08 | 0.037956 | Warm Silver | 0.0215305 |
| Gold | shadow (0.0664225) | -124.525 | 0.555481 | 7.20944e-09 | 3.48806e-08 | 0.0284837 | Selenium | 0.0247896 |
| Platinum | lower midtone (0.120391) | 38.6639 | 0.133456 | 7.27982e-09 | 2.84553e-08 | 0.0109652 | Warm Silver | 0.00896645 |
| Cool Silver | shadow (0.0495727) | -164.841 | 0.306463 | 7.46196e-09 | 4.30465e-08 | 0.0126887 | Selenium | 0.0122638 |
| Warm Silver | shadow (0.0739927) | 40.2579 | 0.324092 | 7.4281e-09 | 3.2413e-08 | 0.0198601 | Platinum | 0.00896645 |
| Split Silver | shadow (0.0490842) | -140 | 0.610976 | 7.35875e-09 | 3.27587e-08 | 0.0242287 | Warm Silver | 0.0165466 |

### Presets, paramètres inchangés

Zone = luminance où la chroma relative atteint son maximum, sur rampe 0→1. Les courbes complètes donnent l'étendue réelle de la réponse ; Neutral n'a pas de hue défini. Distance = MAE RGB linéaire.

| Toner / preset | Zone du maximum (Y) | Hue au maximum | Chroma max | meanAbsΔY | maxAbsΔY | Distance Neutral | Plus proche | Distance |
|---|---|---:|---:|---:|---:|---:|---|---:|
| Neutral Print | shadow (0) | undefined | 0 | 0 | 0 | 0 | Subtle Selenium | 0.00226965 |
| Subtle Selenium | shadow (0.0407814) | -75.0564 | 0.0781801 | 7.28278e-09 | 2.87175e-08 | 0.00226965 | Neutral Print | 0.00226965 |
| Deep Selenium | shadow (0.0473748) | -75.0439 | 0.274057 | 7.40183e-09 | 2.92897e-08 | 0.00946017 | Subtle Selenium | 0.00719052 |
| Classic Sepia | shadow (0.0918193) | 28.5379 | 0.696417 | 7.3647e-09 | 3.32594e-08 | 0.053789 | Copper Print | 0.0246337 |
| Soft Sepia | lower midtone (0.10232) | 28.4154 | 0.311611 | 7.26439e-09 | 3.30567e-08 | 0.0245515 | Warm Silver | 0.010862 |
| Copper Print | shadow (0.0598291) | 9.10019 | 0.722944 | 7.35889e-09 | 3.31521e-08 | 0.03284 | Soft Sepia | 0.0140748 |
| Cool Gold | shadow (0.0664225) | -124.526 | 0.444405 | 7.36139e-09 | 2.8491e-08 | 0.0231465 | Deep Selenium | 0.0197941 |
| Platinum Print | lower midtone (0.121856) | 38.6799 | 0.0601034 | 7.28858e-09 | 2.91705e-08 | 0.00515046 | Neutral Print | 0.00515046 |
| Warm Silver | shadow (0.0742369) | 40.26 | 0.210694 | 7.35364e-09 | 2.89202e-08 | 0.0136895 | Platinum Print | 0.00854534 |
| Cool Silver | shadow (0.0495727) | -164.84 | 0.199204 | 7.49513e-09 | 4.08173e-08 | 0.0085839 | Subtle Selenium | 0.00831869 |
| Split Warm/Cool | shadow (0.0490842) | -140 | 0.397129 | 7.57189e-09 | 3.38674e-08 | 0.0163011 | Warm Silver | 0.0106353 |

### 01_portrait_light_skin

Cadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.

| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Neutral Print | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0 | 0 | 0 | 0 | 0.0161978 | 0 |
| Subtle Selenium | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.0357106 | 0.0730039 | 0.0339 | 0.0109368 | 0.0179504 | 0 |
| Deep Selenium | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.139575 | 0.257376 | 0.137904 | 0.0444205 | 0.0234318 | 0 |
| Classic Sepia | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.598461 | 0.620412 | 0.619622 | 0.491113 | 0.0750493 | 0 |
| Soft Sepia | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.270977 | 0.273143 | 0.282331 | 0.22171 | 0.039767 | 0 |
| Copper Print | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.472201 | 0.673602 | 0.485279 | 0.243016 | 0.055896 | 0 |
| Cool Gold | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.332811 | 0.410303 | 0.341258 | 0.230374 | 0.0759428 | 0 |
| Platinum Print | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.0557934 | 0.0519962 | 0.0575387 | 0.0518011 | 0.0191933 | 0 |
| Warm Silver | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.170213 | 0.192255 | 0.174452 | 0.133411 | 0.0238098 | 0 |
| Cool Silver | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.121005 | 0.186862 | 0.119897 | 0.068536 | 0.0243196 | 0 |
| Split Warm/Cool | 0.355588 | 0.0344244 | 0.27541 | 0.936655 | 0.184872 | 0.37714 | 0.134593 | 0.228039 | 0.0367256 | 0 |

### 02_portrait_dark_skin

Cadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.

| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Neutral Print | 0.160174 | 0.00202088 | 0.0423183 | 0.749234 | 0 | 0 | 0 | 0 | 0.0183628 | 0 |
| Subtle Selenium | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.0472584 | 0.0573606 | 0.034947 | 0.0111055 | 0.0193136 | 0 |
| Deep Selenium | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.169071 | 0.196112 | 0.141014 | 0.0451987 | 0.0217135 | 0 |
| Classic Sepia | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.498316 | 0.433626 | 0.620011 | 0.49263 | 0.0330485 | 0 |
| Soft Sepia | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.221948 | 0.189627 | 0.282138 | 0.222489 | 0.0252589 | 0 |
| Copper Print | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.47688 | 0.492472 | 0.489604 | 0.245503 | 0.0291365 | 0 |
| Cool Gold | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.30717 | 0.295218 | 0.343137 | 0.231505 | 0.0332318 | 0 |
| Platinum Print | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.0441166 | 0.0361965 | 0.0574891 | 0.0518709 | 0.0200066 | 0 |
| Warm Silver | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.148952 | 0.136392 | 0.175116 | 0.133811 | 0.021702 | 0 |
| Cool Silver | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.130058 | 0.140403 | 0.121808 | 0.0689282 | 0.0219139 | 0 |
| Split Warm/Cool | 0.160174 | 0.00202088 | 0.0423183 | 0.749233 | 0.242132 | 0.294693 | 0.147334 | 0.224167 | 0.0249439 | 0 |

### 03_landscape_clouds

Cadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.

| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Neutral Print | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0 | 0 | 0 | 0 | 0.0329319 | 0 |
| Subtle Selenium | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.047174 | 0.0689476 | 0.0385011 | 0.0111024 | 0.0337321 | 0 |
| Deep Selenium | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.175161 | 0.238549 | 0.15343 | 0.045174 | 0.0362278 | 0 |
| Classic Sepia | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.605604 | 0.592686 | 0.62971 | 0.492398 | 0.0506185 | 0 |
| Soft Sepia | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.272917 | 0.263626 | 0.28591 | 0.222342 | 0.0409682 | 0 |
| Copper Print | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.531684 | 0.622827 | 0.514455 | 0.24526 | 0.0461561 | 0 |
| Cool Gold | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.354471 | 0.381981 | 0.354431 | 0.231393 | 0.0508152 | 0 |
| Platinum Print | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.0549147 | 0.0509921 | 0.0578229 | 0.05186 | 0.0343764 | 0 |
| Warm Silver | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.175878 | 0.179796 | 0.179331 | 0.13379 | 0.0361871 | 0 |
| Cool Silver | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.13968 | 0.172243 | 0.129075 | 0.0689345 | 0.0366007 | 0 |
| Split Warm/Cool | 0.231224 | 0.00558447 | 0.145513 | 0.820789 | 0.252844 | 0.377999 | 0.177742 | 0.224764 | 0.0408868 | 0 |

### 04_backlight

Cadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.

| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Neutral Print | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0 | 0 | 0 | 0 | 0.0867165 | 0 |
| Subtle Selenium | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0.0456206 | 0.0638421 | 0.0263491 | 0.0103903 | 0.0880338 | 0 |
| Deep Selenium | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0.158499 | 0.213053 | 0.107979 | 0.0417348 | 0.0916422 | 0 |
| Classic Sepia | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0.48495 | 0.442053 | 0.58348 | 0.484304 | 0.113024 | 0 |
| Soft Sepia | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0.216139 | 0.193788 | 0.266084 | 0.217995 | 0.0993173 | 0 |
| Copper Print | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0.441331 | 0.511587 | 0.413127 | 0.233011 | 0.106334 | 0 |
| Cool Gold | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0.290717 | 0.301179 | 0.308072 | 0.225806 | 0.113276 | 0 |
| Platinum Print | 0.270942 | 0.0037404 | 0.0443347 | 1.06734 | 0.0443505 | 0.0373086 | 0.0559229 | 0.0514805 | 0.0890018 | 0 |
| Warm Silver | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0.14309 | 0.137996 | 0.161843 | 0.131921 | 0.0917568 | 0 |
| Cool Silver | 0.270942 | 0.00374041 | 0.0443347 | 1.06734 | 0.124828 | 0.150354 | 0.103007 | 0.0673335 | 0.0920775 | 0 |
| Split Warm/Cool | 0.270942 | 0.0037404 | 0.0443347 | 1.06734 | 0.255411 | 0.323032 | 0.107167 | 0.245304 | 0.0984925 | 0 |

### 05_night

Cadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.

| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Neutral Print | 0.0421556 | 5.63242e-05 | 0.00796039 | 0.19073 | 0 | 0 | 0 | 0 | 0.0469564 | 0 |
| Subtle Selenium | 0.0421556 | 5.63246e-05 | 0.00796039 | 0.19073 | 0.0512333 | 0.0529111 | 0.0373534 | 0.0110203 | 0.0475464 | 0 |
| Deep Selenium | 0.0421556 | 5.63244e-05 | 0.00796039 | 0.19073 | 0.1758 | 0.179632 | 0.147994 | 0.0447814 | 0.0489366 | 0 |
| Classic Sepia | 0.0421556 | 5.63244e-05 | 0.00796039 | 0.19073 | 0.430144 | 0.411792 | 0.619579 | 0.491201 | 0.0517103 | 0 |
| Soft Sepia | 0.0421556 | 5.63246e-05 | 0.00796039 | 0.19073 | 0.189675 | 0.180792 | 0.281128 | 0.221652 | 0.0490587 | 0 |
| Copper Print | 0.0421556 | 5.63244e-05 | 0.00796039 | 0.19073 | 0.455573 | 0.453471 | 0.499019 | 0.243583 | 0.0522393 | 0 |
| Cool Gold | 0.0421556 | 5.63244e-05 | 0.00796039 | 0.19073 | 0.280337 | 0.274561 | 0.346808 | 0.230638 | 0.0518392 | 0 |
| Platinum Print | 0.0421556 | 5.63243e-05 | 0.00796039 | 0.19073 | 0.0366097 | 0.0345334 | 0.0572197 | 0.0518082 | 0.0473294 | 0 |
| Warm Silver | 0.0421556 | 5.63243e-05 | 0.00796039 | 0.19073 | 0.132176 | 0.128027 | 0.176238 | 0.133579 | 0.0478719 | 0 |
| Cool Silver | 0.0421556 | 5.63246e-05 | 0.00796039 | 0.19073 | 0.128276 | 0.129046 | 0.125981 | 0.0687876 | 0.0481025 | 0 |
| Split Warm/Cool | 0.0421556 | 5.63245e-05 | 0.00796039 | 0.19073 | 0.257027 | 0.266469 | 0.159319 | 0.228007 | 0.0503879 | 0 |

### 06_indoor_high_contrast

Cadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.

| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Neutral Print | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0 | 0 | 0 | 0 | 0.0506037 | 0 |
| Subtle Selenium | 0.0859326 | 1.15701e-06 | 0.00555916 | 0.668505 | 0.0413739 | 0.0443314 | 0.0307063 | 0.0110212 | 0.0511135 | 0 |
| Deep Selenium | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.142763 | 0.150455 | 0.123767 | 0.0448239 | 0.0526141 | 0 |
| Classic Sepia | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.358578 | 0.322576 | 0.597162 | 0.491944 | 0.070639 | 0 |
| Soft Sepia | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.157869 | 0.140663 | 0.271647 | 0.22214 | 0.0559132 | 0 |
| Copper Print | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.373853 | 0.372311 | 0.446339 | 0.244337 | 0.0637887 | 0 |
| Cool Gold | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.232575 | 0.221803 | 0.323074 | 0.230978 | 0.0711086 | 0 |
| Platinum Print | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.0307501 | 0.0265042 | 0.0564183 | 0.051841 | 0.0511192 | 0 |
| Warm Silver | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.110081 | 0.101891 | 0.167487 | 0.133627 | 0.0520929 | 0 |
| Cool Silver | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.105604 | 0.106858 | 0.11213 | 0.0687365 | 0.0523735 | 0 |
| Split Warm/Cool | 0.0859326 | 1.15702e-06 | 0.00555916 | 0.668505 | 0.221423 | 0.231967 | 0.131464 | 0.22597 | 0.0559247 | 0 |

### 07_white_subject

Cadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.

| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Neutral Print | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0 | 0 | 0 | 0 | 0.0682983 | 0 |
| Subtle Selenium | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.023779 | 0.0861665 | 0.0232153 | 0.0110533 | 0.0710517 | 0 |
| Deep Selenium | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.0951006 | 0.297045 | 0.0960873 | 0.044916 | 0.077908 | 0 |
| Classic Sepia | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.554378 | 0.607019 | 0.570172 | 0.4916 | 0.112339 | 0 |
| Soft Sepia | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.251848 | 0.266818 | 0.260124 | 0.221892 | 0.0911323 | 0 |
| Copper Print | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.371419 | 0.728863 | 0.385179 | 0.244166 | 0.102064 | 0 |
| Cool Gold | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.287569 | 0.423922 | 0.29536 | 0.230892 | 0.112942 | 0 |
| Platinum Print | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.0542818 | 0.0497448 | 0.0553812 | 0.0518221 | 0.0730455 | 0 |
| Warm Silver | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.153654 | 0.19168 | 0.157144 | 0.133636 | 0.0782878 | 0 |
| Cool Silver | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.0958534 | 0.205754 | 0.0962996 | 0.0688329 | 0.0788235 | 0 |
| Split Warm/Cool | 0.530369 | 0.0933578 | 0.551099 | 1.02481 | 0.161434 | 0.499003 | 0.116425 | 0.226786 | 0.0896267 | 0 |

### 08_fine_texture

Cadre complet réduit à 512 pixels sur le grand côté, même base Neutral Silver pour toutes les variantes. P05/P50/P95 sont des percentiles de Y.

| Preset | Mean Y | P05 | P50 | P95 | Mean chroma | Shadow chroma | Midtone chroma | Highlight chroma | Clipped fraction | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Neutral Print | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0 | 0 | 0 | 0 | 0.00712077 | 0 |
| Subtle Selenium | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.0474425 | 0.0688649 | 0.0333674 | 0.0113798 | 0.00723606 | 0 |
| Deep Selenium | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.176199 | 0.239952 | 0.135053 | 0.0464963 | 0.00759549 | 0 |
| Classic Sepia | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.593026 | 0.568262 | 0.613919 | 0.495298 | 0.00950792 | 0 |
| Soft Sepia | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.266342 | 0.249826 | 0.279523 | 0.223872 | 0.00807699 | 0 |
| Copper Print | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.531255 | 0.621522 | 0.476242 | 0.249785 | 0.0089586 | 0 |
| Cool Gold | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.35163 | 0.377594 | 0.33704 | 0.233454 | 0.00956896 | 0 |
| Platinum Print | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.0531738 | 0.047525 | 0.0572395 | 0.0519951 | 0.00729709 | 0 |
| Warm Silver | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.173606 | 0.176543 | 0.172808 | 0.134496 | 0.00751411 | 0 |
| Cool Silver | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.140115 | 0.173863 | 0.118397 | 0.0695722 | 0.00761583 | 0 |
| Split Warm/Cool | 0.209914 | 0.00810616 | 0.148873 | 0.584886 | 0.228142 | 0.351442 | 0.140604 | 0.217402 | 0.00822618 | 0 |

## Statut de chaque contrôle : hard invariant / quality heuristic

Les PASS techniques ne valident pas l'esthétique. Un WARN est conservé pour inspection ; un FAIL interdit le commit.

| Cas / contrôle | Type | État | Critère |
|---|---|---|---|
| ST_Neutral / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Neutral / Finite | hard invariant | PASS | RGBAf output |
| ST_Neutral / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Neutral / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Neutral / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Neutral / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Neutral / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Neutral / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Neutral / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Neutral / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Neutral / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Neutral / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Neutral / Deterministic | hard invariant | PASS | No random component |
| ST_Neutral / Neutral identity | hard invariant | PASS | Neutral bypasses all coloration |
| ST_Neutral / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_Selenium / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Selenium / Finite | hard invariant | PASS | RGBAf output |
| ST_Selenium / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Selenium / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Selenium / Density dependent | quality heuristic | PASS | toner behaves like constant overlay if chromaticity range <= .001 |
| ST_Selenium / Nonconstant overlay residual | quality heuristic | PASS | Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed |
| ST_Selenium / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Selenium / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Selenium / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Selenium / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Selenium / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Selenium / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Selenium / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Selenium / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Selenium / Deterministic | hard invariant | PASS | No random component |
| ST_Selenium / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_Sepia / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Sepia / Finite | hard invariant | PASS | RGBAf output |
| ST_Sepia / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Sepia / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Sepia / Density dependent | quality heuristic | PASS | toner behaves like constant overlay if chromaticity range <= .001 |
| ST_Sepia / Nonconstant overlay residual | quality heuristic | PASS | Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed |
| ST_Sepia / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Sepia / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Sepia / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Sepia / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Sepia / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Sepia / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Sepia / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Sepia / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Sepia / Deterministic | hard invariant | PASS | No random component |
| ST_Sepia / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_Copper / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Copper / Finite | hard invariant | PASS | RGBAf output |
| ST_Copper / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Copper / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Copper / Density dependent | quality heuristic | PASS | toner behaves like constant overlay if chromaticity range <= .001 |
| ST_Copper / Nonconstant overlay residual | quality heuristic | PASS | Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed |
| ST_Copper / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Copper / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Copper / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Copper / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Copper / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Copper / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Copper / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Copper / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Copper / Deterministic | hard invariant | PASS | No random component |
| ST_Copper / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_Gold / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Gold / Finite | hard invariant | PASS | RGBAf output |
| ST_Gold / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Gold / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Gold / Density dependent | quality heuristic | PASS | toner behaves like constant overlay if chromaticity range <= .001 |
| ST_Gold / Nonconstant overlay residual | quality heuristic | PASS | Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed |
| ST_Gold / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Gold / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Gold / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Gold / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Gold / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Gold / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Gold / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Gold / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Gold / Deterministic | hard invariant | PASS | No random component |
| ST_Gold / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_Platinum / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Platinum / Finite | hard invariant | PASS | RGBAf output |
| ST_Platinum / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Platinum / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Platinum / Density dependent | quality heuristic | PASS | toner behaves like constant overlay if chromaticity range <= .001 |
| ST_Platinum / Nonconstant overlay residual | quality heuristic | PASS | Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed |
| ST_Platinum / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Platinum / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Platinum / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Platinum / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Platinum / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Platinum / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Platinum / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Platinum / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Platinum / Deterministic | hard invariant | PASS | No random component |
| ST_Platinum / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_Cool Silver / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Cool Silver / Finite | hard invariant | PASS | RGBAf output |
| ST_Cool Silver / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Cool Silver / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Cool Silver / Density dependent | quality heuristic | PASS | toner behaves like constant overlay if chromaticity range <= .001 |
| ST_Cool Silver / Nonconstant overlay residual | quality heuristic | PASS | Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed |
| ST_Cool Silver / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Cool Silver / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Cool Silver / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Cool Silver / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Cool Silver / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Cool Silver / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Cool Silver / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Cool Silver / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Cool Silver / Deterministic | hard invariant | PASS | No random component |
| ST_Cool Silver / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_Warm Silver / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Warm Silver / Finite | hard invariant | PASS | RGBAf output |
| ST_Warm Silver / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Warm Silver / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Warm Silver / Density dependent | quality heuristic | PASS | toner behaves like constant overlay if chromaticity range <= .001 |
| ST_Warm Silver / Nonconstant overlay residual | quality heuristic | PASS | Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed |
| ST_Warm Silver / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Warm Silver / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Warm Silver / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Warm Silver / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Warm Silver / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Warm Silver / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Warm Silver / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Warm Silver / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Warm Silver / Deterministic | hard invariant | PASS | No random component |
| ST_Warm Silver / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_Split Silver / Luminance preservation | hard invariant | PASS | Analytic constant-Y projection; 2e-5 linear absolute allows GPU arithmetic, far below photographic exposure differences |
| ST_Split Silver / Finite | hard invariant | PASS | RGBAf output |
| ST_Split Silver / Continuous ratios | hard invariant | PASS | 4096 linear samples, skip first 4 near-zero divisions; <2% channel-ratio jump |
| ST_Split Silver / Continuous hue | hard invariant | PASS | Wrapped angle, chroma > .001, 0.08 radians at sample spacing 1/4095 |
| ST_Split Silver / Density dependent | quality heuristic | PASS | toner behaves like constant overlay if chromaticity range <= .001 |
| ST_Split Silver / Nonconstant overlay residual | quality heuristic | PASS | Linear RGB mean absolute residual > .0001; subtle toners deliberately allowed |
| ST_Split Silver / Strength 0.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Split Silver / Strength 25.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Split Silver / Strength 50.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Split Silver / Strength 75.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Split Silver / Strength 100.0 Y | hard invariant | PASS | Paper and silver share the same Strength |
| ST_Split Silver / Amount zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Split Silver / Strength zero | hard invariant | PASS | Strict early return, including Paper Tone nonzero |
| ST_Split Silver / Extended -0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended -0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended -0.001 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 0.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 0.01 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 0.05 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 0.18 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 0.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 1.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 1.5 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 2.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 3.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 4.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 6.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Extended 8.0 | hard invariant | PASS | Signed luminance, no clamp, monotone Y; negative Y is unchanged |
| ST_Split Silver / Deterministic | hard invariant | PASS | No random component |
| ST_Split Silver / Color input retained | hard invariant | PASS | Original chroma is not discarded |
| ST_control_isolation / selenium strength 0.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / selenium strength 25.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / selenium strength 50.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / selenium strength 75.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / selenium strength 100.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / sepia strength 0.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / sepia strength 25.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / sepia strength 50.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / sepia strength 75.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / sepia strength 100.0 | hard invariant | PASS | Progressive chroma magnitude |
| ST_control_isolation / Paper black isolation | hard invariant | PASS | Paper must not color deep black |
| ST_control_isolation / Balance shifts toward light | hard invariant | PASS | Measured cool/warm transition increases with Balance; overlapping functions |
| ST_control_isolation / No spatial luminance change | hard invariant | PASS | Existing FFT/structure protocol; nonlinear chroma may contain input-derived harmonics, no neighboring samples |
| ST_control_isolation / No noise | hard invariant | PASS | Uniform patch remains spatially uniform |
| ST_extended_controls_alpha / Signed/HDR 0/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 0/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 0/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 0/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 0/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 0/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 0/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 0/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 0/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 0/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 1/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 1/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 2/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 2/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 3/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 3/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 4/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 4/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 5/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 5/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 6/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 6/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 7/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 7/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/-100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/-100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/-100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/-100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/-100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/-100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/0.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/0.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/0.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/0.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/0.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/0.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/100.0/-100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/100.0/-100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/100.0/0.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/100.0/0.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Signed/HDR 8/100.0/100.0 | hard invariant | PASS | Mixed extended RGB and extreme controls retain Y |
| ST_extended_controls_alpha / Black continuity 8/100.0/100.0 | hard invariant | PASS | Dense signed ramp across Y=0, C1 amplitude |
| ST_extended_controls_alpha / Final blend 0.0 | hard invariant | PASS | Amount only mixes the complete pointwise effect |
| ST_extended_controls_alpha / Final blend 25.0 | hard invariant | PASS | Amount only mixes the complete pointwise effect |
| ST_extended_controls_alpha / Final blend 50.0 | hard invariant | PASS | Amount only mixes the complete pointwise effect |
| ST_extended_controls_alpha / Final blend 75.0 | hard invariant | PASS | Amount only mixes the complete pointwise effect |
| ST_extended_controls_alpha / Final blend 100.0 | hard invariant | PASS | Amount only mixes the complete pointwise effect |
| ST_extended_controls_alpha / Alpha 0.0 | hard invariant | PASS | Premultiplication preserved, including transparent black |
| ST_extended_controls_alpha / Alpha 0.2 | hard invariant | PASS | Premultiplication preserved, including transparent black |
| ST_extended_controls_alpha / Alpha 0.5 | hard invariant | PASS | Premultiplication preserved, including transparent black |
| ST_extended_controls_alpha / Alpha 1.0 | hard invariant | PASS | Premultiplication preserved, including transparent black |
| ST_extended_controls_alpha / Neutral HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / Selenium HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / Sepia HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / Copper HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / Gold HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / Platinum HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / Cool Silver HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / Warm Silver HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / Split Silver HDR continuity | hard invariant | PASS | 4096 samples between 1 and 8 |
| ST_extended_controls_alpha / shadow split orientation | hard invariant | PASS | Cool shadow and warm highlight contributions isolated by density |
| ST_extended_controls_alpha / highlight split orientation | hard invariant | PASS | Cool shadow and warm highlight contributions isolated by density |
| ST_standard_masks / simple | hard invariant | PASS | Standard Lumora ROI isolation protocol, existing compositor |
| ST_standard_masks / inverted | hard invariant | PASS | Standard Lumora ROI isolation protocol, existing compositor |
| ST_standard_masks / stacked | hard invariant | PASS | Standard Lumora ROI isolation protocol, existing compositor |
| ST_standard_masks / subtractive | hard invariant | PASS | Standard Lumora ROI isolation protocol, existing compositor |
| ST_standard_masks / Inside responds | hard invariant | PASS | Target ROI changes |
| ST_standard_masks / Second responds | hard invariant | PASS | Second mask changes |
| ST_standard_preset_history_persistence / Preset / Custom | hard invariant | PASS | Shared matcher |
| ST_standard_preset_history_persistence / Rematch | hard invariant | PASS | Exact return to snapshot |
| ST_standard_preset_history_persistence / Undo / Redo | hard invariant | PASS | Existing HistoryManager restores full state |
| ST_standard_preset_history_persistence / Mask and identity | hard invariant | PASS | Existing applying(to:) semantics |
| ST_standard_preset_history_persistence / Document persistence | hard invariant | PASS | Codable round trip |
| ST_standard_preset_history_persistence / Settings persistence | hard invariant | PASS | SilverToningSettings Codable |
| ST_standard_preset_history_persistence / Validation | hard invariant | PASS | Existing parameter range sanitizer |
| ST_stack_silver_bw / Order respected | hard invariant | PASS | Production ordered stack, neutral BW base; no commutativity imposed |
| ST_stack_silver_bw / Finite | hard invariant | PASS | Both orders |
| ST_stack_silver_bw / BW last removes toning | hard invariant | PASS | Full monochrome conversion last |
| ST_stack_film_grain / Order respected | hard invariant | PASS | Production ordered stack, neutral BW base; no commutativity imposed |
| ST_stack_film_grain / Finite | hard invariant | PASS | Both orders |
| ST_stack_glamour_glow / Order respected | hard invariant | PASS | Production ordered stack, neutral BW base; no commutativity imposed |
| ST_stack_glamour_glow / Finite | hard invariant | PASS | Both orders |
| ST_stack_film_emulation / Order respected | hard invariant | PASS | Production ordered stack, neutral BW base; no commutativity imposed |
| ST_stack_film_emulation / Finite | hard invariant | PASS | Both orders |
| ST_stack_cross_processing / Order respected | hard invariant | PASS | Production ordered stack, neutral BW base; no commutativity imposed |
| ST_stack_cross_processing / Finite | hard invariant | PASS | Both orders |
| ST_multi_step_history / Undo Undo Redo | hard invariant | PASS | Every setting is in shared EditState |
| ST_soft_mask_edge / No luminance fringe | hard invariant | PASS | Shared soft mask blend interpolates constant-Y colors |
| ST_pipeline_Subtle Selenium / Cache hit | hard invariant | PASS | Shared RenderEngine cache |
| ST_pipeline_Subtle Selenium / interactive / export | hard invariant | PASS | Pointwise common-size RGB RMSE < .003 including resampling and 8-bit codec |
| ST_pipeline_Subtle Selenium / HQ / export | hard invariant | PASS | Pointwise common-size RGB RMSE < .003 including resampling and 8-bit codec |
| ST_pipeline_Subtle Selenium / Strength invalidates preview | hard invariant | PASS | Changed Silver settings cannot reuse stale pixels |
| ST_pipeline_Subtle Selenium / Toner invalidates preview | hard invariant | PASS | Toner selector uses same cache key |
| ST_pipeline_Classic Sepia / Cache hit | hard invariant | PASS | Shared RenderEngine cache |
| ST_pipeline_Classic Sepia / interactive / export | hard invariant | PASS | Pointwise common-size RGB RMSE < .003 including resampling and 8-bit codec |
| ST_pipeline_Classic Sepia / HQ / export | hard invariant | PASS | Pointwise common-size RGB RMSE < .003 including resampling and 8-bit codec |
| ST_pipeline_Classic Sepia / Strength invalidates preview | hard invariant | PASS | Changed Silver settings cannot reuse stale pixels |
| ST_pipeline_Classic Sepia / Toner invalidates preview | hard invariant | PASS | Toner selector uses same cache key |
| ST_pipeline_Split Warm/Cool / Cache hit | hard invariant | PASS | Shared RenderEngine cache |
| ST_pipeline_Split Warm/Cool / interactive / export | hard invariant | PASS | Pointwise common-size RGB RMSE < .003 including resampling and 8-bit codec |
| ST_pipeline_Split Warm/Cool / HQ / export | hard invariant | PASS | Pointwise common-size RGB RMSE < .003 including resampling and 8-bit codec |
| ST_pipeline_Split Warm/Cool / Strength invalidates preview | hard invariant | PASS | Changed Silver settings cannot reuse stale pixels |
| ST_pipeline_Split Warm/Cool / Toner invalidates preview | hard invariant | PASS | Toner selector uses same cache key |
| ST_performance_resolution_memory / Resolution 1024 | hard invariant | PASS | Same luminance/color at native resolution, pointwise response |
| ST_performance_resolution_memory / Resolution 2048 | hard invariant | PASS | Same luminance/color at native resolution, pointwise response |
| ST_performance_resolution_memory / Resolution 4096 | hard invariant | PASS | Same luminance/color at native resolution, pointwise response |
| ST_performance_resolution_memory / Switch 0/0 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/1 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/2 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/3 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/4 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/5 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/6 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/7 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/8 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/9 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/10 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/11 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/12 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/13 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/14 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/15 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/16 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/17 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/18 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/19 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/20 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/21 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/22 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/23 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/24 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/25 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/26 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/27 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/28 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/29 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/30 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/31 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/32 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/33 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/34 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 0/35 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/0 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/1 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/2 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/3 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/4 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/5 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/6 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/7 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/8 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/9 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/10 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/11 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/12 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/13 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/14 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/15 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/16 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/17 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/18 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/19 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/20 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/21 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/22 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/23 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/24 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/25 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/26 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/27 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/28 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/29 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/30 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/31 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/32 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/33 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/34 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 1/35 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/0 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/1 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/2 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/3 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/4 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/5 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/6 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/7 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/8 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/9 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/10 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/11 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/12 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/13 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/14 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/15 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/16 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/17 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/18 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/19 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/20 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/21 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/22 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/23 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/24 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/25 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/26 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/27 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/28 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/29 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/30 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/31 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/32 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/33 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/34 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 2/35 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/0 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/1 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/2 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/3 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/4 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/5 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/6 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/7 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/8 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/9 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/10 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/11 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/12 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/13 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/14 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/15 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/16 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/17 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/18 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/19 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/20 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/21 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/22 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/23 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/24 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/25 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/26 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/27 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/28 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/29 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/30 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/31 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/32 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/33 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/34 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Switch 3/35 | hard invariant | PASS | All chromatic settings varied, no retained per-effect textures |
| ST_performance_resolution_memory / Bounded post-warmup memory | quality heuristic | PASS | 144 changes; RSS diagnostic, not a device leak instrument |
| ST_photo_01_portrait_light_skin / Neutral Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Neutral Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Neutral Print / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Neutral Print / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Neutral Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Neutral Print / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Subtle Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Subtle Selenium / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Subtle Selenium / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Subtle Selenium / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Subtle Selenium / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Subtle Selenium / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Deep Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Deep Selenium / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Deep Selenium / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Deep Selenium / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Deep Selenium / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Deep Selenium / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Classic Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Classic Sepia / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Classic Sepia / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Classic Sepia / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Classic Sepia / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Classic Sepia / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Soft Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Soft Sepia / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Soft Sepia / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Soft Sepia / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Soft Sepia / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Soft Sepia / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Copper Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Copper Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Copper Print / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Copper Print / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Copper Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Copper Print / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Gold finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Cool Gold / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Gold / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Gold / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Gold / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Gold / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Platinum Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Platinum Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Platinum Print / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Platinum Print / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Platinum Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Platinum Print / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Warm Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Warm Silver / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Warm Silver / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Warm Silver / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Warm Silver / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Warm Silver / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Cool Silver / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Silver / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Silver / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Silver / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Cool Silver / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Split Warm/Cool finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_01_portrait_light_skin / Split Warm/Cool / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Split Warm/Cool / eye detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Split Warm/Cool / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Split Warm/Cool / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Split Warm/Cool / bright background detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_01_portrait_light_skin / Original unchanged | hard invariant | PASS | SHA256 original corpus |
| ST_photo_02_portrait_dark_skin / Neutral Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Neutral Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Neutral Print / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Neutral Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Neutral Print / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Neutral Print / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Neutral Print / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Subtle Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Subtle Selenium / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Subtle Selenium / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Subtle Selenium / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Subtle Selenium / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Subtle Selenium / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Subtle Selenium / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Deep Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Deep Selenium / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Deep Selenium / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Deep Selenium / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Deep Selenium / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Deep Selenium / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Deep Selenium / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Classic Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Classic Sepia / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Classic Sepia / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Classic Sepia / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Classic Sepia / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Classic Sepia / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Classic Sepia / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Soft Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Soft Sepia / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Soft Sepia / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Soft Sepia / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Soft Sepia / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Soft Sepia / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Soft Sepia / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Copper Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Copper Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Copper Print / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Copper Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Copper Print / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Copper Print / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Copper Print / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Gold finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Cool Gold / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Gold / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Gold / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Gold / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Gold / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Gold / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Platinum Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Platinum Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Platinum Print / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Platinum Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Platinum Print / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Platinum Print / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Platinum Print / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Warm Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Warm Silver / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Warm Silver / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Warm Silver / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Warm Silver / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Warm Silver / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Warm Silver / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Cool Silver / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Silver / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Silver / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Silver / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Silver / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Cool Silver / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Split Warm/Cool finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_02_portrait_dark_skin / Split Warm/Cool / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Split Warm/Cool / eyes detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Split Warm/Cool / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Split Warm/Cool / dark clothing detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Split Warm/Cool / highlight on skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Split Warm/Cool / lips detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_02_portrait_dark_skin / Original unchanged | hard invariant | PASS | SHA256 original corpus |
| ST_photo_03_landscape_clouds / Neutral Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Neutral Print / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Neutral Print / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Neutral Print / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Neutral Print / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Neutral Print / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Subtle Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Subtle Selenium / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Subtle Selenium / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Subtle Selenium / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Subtle Selenium / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Subtle Selenium / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Deep Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Deep Selenium / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Deep Selenium / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Deep Selenium / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Deep Selenium / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Deep Selenium / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Classic Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Classic Sepia / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Classic Sepia / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Classic Sepia / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Classic Sepia / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Classic Sepia / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Soft Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Soft Sepia / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Soft Sepia / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Soft Sepia / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Soft Sepia / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Soft Sepia / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Copper Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Copper Print / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Copper Print / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Copper Print / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Copper Print / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Copper Print / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Gold finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Cool Gold / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Gold / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Gold / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Gold / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Gold / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Platinum Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Platinum Print / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Platinum Print / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Platinum Print / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Platinum Print / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Platinum Print / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Warm Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Warm Silver / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Warm Silver / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Warm Silver / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Warm Silver / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Warm Silver / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Cool Silver / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Silver / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Silver / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Silver / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Cool Silver / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Split Warm/Cool finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_03_landscape_clouds / Split Warm/Cool / clouds detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Split Warm/Cool / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Split Warm/Cool / green landscape detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Split Warm/Cool / rocks detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Split Warm/Cool / mountain detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_03_landscape_clouds / Original unchanged | hard invariant | PASS | SHA256 original corpus |
| ST_photo_04_backlight / Neutral Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Neutral Print / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Neutral Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Neutral Print / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Neutral Print / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Subtle Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Subtle Selenium / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Subtle Selenium / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Subtle Selenium / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Subtle Selenium / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Deep Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Deep Selenium / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Deep Selenium / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Deep Selenium / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Deep Selenium / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Classic Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Classic Sepia / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Classic Sepia / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Classic Sepia / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Classic Sepia / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Soft Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Soft Sepia / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Soft Sepia / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Soft Sepia / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Soft Sepia / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Copper Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Copper Print / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Copper Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Copper Print / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Copper Print / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Cool Gold finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Cool Gold / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Cool Gold / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Cool Gold / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Cool Gold / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Platinum Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Platinum Print / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Platinum Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Platinum Print / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Platinum Print / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Warm Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Warm Silver / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Warm Silver / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Warm Silver / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Warm Silver / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Cool Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Cool Silver / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Cool Silver / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Cool Silver / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Cool Silver / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Split Warm/Cool finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_04_backlight / Split Warm/Cool / sun detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Split Warm/Cool / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Split Warm/Cool / face detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Split Warm/Cool / sea reflection detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_04_backlight / Original unchanged | hard invariant | PASS | SHA256 original corpus |
| ST_photo_05_night / Neutral Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Neutral Print / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Neutral Print / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Neutral Print / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Neutral Print / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Subtle Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Subtle Selenium / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Subtle Selenium / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Subtle Selenium / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Subtle Selenium / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Deep Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Deep Selenium / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Deep Selenium / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Deep Selenium / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Deep Selenium / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Classic Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Classic Sepia / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Classic Sepia / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Classic Sepia / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Classic Sepia / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Soft Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Soft Sepia / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Soft Sepia / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Soft Sepia / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Soft Sepia / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Copper Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Copper Print / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Copper Print / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Copper Print / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Copper Print / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Cool Gold finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Cool Gold / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Cool Gold / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Cool Gold / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Cool Gold / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Platinum Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Platinum Print / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Platinum Print / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Platinum Print / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Platinum Print / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Warm Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Warm Silver / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Warm Silver / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Warm Silver / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Warm Silver / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Cool Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Cool Silver / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Cool Silver / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Cool Silver / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Cool Silver / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Split Warm/Cool finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_05_night / Split Warm/Cool / lamp detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Split Warm/Cool / sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Split Warm/Cool / stone detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Split Warm/Cool / wet pavement detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_05_night / Original unchanged | hard invariant | PASS | SHA256 original corpus |
| ST_photo_06_indoor_high_contrast / Neutral Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Neutral Print / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Neutral Print / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Neutral Print / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Neutral Print / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Subtle Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Subtle Selenium / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Subtle Selenium / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Subtle Selenium / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Subtle Selenium / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Deep Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Deep Selenium / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Deep Selenium / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Deep Selenium / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Deep Selenium / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Classic Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Classic Sepia / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Classic Sepia / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Classic Sepia / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Classic Sepia / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Soft Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Soft Sepia / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Soft Sepia / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Soft Sepia / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Soft Sepia / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Copper Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Copper Print / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Copper Print / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Copper Print / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Copper Print / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Cool Gold finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Cool Gold / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Cool Gold / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Cool Gold / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Cool Gold / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Platinum Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Platinum Print / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Platinum Print / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Platinum Print / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Platinum Print / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Warm Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Warm Silver / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Warm Silver / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Warm Silver / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Warm Silver / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Cool Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Cool Silver / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Cool Silver / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Cool Silver / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Cool Silver / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Split Warm/Cool finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_06_indoor_high_contrast / Split Warm/Cool / dark interior detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Split Warm/Cool / sunlit wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Split Warm/Cool / wood table detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Split Warm/Cool / white object detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_06_indoor_high_contrast / Original unchanged | hard invariant | PASS | SHA256 original corpus |
| ST_photo_07_white_subject / Neutral Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Neutral Print / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Neutral Print / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Neutral Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Neutral Print / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Subtle Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Subtle Selenium / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Subtle Selenium / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Subtle Selenium / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Subtle Selenium / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Deep Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Deep Selenium / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Deep Selenium / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Deep Selenium / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Deep Selenium / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Classic Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Classic Sepia / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Classic Sepia / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Classic Sepia / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Classic Sepia / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Soft Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Soft Sepia / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Soft Sepia / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Soft Sepia / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Soft Sepia / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Copper Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Copper Print / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Copper Print / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Copper Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Copper Print / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Cool Gold finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Cool Gold / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Cool Gold / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Cool Gold / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Cool Gold / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Platinum Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Platinum Print / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Platinum Print / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Platinum Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Platinum Print / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Warm Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Warm Silver / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Warm Silver / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Warm Silver / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Warm Silver / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Cool Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Cool Silver / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Cool Silver / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Cool Silver / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Cool Silver / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Split Warm/Cool finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_07_white_subject / Split Warm/Cool / white dress detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Split Warm/Cool / white wall detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Split Warm/Cool / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Split Warm/Cool / blue sky detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_07_white_subject / Original unchanged | hard invariant | PASS | SHA256 original corpus |
| ST_photo_08_fine_texture / Neutral Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Neutral Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Neutral Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Neutral Print / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Neutral Print / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Subtle Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Subtle Selenium / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Subtle Selenium / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Subtle Selenium / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Subtle Selenium / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Deep Selenium finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Deep Selenium / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Deep Selenium / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Deep Selenium / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Deep Selenium / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Classic Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Classic Sepia / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Classic Sepia / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Classic Sepia / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Classic Sepia / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Soft Sepia finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Soft Sepia / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Soft Sepia / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Soft Sepia / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Soft Sepia / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Copper Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Copper Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Copper Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Copper Print / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Copper Print / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Cool Gold finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Cool Gold / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Cool Gold / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Cool Gold / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Cool Gold / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Platinum Print finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Platinum Print / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Platinum Print / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Platinum Print / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Platinum Print / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Warm Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Warm Silver / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Warm Silver / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Warm Silver / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Warm Silver / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Cool Silver finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Cool Silver / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Cool Silver / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Cool Silver / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Cool Silver / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Split Warm/Cool finite / Y | hard invariant | PASS | Identical Neutral Silver base for all toning variants |
| ST_photo_08_fine_texture / Split Warm/Cool / skin detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Split Warm/Cool / hair detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Split Warm/Cool / fabric detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Split Warm/Cool / water detail | hard invariant | PASS | Linear luminance detail is preserved; inspect color on skin, hair, white and black |
| ST_photo_08_fine_texture / Original unchanged | hard invariant | PASS | SHA256 original corpus |
| ST_preset_diversity / Subtle Selenium / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Deep Selenium / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Deep Selenium / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Classic Sepia / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Classic Sepia / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Classic Sepia / Deep Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Soft Sepia / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Soft Sepia / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Soft Sepia / Deep Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Soft Sepia / Classic Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Copper Print / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Copper Print / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Copper Print / Deep Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Copper Print / Classic Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Copper Print / Soft Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Gold / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Gold / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Gold / Deep Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Gold / Classic Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Gold / Soft Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Gold / Copper Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Platinum Print / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Platinum Print / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Platinum Print / Deep Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Platinum Print / Classic Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Platinum Print / Soft Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Platinum Print / Copper Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Platinum Print / Cool Gold | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Warm Silver / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Warm Silver / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Warm Silver / Deep Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Warm Silver / Classic Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Warm Silver / Soft Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Warm Silver / Copper Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Warm Silver / Cool Gold | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Warm Silver / Platinum Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Deep Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Classic Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Soft Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Copper Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Cool Gold | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Platinum Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Cool Silver / Warm Silver | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Neutral Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Subtle Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Deep Selenium | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Classic Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Soft Sepia | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Copper Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Cool Gold | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Platinum Print | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Warm Silver | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |
| ST_preset_diversity / Split Warm/Cool / Cool Silver | quality heuristic | PASS | WARN only if close on synthetic AND eight photos. Deliberately subtle presets exempt; no retuning |

## Inspection photographique — distincte des invariants techniques

| Observation | Type | État | Résultat |
|---|---|---|---|
| Deep Selenium sur les portraits | quality heuristic | WARN | Une dominante mauve est perceptible sur les carnations avec Deep Selenium. Inspection manuelle demandée avant tout raffinement. Subtle Selenium reste nettement plus discret. |
| Nuances peau claire et peau sombre | hard invariant de luminance, esthétique non approuvée | PASS technique | Les ROI de peau, reflets, cheveux et vêtements conservent leur luminance et leur variation ; aucune suppression de texture. Une égalité de Y ne garantit pas à elle seule une couleur de peau plaisante. |
| Sepia / Copper | quality heuristic | PASS provisoire | Le brun chaud de Sepia et le rouge de Copper se distinguent sur portrait et nuit ; les planches restent à approuver. |
| Gold / Cool Silver | quality heuristic | PASS provisoire | Gold plus bleu/violet ; Cool Silver plus cyan. Différences mesurées et visibles sur les planches. |
| Platinum / Subtle Selenium | quality heuristic | PASS provisoire | Faibles amplitudes volontaires. Comparer en A/B à la même échelle ; aucun renforcement pour accroître une distance. |
| Papier / blancs | hard invariant + qualité à revoir | PASS technique | Aucun effet au noir. À Paper=100, Silver=0, erreur RGB maximale 0 à Y=.01, .000319 à Y=.18, .043624 à Y=1. La robe et le mur restent détaillés ; le papier fort est volontairement plus visible dans les blancs. |
| Split / Balance | hard invariant | PASS | La transition froide/chaude mesurée se déplace continûment de Y=.0967 à 1.5433 pour Balance −100→+100. Elle peut sortir de la plage SDR aux extrêmes ; aucune contribution supprimée par seuil. |
| Rampes / banding | hard invariant numérique, inspection PNG limitée | PASS technique | Pas de discontinuité significative ni de hue jump hors chroma quasi nulle dans les 4096 échantillons. Les PNG SDR ne représentent pas les valeurs HDR >1 et leur quantification ne doit pas être confondue avec le kernel float. Aucun faux contour saillant constaté dans la planche examinée ; revue native recommandée. |

Le point exact Y=0 des graphiques R/Y−1 vaut artificiellement −1 car la division est protégée par epsilon : ce point n’a pas de chromaticité définie. Le trait qui le joint au premier échantillon positif n’est pas une discontinuité du renderer. Les contrôles excluent les quatre premières divisions et testent séparément une rampe signée dense autour de zéro. Les graphiques n’ont pas été retouchés après le banc.

Les planches ouvertes pour cette inspection comprennent les deux portraits, la nuit, Paper Tone sur le sujet blanc, toutes les rampes de densité, le stress de banding et « not an overlay ». Cette inspection préliminaire ne remplace pas la validation visuelle de l’utilisateur. Aucun réglage n’a changé.

## Build, tests communs et non-régression

- **PASS / hard invariant** : application iOS, Debug Simulator, signature désactivée (`xcodebuild`, exit 0).
- **PASS / hard invariant** : compilation LumoraVisualTestLab et LumoraCore.
- **PASS** : `silverToningValidation`, 333.228 s ; 1 201 contrôles, aucun échec ni WARN automatique.
- **PASS** : `silverToningDescriptiveTables`, 31.502 s ; 108 lignes descriptives (9 toners, 11 presets, 8×11 photos), aucun pixel non fini.
- **PASS** : 97 tests LumoraCore ; 3 tests de protocole visuel commun, chartes et FFT.
- **PASS / hard invariant** : les 66 presets des 11 Creative FX antérieurs sont bit-identiques au commit `8e2ad94768565acd4254455dce5fffc0f51f0a1c`, seed fixe, même mire RGBAf. Références temporaires générées depuis une copie `git archive` du commit validé, sans Golden Master. Cela prouve la non-régression sur ce fixture ; pas une preuve exhaustive de tous les pixels possibles.
- **PASS** : SHA-256 des sources du premier banc inchangés après mesure. Le fichier de statistiques descriptives a été ajouté à la réception de la fin de spécification, sans modification du banc initial.

Le banc commun conserve **58 cas PASS, 9 cas WARN, 0 FAIL** : cinq cas High Key (clipping SDR), deux Low Key (réponse relative historique), deux Grain (répartition fréquentielle et cohérence aux résolutions). Ce sont des quality heuristics documentées dans [le rapport commun](SilverToning/Common/CreativeFXValidationReport.md), sans correction. Les effets correspondants restent identiques au commit validé.

### Performance : portée des mesures

| Taille | GPU médian (ms) | CPU préparation (ms) | Mur (ms) |
|---|---:|---:|---:|
| 1024 | 0.1043 | 0.0383 | 0.5772 |
| 2048 | 0.3707 | 0.0421 | 0.8958 |
| 4096 | 1.4247 | 0.0477 | 2.0215 |

Apple M2 Pro, entrée uniforme Y=.18, Classic Sepia, sortie texture RGBA32Float. Cette micro-mesure n’inclut ni décodage photographique, ni readback, ni encodage export ; Core Image peut optimiser une entrée uniforme. Elle ne doit pas être présentée comme une latence photographique complète. Les latences réelles RenderEngine ci-dessus sont mesurées séparément : interactive 52.5–115.2 ms, HQ 75.8–86.9 ms. Ces chiffres peuvent inclure chauffe/décodage et ne sont pas des médianes de boucle. RMSE HQ/export ≤.0000707, interactive/export ≤.001159 après réduction commune.

RSS après 36 changements : 151 715 840 octets ; après 144 : 151 732 224 octets, soit +16 384 octets puis plateau. Aucune croissance permanente observée pendant cette séquence. Pas de garantie thermique/mémoire iPhone : aucune mesure sur appareil réel dans ce banc.

## Priority Visual Inspection

- [not_an_overlay.png](SilverToning/not_an_overlay.png)
- [all_density_responses.png](SilverToning/all_density_responses.png)
- [selenium_strength.png](SilverToning/selenium_strength.png)
- [sepia_strength.png](SilverToning/sepia_strength.png)
- [sepia_vs_copper.png](SilverToning/sepia_vs_copper.png)
- [gold_vs_cool_silver.png](SilverToning/gold_vs_cool_silver.png)
- [paper_tone_response.png](SilverToning/paper_tone_response.png)
- [split_toning_response.png](SilverToning/split_toning_response.png)
- [reference_triptych.png](SilverToning/reference_triptych.png)
- [RealPhotos/01_portrait_light_skin/portrait_light_toning_comparison.png](SilverToning/RealPhotos/01_portrait_light_skin/portrait_light_toning_comparison.png)
- [RealPhotos/02_portrait_dark_skin/portrait_dark_toning_comparison.png](SilverToning/RealPhotos/02_portrait_dark_skin/portrait_dark_toning_comparison.png)
- [RealPhotos/05_night/night_toning_comparison.png](SilverToning/RealPhotos/05_night/night_toning_comparison.png)
- [RealPhotos/07_white_subject/white_subject_toning_comparison.png](SilverToning/RealPhotos/07_white_subject/white_subject_toning_comparison.png)
- [RealPhotos/07_white_subject/paper_tone_white_subject.png](SilverToning/RealPhotos/07_white_subject/paper_tone_white_subject.png)
