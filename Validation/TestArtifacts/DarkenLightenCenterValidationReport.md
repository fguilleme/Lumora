# Darken / Lighten Center — validation

**22 PASS, 6 WARN, 0 FAIL** — cas du banc. Les contrôles hard et les quality heuristics sont distingués ci-dessous. Un PASS technique ne vaut pas approbation photographique. Pas de Golden Master ni de retouche automatique après mesure. Matériel : Apple M2 Pro, Version 26.6.2 (Build 25G83).

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
Subtle Focus, Portrait Focus, Dark Surround, Light Center, Wide Focus, Narrow Focus, Off-Center Drama, Reverse Focus.

## Tableau géométrique

Erreur RGB sur champ uniforme mesurée face à l’oracle ; les déplacements, rayons et angles preview/export sont reportés séparément dans leurs unités.

| Ratio | Centre X/Y | Size | Shape | Rotation | Feather | Center/Border EV | Erreur max | État |
|---|---|---:|---:|---:|---:|---|---:|---|
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 0.0 | 75.0 | 1 / −1 | 8.624710728932783e-08 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 37.0 | 75.0 | 1 / −1 | 1.0350557316796127e-07 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 90.0 | 75.0 | 1 / −1 | 1.496958175195573e-07 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 173.0 | 75.0 | 1 / −1 | 1.6009438000286202e-07 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 0.0 | 75.0 | 1 / −1 | 9.178490795180849e-08 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 37.0 | 75.0 | 1 / −1 | 9.178490795180849e-08 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 90.0 | 75.0 | 1 / −1 | 9.178490795180849e-08 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 173.0 | 75.0 | 1 / −1 | 9.178490795180849e-08 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 0.0 | 75.0 | 1 / −1 | 1.496958175195573e-07 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 37.0 | 75.0 | 1 / −1 | 1.463908237131495e-07 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 90.0 | 75.0 | 1 / −1 | 8.624710723381668e-08 | PASS |
| 768.0/512.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 173.0 | 75.0 | 1 / −1 | 2.1592091645206146e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 0.0 | 75.0 | 1 / −1 | 1.2064889806651102e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 37.0 | 75.0 | 1 / −1 | 1.4531339032064494e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 90.0 | 75.0 | 1 / −1 | 1.479680665217309e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 173.0 | 75.0 | 1 / −1 | 1.8641845464517637e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 0.0 | 75.0 | 1 / −1 | 1.062652896233196e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 37.0 | 75.0 | 1 / −1 | 1.062652897343419e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 90.0 | 75.0 | 1 / −1 | 1.062652896233196e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 173.0 | 75.0 | 1 / −1 | 1.062652897343419e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 0.0 | 75.0 | 1 / −1 | 1.479680665217309e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 37.0 | 75.0 | 1 / −1 | 1.0563767377513855e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 90.0 | 75.0 | 1 / −1 | 1.1522915985273663e-07 | PASS |
| 512.0/768.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 173.0 | 75.0 | 1 / −1 | 2.150078268481348e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 0.0 | 75.0 | 1 / −1 | 1.227443297557862e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 37.0 | 75.0 | 1 / −1 | 9.890216870478419e-08 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 90.0 | 75.0 | 1 / −1 | 1.4263456935004193e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | -100.0 | 173.0 | 75.0 | 1 / −1 | 1.7759669676542522e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 0.0 | 75.0 | 1 / −1 | 1.0934911914839418e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 37.0 | 75.0 | 1 / −1 | 1.0934911914839418e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 90.0 | 75.0 | 1 / −1 | 1.0934911914839418e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | 0.0 | 173.0 | 75.0 | 1 / −1 | 1.0934911914839418e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 0.0 | 75.0 | 1 / −1 | 1.6695230986574217e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 37.0 | 75.0 | 1 / −1 | 1.5904636924135573e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 90.0 | 75.0 | 1 / −1 | 1.1457570600614808e-07 | PASS |
| 512.0/512.0 | 0.3731, 0.4273 | 38.0 | 100.0 | 173.0 | 75.0 | 1 / −1 | 2.1453087406531068e-07 | PASS |

## Résultats et type de chaque contrôle

### DLC_geometry_oracle — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| 768x512/-100.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/-100.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/-100.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/-100.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/0.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/0.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/0.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/0.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/100.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/100.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/100.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 768x512/100.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/-100.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/-100.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/-100.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/-100.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/0.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/0.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/0.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/0.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/100.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/100.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/100.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x768/100.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/-100.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/-100.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/-100.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/-100.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/0.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/0.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/0.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/0.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/100.0/0.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/100.0/37.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/100.0/90.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |
| 512x512/100.0/173.0 | hard invariant | PASS | Independent Float64 spatial oracle, pixel centers and top-left coordinates |



### DLC_identity_EV_HDR_color — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| neutral/5.0/-100.0 | hard invariant | PASS | Strict input return |
| amount/5.0/-100.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/5.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/5.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/5.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/5.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/5.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| neutral/5.0/0.0 | hard invariant | PASS | Strict input return |
| amount/5.0/0.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/5.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/5.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/5.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/5.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/5.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| neutral/5.0/100.0 | hard invariant | PASS | Strict input return |
| amount/5.0/100.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/5.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/5.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/5.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/5.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/5.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| neutral/45.0/-100.0 | hard invariant | PASS | Strict input return |
| amount/45.0/-100.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/45.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/45.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/45.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/45.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/45.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| neutral/45.0/0.0 | hard invariant | PASS | Strict input return |
| amount/45.0/0.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/45.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/45.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/45.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/45.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/45.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| neutral/45.0/100.0 | hard invariant | PASS | Strict input return |
| amount/45.0/100.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/45.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/45.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/45.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/45.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/45.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| neutral/150.0/-100.0 | hard invariant | PASS | Strict input return |
| amount/150.0/-100.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/150.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/150.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/150.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/150.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/150.0/-100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| neutral/150.0/0.0 | hard invariant | PASS | Strict input return |
| amount/150.0/0.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/150.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/150.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/150.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/150.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/150.0/0.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| neutral/150.0/100.0 | hard invariant | PASS | Strict input return |
| amount/150.0/100.0 | hard invariant | PASS | Strict input return |
| Equal EV -2.0/150.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV -1.0/150.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 0.0/150.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 1.0/150.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| Equal EV 2.0/150.0/100.0 | hard invariant | PASS | Matches global linear exposure regardless of geometry |
| HDR / signed -0.05 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed -0.01 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed -0.001 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed 0.0 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed 0.1 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed 0.5 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed 1.0 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed 2.0 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed 4.0 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| HDR / signed 8.0 | hard invariant | PASS | Exact ×4 / ×.25 at plateaus; signed RGB, no clamp |
| Color preserved | hard invariant | PASS | RGB normalized ratios before any display clipping/gamut mapping |
| Amount 0.0 | hard invariant | PASS | Final linear blend, not EV interpolation |
| Amount 25.0 | hard invariant | PASS | Final linear blend, not EV interpolation |
| Amount 50.0 | hard invariant | PASS | Final linear blend, not EV interpolation |
| Amount 75.0 | hard invariant | PASS | Final linear blend, not EV interpolation |
| Amount 100.0 | hard invariant | PASS | Final linear blend, not EV interpolation |
| Deterministic | hard invariant | PASS | Same immutable geometry |

| Mesure | Valeur |
|---|---:|
| equalEV/-1.0/150.0/-100.0-maxError | 4.7683716e-07 |
| equalEV/-1.0/150.0/0.0-maxError | 4.7683716e-07 |
| equalEV/-1.0/150.0/100.0-maxError | 4.7683716e-07 |
| equalEV/-1.0/45.0/-100.0-maxError | 4.7683716e-07 |
| equalEV/-1.0/45.0/0.0-maxError | 4.7683716e-07 |
| equalEV/-1.0/45.0/100.0-maxError | 4.7683716e-07 |
| equalEV/-1.0/5.0/-100.0-maxError | 4.7683716e-07 |
| equalEV/-1.0/5.0/0.0-maxError | 4.7683716e-07 |
| equalEV/-1.0/5.0/100.0-maxError | 4.7683716e-07 |
| equalEV/-2.0/150.0/-100.0-maxError | 0 |
| equalEV/-2.0/150.0/0.0-maxError | 0 |
| equalEV/-2.0/150.0/100.0-maxError | 0 |
| equalEV/-2.0/45.0/-100.0-maxError | 0 |
| equalEV/-2.0/45.0/0.0-maxError | 0 |
| equalEV/-2.0/45.0/100.0-maxError | 0 |
| equalEV/-2.0/5.0/-100.0-maxError | 0 |
| equalEV/-2.0/5.0/0.0-maxError | 0 |
| equalEV/-2.0/5.0/100.0-maxError | 0 |
| equalEV/0.0/150.0/-100.0-maxError | 0 |
| equalEV/0.0/150.0/0.0-maxError | 0 |
| equalEV/0.0/150.0/100.0-maxError | 0 |
| equalEV/0.0/45.0/-100.0-maxError | 0 |
| equalEV/0.0/45.0/0.0-maxError | 0 |
| equalEV/0.0/45.0/100.0-maxError | 0 |
| equalEV/0.0/5.0/-100.0-maxError | 0 |
| equalEV/0.0/5.0/0.0-maxError | 0 |
| equalEV/0.0/5.0/100.0-maxError | 0 |
| equalEV/1.0/150.0/-100.0-maxError | 0 |
| equalEV/1.0/150.0/0.0-maxError | 0 |
| equalEV/1.0/150.0/100.0-maxError | 0 |
| equalEV/1.0/45.0/-100.0-maxError | 0 |
| equalEV/1.0/45.0/0.0-maxError | 0 |
| equalEV/1.0/45.0/100.0-maxError | 0 |
| equalEV/1.0/5.0/-100.0-maxError | 0 |
| equalEV/1.0/5.0/0.0-maxError | 0 |
| equalEV/1.0/5.0/100.0-maxError | 0 |
| equalEV/2.0/150.0/-100.0-maxError | 0 |
| equalEV/2.0/150.0/0.0-maxError | 0 |
| equalEV/2.0/150.0/100.0-maxError | 0 |
| equalEV/2.0/45.0/-100.0-maxError | 0 |
| equalEV/2.0/45.0/0.0-maxError | 0 |
| equalEV/2.0/45.0/100.0-maxError | 0 |
| equalEV/2.0/5.0/-100.0-maxError | 0 |
| equalEV/2.0/5.0/0.0-maxError | 0 |
| equalEV/2.0/5.0/100.0-maxError | 0 |
| maxChromaticityDrift | 1.0538201e-07 |



### DLC_circle_symmetry_extent_crop — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Circle rotation 0.0 | hard invariant | PASS | Circle canonical rotation |
| Circle rotation 37.0 | hard invariant | PASS | Circle canonical rotation |
| Circle rotation 90.0 | hard invariant | PASS | Circle canonical rotation |
| Circle rotation 173.0 | hard invariant | PASS | Circle canonical rotation |
| Mirror and axis symmetry | hard invariant | PASS | Horizontal, vertical, diagonal; implies 180 degree symmetry |
| Ellipse 90 axes exchange | hard invariant | PASS | Reciprocal axes at constant ellipse area |
| Translated extent | hard invariant | PASS | Integer nonzero CI extent, same local geometry |
| Fractional extent actual-frame oracle | hard invariant | PASS | CI rounds transformed bounds to 513×513; interior avoids resampled source alpha boundary |
| Crop semantics | hard invariant | PASS | DLC uses its incoming extent; crop before and after have different frames |

| Mesure | Valeur |
|---|---:|
| fractionalExtentOracleMaxError | 7.8608799e-08 |



### DLC_profiles_subpixel_viewport — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Smooth 0.0 | hard invariant | PASS | 4096 spatial profile; bounded first/second differences, C2 plateaus |
| No overshoot 0.0 | hard invariant | PASS | EV remains between Center and Border |
| Smooth 25.0 | hard invariant | PASS | 4096 spatial profile; bounded first/second differences, C2 plateaus |
| No overshoot 25.0 | hard invariant | PASS | EV remains between Center and Border |
| Smooth 50.0 | hard invariant | PASS | 4096 spatial profile; bounded first/second differences, C2 plateaus |
| No overshoot 50.0 | hard invariant | PASS | EV remains between Center and Border |
| Smooth 75.0 | hard invariant | PASS | 4096 spatial profile; bounded first/second differences, C2 plateaus |
| No overshoot 75.0 | hard invariant | PASS | EV remains between Center and Border |
| Smooth 100.0 | hard invariant | PASS | 4096 spatial profile; bounded first/second differences, C2 plateaus |
| No overshoot 100.0 | hard invariant | PASS | EV remains between Center and Border |
| Radial 0.0 | hard invariant | PASS | Nearest GPU sampling footprint <= .71 px; reference exact radial distance |
| Radial 45.0 | hard invariant | PASS | Nearest GPU sampling footprint <= .71 px; reference exact radial distance |
| Radial 90.0 | hard invariant | PASS | Nearest GPU sampling footprint <= .71 px; reference exact radial distance |
| Radial 135.0 | hard invariant | PASS | Nearest GPU sampling footprint <= .71 px; reference exact radial distance |
| Subpixel 0 | hard invariant | PASS | Weighted EV centroid, normalized error <1e-5 (0.00512px) |
| Subpixel 1 | hard invariant | PASS | Weighted EV centroid, normalized error <1e-5 (0.00512px) |
| Subpixel 2 | hard invariant | PASS | Weighted EV centroid, normalized error <1e-5 (0.00512px) |
| Subpixel 3 | hard invariant | PASS | Weighted EV centroid, normalized error <1e-5 (0.00512px) |
| Subpixel 4 | hard invariant | PASS | Weighted EV centroid, normalized error <1e-5 (0.00512px) |
| Subpixel 5 | hard invariant | PASS | Weighted EV centroid, normalized error <1e-5 (0.00512px) |
| Continuous displacement | hard invariant | PASS | No quantization to preview pixels |
| UI roundtrip (390.0, 340.0)/1.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (390.0, 340.0)/1.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (390.0, 340.0)/2.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (390.0, 340.0)/2.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (390.0, 340.0)/5.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (390.0, 340.0)/5.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (844.0, 300.0)/1.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (844.0, 300.0)/1.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (844.0, 300.0)/2.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (844.0, 300.0)/2.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (844.0, 300.0)/5.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (844.0, 300.0)/5.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (768.0, 900.0)/1.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (768.0, 900.0)/1.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (768.0, 900.0)/2.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (768.0, 900.0)/2.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (768.0, 900.0)/5.0/(1600.0, 900.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |
| UI roundtrip (768.0, 900.0)/5.0/(900.0, 1600.0) | hard invariant | PASS | Same pure transform used by PhotoCanvas overlay; screen hit target separated from saved image coordinates |

| Mesure | Valeur |
|---|---:|
| feather0.0-maxFirstDifference | 0.017436678 |
| feather0.0-maxSecondDifference | 0.00025087143 |
| feather100.0-maxFirstDifference | 0.0026160142 |
| feather100.0-maxSecondDifference | 6.9734211e-06 |
| feather25.0-maxFirstDifference | 0.0072167597 |
| feather25.0-maxSecondDifference | 4.4392689e-05 |
| feather50.0-maxFirstDifference | 0.0045496831 |
| feather50.0-maxSecondDifference | 1.8299356e-05 |
| feather75.0-maxFirstDifference | 0.0033216927 |
| feather75.0-maxSecondDifference | 1.0645231e-05 |
| radial0.0-maxEVError | 0.0066516295 |
| radial135.0-maxEVError | 0.0089585277 |
| radial45.0-maxEVError | 0.0089585277 |
| radial90.0-maxEVError | 0.0066516295 |
| subpixel0-centerError | 1.3025273e-08 |
| subpixel1-centerError | 1.3354856e-10 |
| subpixel2-centerError | 1.2994829e-08 |
| subpixel3-centerError | 4.1667794e-09 |
| subpixel4-centerError | 9.0684233e-09 |
| subpixel5-centerError | 8.8020297e-09 |



### DLC_standard_masks — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| simple | hard invariant | PASS | Standard Lumora ROI isolation protocol, existing compositor |
| inverted | hard invariant | PASS | Standard Lumora ROI isolation protocol, existing compositor |
| stacked | hard invariant | PASS | Standard Lumora ROI isolation protocol, existing compositor |
| subtractive | hard invariant | PASS | Standard Lumora ROI isolation protocol, existing compositor |
| Inside responds | hard invariant | PASS | Target ROI changes |
| Second responds | hard invariant | PASS | Second mask changes |

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



### DLC_standard_preset_history_persistence — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Preset / Custom | hard invariant | PASS | Shared matcher |
| Rematch | hard invariant | PASS | Exact return to snapshot |
| Undo / Redo | hard invariant | PASS | Existing HistoryManager restores full state |
| Mask and identity | hard invariant | PASS | Existing applying(to:) semantics |
| Document persistence | hard invariant | PASS | Codable round trip |
| Settings persistence | hard invariant | PASS | DarkenLightenCenterSettings Codable |
| Validation | hard invariant | PASS | Existing parameter range sanitizer |



### DLC_stack_silverBW — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |

| Mesure | Valeur |
|---|---:|
| orderMAE | 0.00095974939 |



### DLC_stack_silverToning — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |

| Mesure | Valeur |
|---|---:|
| orderMAE | 0.00030801804 |



### DLC_stack_filmEmulation — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |
| Nonlinear film differs | hard invariant | PASS | Exposure before and after film response differ |

| Mesure | Valeur |
|---|---:|
| orderMAE | 0.00092741254 |



### DLC_stack_highKey — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |

| Mesure | Valeur |
|---|---:|
| orderMAE | 0.014779234 |



### DLC_stack_lowKey — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |

| Mesure | Valeur |
|---|---:|
| orderMAE | 0.00061209532 |



### DLC_stack_glamourGlow — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |

| Mesure | Valeur |
|---|---:|
| orderMAE | 0.0031063138 |



### DLC_stack_tonalContrast — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |

| Mesure | Valeur |
|---|---:|
| orderMAE | 5.2213139e-05 |



### DLC_stack_detailExtractor — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |

| Mesure | Valeur |
|---|---:|
| orderMAE | 8.470296e-05 |



### DLC_stack_grain — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Finite both orders | hard invariant | PASS | Ordered production compositor |
| Order matches explicit composition | hard invariant | PASS | No arbitrary noncommutativity threshold imposed |

| Mesure | Valeur |
|---|---:|
| orderMAE | 8.3614867e-05 |



### DLC_history_multi_instance — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Duplicate independent identity | hard invariant | PASS | Shared duplicate implementation |
| Original unchanged | hard invariant | PASS | Value settings, no shared geometry cache |
| Instances compose | hard invariant | PASS | Pointwise gains may commute; order still evaluated literally |
| Coalesced drag Undo/Redo | hard invariant | PASS | One begin/commit for a continuous gesture, as used in EditorSession |
| Restored pixels | hard invariant | PASS | Persistence includes all geometry and external mask settings |



### DLC_preview_HQ_export_alignment — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Export center | hard invariant | PASS | Recovered field centroid, normalized displacement <.003 including output quantization |
| interactive alignment | hard invariant | PASS | Moment geometry and complete common-size profile; 8-bit output tolerance |
| HQ alignment | hard invariant | PASS | Moment geometry and complete common-size profile; 8-bit output tolerance |
| Cache hit | hard invariant | PASS | Existing RenderEngine cache |
| No stale centerX | hard invariant | PASS | Each geometry parameter invalidates output |
| No stale centerY | hard invariant | PASS | Each geometry parameter invalidates output |
| No stale size | hard invariant | PASS | Each geometry parameter invalidates output |
| No stale shape | hard invariant | PASS | Each geometry parameter invalidates output |
| No stale rotation | hard invariant | PASS | Each geometry parameter invalidates output |
| No stale feather | hard invariant | PASS | Each geometry parameter invalidates output |
| Multi-instance cache | hard invariant | PASS | Full stack contributes to cache key |

| Mesure | Valeur |
|---|---:|
| HQ-centerDisplacement | 3.0209519e-08 |
| HQ-milliseconds | 94.408167 |
| HQ-profileMAE | 3.6823076e-05 |
| HQ-radiusError | 4.3440855e-05 |
| HQ-rotationErrorDegrees | 4.8659212e-07 |
| export-centerError | 1.3004545e-06 |
| interactive-centerDisplacement | 5.3859711e-06 |
| interactive-milliseconds | 107.66721 |
| interactive-profileMAE | 5.3510972e-05 |
| interactive-radiusError | 4.2007918e-05 |
| interactive-rotationErrorDegrees | 0.00016906813 |



### DLC_EXIF_orientation — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| EXIF 1 | hard invariant | PASS | ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center |
| EXIF export 1 | hard invariant | PASS | Same normalized visual center after export |
| EXIF 2 | hard invariant | PASS | ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center |
| EXIF export 2 | hard invariant | PASS | Same normalized visual center after export |
| EXIF 3 | hard invariant | PASS | ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center |
| EXIF export 3 | hard invariant | PASS | Same normalized visual center after export |
| EXIF 4 | hard invariant | PASS | ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center |
| EXIF export 4 | hard invariant | PASS | Same normalized visual center after export |
| EXIF 5 | hard invariant | PASS | ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center |
| EXIF export 5 | hard invariant | PASS | Same normalized visual center after export |
| EXIF 6 | hard invariant | PASS | ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center |
| EXIF export 6 | hard invariant | PASS | Same normalized visual center after export |
| EXIF 7 | hard invariant | PASS | ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center |
| EXIF export 7 | hard invariant | PASS | Same normalized visual center after export |
| EXIF 8 | hard invariant | PASS | ImageIO orientation vs independently oriented CI image; asymmetric corner landmarks and top-left center |
| EXIF export 8 | hard invariant | PASS | Same normalized visual center after export |

| Mesure | Valeur |
|---|---:|
| EXIF1-profileMAE | 0.00059229184 |
| EXIF2-profileMAE | 0.00059100206 |
| EXIF3-profileMAE | 0.00059214323 |
| EXIF4-profileMAE | 0.0005908246 |
| EXIF5-profileMAE | 0.00059228792 |
| EXIF6-profileMAE | 0.00059082163 |
| EXIF7-profileMAE | 0.00059214035 |
| EXIF8-profileMAE | 0.00059099819 |



### DLC_performance_resolution_memory — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Resolution 1024 | hard invariant | PASS | Same normalized varying scene rendered natively, reduced to 256px |
| Resolution 2048 | hard invariant | PASS | Same normalized varying scene rendered natively, reduced to 256px |
| Resolution 4096 | hard invariant | PASS | Same normalized varying scene rendered natively, reduced to 256px |
| Switch 0/0 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/1 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/2 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/3 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/4 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/5 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/6 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/7 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/8 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/9 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/10 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/11 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/12 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/13 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/14 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/15 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/16 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/17 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/18 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/19 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/20 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/21 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/22 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/23 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/24 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/25 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/26 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/27 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/28 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/29 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/30 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/31 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/32 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/33 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/34 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 0/35 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/0 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/1 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/2 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/3 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/4 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/5 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/6 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/7 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/8 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/9 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/10 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/11 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/12 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/13 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/14 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/15 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/16 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/17 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/18 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/19 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/20 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/21 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/22 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/23 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/24 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/25 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/26 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/27 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/28 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/29 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/30 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/31 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/32 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/33 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/34 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 1/35 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/0 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/1 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/2 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/3 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/4 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/5 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/6 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/7 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/8 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/9 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/10 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/11 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/12 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/13 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/14 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/15 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/16 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/17 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/18 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/19 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/20 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/21 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/22 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/23 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/24 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/25 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/26 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/27 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/28 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/29 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/30 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/31 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/32 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/33 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/34 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 2/35 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/0 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/1 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/2 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/3 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/4 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/5 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/6 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/7 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/8 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/9 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/10 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/11 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/12 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/13 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/14 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/15 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/16 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/17 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/18 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/19 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/20 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/21 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/22 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/23 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/24 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/25 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/26 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/27 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/28 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/29 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/30 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/31 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/32 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/33 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/34 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Switch 3/35 | hard invariant | PASS | Geometry varied, no retained per-effect mask texture |
| Bounded post-warmup memory | quality heuristic | PASS | 144 changes; RSS diagnostic, not a device leak instrument |

| Mesure | Valeur |
|---|---:|
| 1024-CPU-graph-medianMS | 0.044041662 |
| 1024-GPU-medianMS | 0.18020836 |
| 1024-resolutionMaxError | 0 |
| 1024-wall-medianMS | 0.7331667 |
| 2048-CPU-graph-medianMS | 0.037083286 |
| 2048-GPU-medianMS | 0.73249999 |
| 2048-resolutionMaxError | 2.4139881e-06 |
| 2048-wall-medianMS | 2.087625 |
| 4096-CPU-graph-medianMS | 0.036958372 |
| 4096-GPU-medianMS | 2.9084167 |
| 4096-resolutionMaxError | 3.6358833e-06 |
| 4096-wall-medianMS | 5.0446667 |
| RSS-batch0 | 5.4252339e+08 |
| RSS-batch1 | 2.7267891e+08 |
| RSS-batch2 | 2.726953e+08 |
| RSS-batch3 | 2.726953e+08 |
| instances1-materializationMedianMS | 7.2259166 |
| instances2-materializationMedianMS | 7.401625 |
| instances4-materializationMedianMS | 7.1892501 |

GPU command timestamps include CI encoding execution and output writes, without CPU readback. CPU timing is settings validation/graph preparation; compile is warmed. No isolated kernel-only claim. Mac GPU, not iPhone thermal performance.

### DLC_photo_portrait_light — WARN

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Subtle Focus finite | hard invariant | PASS | Full-frame float sample |
| Subtle Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Subtle Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / eye hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / lips hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / bright background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus finite | hard invariant | PASS | Full-frame float sample |
| Portrait Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Portrait Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / eye hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / lips hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / bright background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround finite | hard invariant | PASS | Full-frame float sample |
| Dark Surround new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Dark Surround / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / eye hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / lips hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / bright background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center finite | hard invariant | PASS | Full-frame float sample |
| Light Center new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Light Center / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / eye hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / lips hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / bright background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus finite | hard invariant | PASS | Full-frame float sample |
| Wide Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Wide Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / eye hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / lips hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / bright background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus finite | hard invariant | PASS | Full-frame float sample |
| Narrow Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Narrow Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / eye hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / lips hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / bright background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama finite | hard invariant | PASS | Full-frame float sample |
| Off-Center Drama new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Off-Center Drama / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / eye hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / lips hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / bright background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus finite | hard invariant | PASS | Full-frame float sample |
| Reverse Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Reverse Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / eye hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / lips hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / bright background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Source unchanged | hard invariant | PASS | Original SHA256 before/after |

| Mesure | Valeur |
|---|---:|
| Dark Surround / bright background / chromaticityDrift | 5.5951691e-08 |
| Dark Surround / bright background / clippedFraction | 0 |
| Dark Surround / bright background / inputClippedFraction | 0 |
| Dark Surround / bright background / newClippedFraction | 0 |
| Dark Surround / bright background / shadowRMS | 0 |
| Dark Surround / eye / chromaticityDrift | 8.1145009e-08 |
| Dark Surround / eye / clippedFraction | 0 |
| Dark Surround / eye / inputClippedFraction | 0 |
| Dark Surround / eye / newClippedFraction | 0 |
| Dark Surround / eye / shadowRMS | 0.022941102 |
| Dark Surround / hair / chromaticityDrift | 6.3535797e-08 |
| Dark Surround / hair / clippedFraction | 0 |
| Dark Surround / hair / inputClippedFraction | 0 |
| Dark Surround / hair / newClippedFraction | 0 |
| Dark Surround / hair / shadowRMS | 0.018004508 |
| Dark Surround / lips / chromaticityDrift | 8.9645224e-08 |
| Dark Surround / lips / clippedFraction | 0 |
| Dark Surround / lips / inputClippedFraction | 0 |
| Dark Surround / lips / newClippedFraction | 0 |
| Dark Surround / lips / shadowRMS | 0.023113819 |
| Dark Surround / skin / chromaticityDrift | 7.8940966e-08 |
| Dark Surround / skin / clippedFraction | 0 |
| Dark Surround / skin / inputClippedFraction | 0 |
| Dark Surround / skin / newClippedFraction | 0 |
| Dark Surround / skin / shadowRMS | 0.01403744 |
| Dark Surround / transition / chromaticityDrift | 7.4036379e-08 |
| Dark Surround / transition / clippedFraction | 0 |
| Dark Surround / transition / inputClippedFraction | 0 |
| Dark Surround / transition / newClippedFraction | 0 |
| Dark Surround / transition / shadowRMS | 0.011273895 |
| Light Center / bright background / chromaticityDrift | 0 |
| Light Center / bright background / clippedFraction | 0 |
| Light Center / bright background / inputClippedFraction | 0 |
| Light Center / bright background / newClippedFraction | 0 |
| Light Center / bright background / shadowRMS | 0 |
| Light Center / eye / chromaticityDrift | 8.3522942e-08 |
| Light Center / eye / clippedFraction | 0 |
| Light Center / eye / inputClippedFraction | 0 |
| Light Center / eye / newClippedFraction | 0 |
| Light Center / eye / shadowRMS | 0.033408019 |
| Light Center / hair / chromaticityDrift | 7.2100798e-08 |
| Light Center / hair / clippedFraction | 0 |
| Light Center / hair / inputClippedFraction | 0 |
| Light Center / hair / newClippedFraction | 0 |
| Light Center / hair / shadowRMS | 0.026696513 |
| Light Center / lips / chromaticityDrift | 9.533182e-08 |
| Light Center / lips / clippedFraction | 0 |
| Light Center / lips / inputClippedFraction | 0 |
| Light Center / lips / newClippedFraction | 0 |
| Light Center / lips / shadowRMS | 0.033305087 |
| Light Center / skin / chromaticityDrift | 8.7918662e-08 |
| Light Center / skin / clippedFraction | 0 |
| Light Center / skin / inputClippedFraction | 0 |
| Light Center / skin / newClippedFraction | 0 |
| Light Center / skin / shadowRMS | 0.020553998 |
| Light Center / transition / chromaticityDrift | 7.1703882e-08 |
| Light Center / transition / clippedFraction | 0 |
| Light Center / transition / inputClippedFraction | 0 |
| Light Center / transition / newClippedFraction | 0 |
| Light Center / transition / shadowRMS | 0.018920957 |
| Narrow Focus / bright background / chromaticityDrift | 5.622875e-08 |
| Narrow Focus / bright background / clippedFraction | 0 |
| Narrow Focus / bright background / inputClippedFraction | 0 |
| Narrow Focus / bright background / newClippedFraction | 0 |
| Narrow Focus / bright background / shadowRMS | 0 |
| Narrow Focus / eye / chromaticityDrift | 8.1784534e-08 |
| Narrow Focus / eye / clippedFraction | 0 |
| Narrow Focus / eye / inputClippedFraction | 0 |
| Narrow Focus / eye / newClippedFraction | 0 |
| Narrow Focus / eye / shadowRMS | 0.02908687 |
| Narrow Focus / hair / chromaticityDrift | 6.9602345e-08 |
| Narrow Focus / hair / clippedFraction | 0 |
| Narrow Focus / hair / inputClippedFraction | 0 |
| Narrow Focus / hair / newClippedFraction | 0 |
| Narrow Focus / hair / shadowRMS | 0.016868988 |
| Narrow Focus / lips / chromaticityDrift | 8.8563532e-08 |
| Narrow Focus / lips / clippedFraction | 0 |
| Narrow Focus / lips / inputClippedFraction | 0 |
| Narrow Focus / lips / newClippedFraction | 0 |
| Narrow Focus / lips / shadowRMS | 0.024710675 |
| Narrow Focus / skin / chromaticityDrift | 8.7059106e-08 |
| Narrow Focus / skin / clippedFraction | 0 |
| Narrow Focus / skin / inputClippedFraction | 0 |
| Narrow Focus / skin / newClippedFraction | 0 |
| Narrow Focus / skin / shadowRMS | 0.019371883 |
| Narrow Focus / transition / chromaticityDrift | 6.1537341e-08 |
| Narrow Focus / transition / clippedFraction | 0 |
| Narrow Focus / transition / inputClippedFraction | 0 |
| Narrow Focus / transition / newClippedFraction | 0 |
| Narrow Focus / transition / shadowRMS | 0.01310989 |
| Off-Center Drama / bright background / chromaticityDrift | 5.46927e-08 |
| Off-Center Drama / bright background / clippedFraction | 0 |
| Off-Center Drama / bright background / inputClippedFraction | 0 |
| Off-Center Drama / bright background / newClippedFraction | 0 |
| Off-Center Drama / bright background / shadowRMS | 0 |
| Off-Center Drama / eye / chromaticityDrift | 8.5228529e-08 |
| Off-Center Drama / eye / clippedFraction | 0 |
| Off-Center Drama / eye / inputClippedFraction | 0 |
| Off-Center Drama / eye / newClippedFraction | 0 |
| Off-Center Drama / eye / shadowRMS | 0.029872554 |
| Off-Center Drama / hair / chromaticityDrift | 7.354895e-08 |
| Off-Center Drama / hair / clippedFraction | 0 |
| Off-Center Drama / hair / inputClippedFraction | 0 |
| Off-Center Drama / hair / newClippedFraction | 0 |
| Off-Center Drama / hair / shadowRMS | 0.018682545 |
| Off-Center Drama / lips / chromaticityDrift | 9.5732782e-08 |
| Off-Center Drama / lips / clippedFraction | 0 |
| Off-Center Drama / lips / inputClippedFraction | 0 |
| Off-Center Drama / lips / newClippedFraction | 0 |
| Off-Center Drama / lips / shadowRMS | 0.028775803 |
| Off-Center Drama / skin / chromaticityDrift | 8.4067889e-08 |
| Off-Center Drama / skin / clippedFraction | 0 |
| Off-Center Drama / skin / inputClippedFraction | 0 |
| Off-Center Drama / skin / newClippedFraction | 0 |
| Off-Center Drama / skin / shadowRMS | 0.018527448 |
| Off-Center Drama / transition / chromaticityDrift | 7.3158853e-08 |
| Off-Center Drama / transition / clippedFraction | 0 |
| Off-Center Drama / transition / inputClippedFraction | 0 |
| Off-Center Drama / transition / newClippedFraction | 0 |
| Off-Center Drama / transition / shadowRMS | 0.011009845 |
| Portrait Focus / bright background / chromaticityDrift | 6.7517402e-08 |
| Portrait Focus / bright background / clippedFraction | 0 |
| Portrait Focus / bright background / inputClippedFraction | 0 |
| Portrait Focus / bright background / newClippedFraction | 0 |
| Portrait Focus / bright background / shadowRMS | 0 |
| Portrait Focus / eye / chromaticityDrift | 8.2228774e-08 |
| Portrait Focus / eye / clippedFraction | 0 |
| Portrait Focus / eye / inputClippedFraction | 0 |
| Portrait Focus / eye / newClippedFraction | 0 |
| Portrait Focus / eye / shadowRMS | 0.028184159 |
| Portrait Focus / hair / chromaticityDrift | 7.1665748e-08 |
| Portrait Focus / hair / clippedFraction | 0 |
| Portrait Focus / hair / inputClippedFraction | 0 |
| Portrait Focus / hair / newClippedFraction | 0 |
| Portrait Focus / hair / shadowRMS | 0.02129361 |
| Portrait Focus / lips / chromaticityDrift | 9.1878615e-08 |
| Portrait Focus / lips / clippedFraction | 0 |
| Portrait Focus / lips / inputClippedFraction | 0 |
| Portrait Focus / lips / newClippedFraction | 0 |
| Portrait Focus / lips / shadowRMS | 0.027928933 |
| Portrait Focus / skin / chromaticityDrift | 9.1739883e-08 |
| Portrait Focus / skin / clippedFraction | 0 |
| Portrait Focus / skin / inputClippedFraction | 0 |
| Portrait Focus / skin / newClippedFraction | 0 |
| Portrait Focus / skin / shadowRMS | 0.017278366 |
| Portrait Focus / transition / chromaticityDrift | 6.8810126e-08 |
| Portrait Focus / transition / clippedFraction | 0 |
| Portrait Focus / transition / inputClippedFraction | 0 |
| Portrait Focus / transition / newClippedFraction | 0 |
| Portrait Focus / transition / shadowRMS | 0.01402911 |
| Reverse Focus / bright background / chromaticityDrift | 5.5338941e-08 |
| Reverse Focus / bright background / clippedFraction | 0.98681641 |
| Reverse Focus / bright background / inputClippedFraction | 0 |
| Reverse Focus / bright background / newClippedFraction | 0.98681641 |
| Reverse Focus / bright background / shadowRMS | 0 |
| Reverse Focus / eye / chromaticityDrift | 8.0125214e-08 |
| Reverse Focus / eye / clippedFraction | 0 |
| Reverse Focus / eye / inputClippedFraction | 0 |
| Reverse Focus / eye / newClippedFraction | 0 |
| Reverse Focus / eye / shadowRMS | 0.01775605 |
| Reverse Focus / hair / chromaticityDrift | 6.9737938e-08 |
| Reverse Focus / hair / clippedFraction | 0 |
| Reverse Focus / hair / inputClippedFraction | 0 |
| Reverse Focus / hair / newClippedFraction | 0 |
| Reverse Focus / hair / shadowRMS | 0.025101666 |
| Reverse Focus / lips / chromaticityDrift | 9.6226243e-08 |
| Reverse Focus / lips / clippedFraction | 0 |
| Reverse Focus / lips / inputClippedFraction | 0 |
| Reverse Focus / lips / newClippedFraction | 0 |
| Reverse Focus / lips / shadowRMS | 0.019260922 |
| Reverse Focus / skin / chromaticityDrift | 8.1449745e-08 |
| Reverse Focus / skin / clippedFraction | 0 |
| Reverse Focus / skin / inputClippedFraction | 0 |
| Reverse Focus / skin / newClippedFraction | 0 |
| Reverse Focus / skin / shadowRMS | 0.010639554 |
| Reverse Focus / transition / chromaticityDrift | 6.5864833e-08 |
| Reverse Focus / transition / clippedFraction | 0.074462891 |
| Reverse Focus / transition / inputClippedFraction | 0 |
| Reverse Focus / transition / newClippedFraction | 0.074462891 |
| Reverse Focus / transition / shadowRMS | 0.022994446 |
| Subtle Focus / bright background / chromaticityDrift | 6.4691416e-08 |
| Subtle Focus / bright background / clippedFraction | 0 |
| Subtle Focus / bright background / inputClippedFraction | 0 |
| Subtle Focus / bright background / newClippedFraction | 0 |
| Subtle Focus / bright background / shadowRMS | 0 |
| Subtle Focus / eye / chromaticityDrift | 8.0926203e-08 |
| Subtle Focus / eye / clippedFraction | 0 |
| Subtle Focus / eye / inputClippedFraction | 0 |
| Subtle Focus / eye / newClippedFraction | 0 |
| Subtle Focus / eye / shadowRMS | 0.025002768 |
| Subtle Focus / hair / chromaticityDrift | 8.4841241e-08 |
| Subtle Focus / hair / clippedFraction | 0 |
| Subtle Focus / hair / inputClippedFraction | 0 |
| Subtle Focus / hair / newClippedFraction | 0 |
| Subtle Focus / hair / shadowRMS | 0.024245185 |
| Subtle Focus / lips / chromaticityDrift | 9.198162e-08 |
| Subtle Focus / lips / clippedFraction | 0 |
| Subtle Focus / lips / inputClippedFraction | 0 |
| Subtle Focus / lips / newClippedFraction | 0 |
| Subtle Focus / lips / shadowRMS | 0.025733359 |
| Subtle Focus / skin / chromaticityDrift | 8.5272456e-08 |
| Subtle Focus / skin / clippedFraction | 0 |
| Subtle Focus / skin / inputClippedFraction | 0 |
| Subtle Focus / skin / newClippedFraction | 0 |
| Subtle Focus / skin / shadowRMS | 0.015253682 |
| Subtle Focus / transition / chromaticityDrift | 6.6933434e-08 |
| Subtle Focus / transition / clippedFraction | 0 |
| Subtle Focus / transition / inputClippedFraction | 0 |
| Subtle Focus / transition / newClippedFraction | 0 |
| Subtle Focus / transition / shadowRMS | 0.017656258 |
| Wide Focus / bright background / chromaticityDrift | 6.3867498e-08 |
| Wide Focus / bright background / clippedFraction | 0 |
| Wide Focus / bright background / inputClippedFraction | 0 |
| Wide Focus / bright background / newClippedFraction | 0 |
| Wide Focus / bright background / shadowRMS | 0 |
| Wide Focus / eye / chromaticityDrift | 7.7595245e-08 |
| Wide Focus / eye / clippedFraction | 0 |
| Wide Focus / eye / inputClippedFraction | 0 |
| Wide Focus / eye / newClippedFraction | 0 |
| Wide Focus / eye / shadowRMS | 0.025866525 |
| Wide Focus / hair / chromaticityDrift | 7.3887612e-08 |
| Wide Focus / hair / clippedFraction | 0 |
| Wide Focus / hair / inputClippedFraction | 0 |
| Wide Focus / hair / newClippedFraction | 0 |
| Wide Focus / hair / shadowRMS | 0.02288339 |
| Wide Focus / lips / chromaticityDrift | 8.7356011e-08 |
| Wide Focus / lips / clippedFraction | 0 |
| Wide Focus / lips / inputClippedFraction | 0 |
| Wide Focus / lips / newClippedFraction | 0 |
| Wide Focus / lips / shadowRMS | 0.026370878 |
| Wide Focus / skin / chromaticityDrift | 8.4972935e-08 |
| Wide Focus / skin / clippedFraction | 0 |
| Wide Focus / skin / inputClippedFraction | 0 |
| Wide Focus / skin / newClippedFraction | 0 |
| Wide Focus / skin / shadowRMS | 0.015900851 |
| Wide Focus / transition / chromaticityDrift | 6.9387568e-08 |
| Wide Focus / transition / clippedFraction | 0 |
| Wide Focus / transition / inputClippedFraction | 0 |
| Wide Focus / transition / newClippedFraction | 0 |
| Wide Focus / transition / shadowRMS | 0.018648537 |

Fixed top-left subject coordinates: (0.37, 0.45). Native ROIs use lower-left image coordinates. No face detection or automated subject placement.

### DLC_photo_portrait_dark — WARN

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Subtle Focus finite | hard invariant | PASS | Full-frame float sample |
| Subtle Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Subtle Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / eyes hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / dark clothing hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus finite | hard invariant | PASS | Full-frame float sample |
| Portrait Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Portrait Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / eyes hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / dark clothing hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround finite | hard invariant | PASS | Full-frame float sample |
| Dark Surround new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Dark Surround / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / eyes hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / dark clothing hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center finite | hard invariant | PASS | Full-frame float sample |
| Light Center new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Light Center / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / eyes hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / dark clothing hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus finite | hard invariant | PASS | Full-frame float sample |
| Wide Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Wide Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / eyes hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / dark clothing hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus finite | hard invariant | PASS | Full-frame float sample |
| Narrow Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Narrow Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / eyes hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / dark clothing hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama finite | hard invariant | PASS | Full-frame float sample |
| Off-Center Drama new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Off-Center Drama / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / eyes hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / dark clothing hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus finite | hard invariant | PASS | Full-frame float sample |
| Reverse Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Reverse Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / eyes hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / dark clothing hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / background hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Source unchanged | hard invariant | PASS | Original SHA256 before/after |

| Mesure | Valeur |
|---|---:|
| Dark Surround / background / chromaticityDrift | 6.9547195e-08 |
| Dark Surround / background / clippedFraction | 0 |
| Dark Surround / background / inputClippedFraction | 0 |
| Dark Surround / background / newClippedFraction | 0 |
| Dark Surround / background / shadowRMS | 0.0070930164 |
| Dark Surround / dark clothing / chromaticityDrift | 6.668804e-08 |
| Dark Surround / dark clothing / clippedFraction | 0 |
| Dark Surround / dark clothing / inputClippedFraction | 0 |
| Dark Surround / dark clothing / newClippedFraction | 0 |
| Dark Surround / dark clothing / shadowRMS | 0.001335666 |
| Dark Surround / eyes / chromaticityDrift | 8.3417976e-08 |
| Dark Surround / eyes / clippedFraction | 0 |
| Dark Surround / eyes / inputClippedFraction | 0 |
| Dark Surround / eyes / newClippedFraction | 0 |
| Dark Surround / eyes / shadowRMS | 0.027237117 |
| Dark Surround / hair / chromaticityDrift | 6.62757e-08 |
| Dark Surround / hair / clippedFraction | 0 |
| Dark Surround / hair / inputClippedFraction | 0 |
| Dark Surround / hair / newClippedFraction | 0 |
| Dark Surround / hair / shadowRMS | 0.004987102 |
| Dark Surround / skin / chromaticityDrift | 9.211266e-08 |
| Dark Surround / skin / clippedFraction | 0 |
| Dark Surround / skin / inputClippedFraction | 0 |
| Dark Surround / skin / newClippedFraction | 0 |
| Dark Surround / skin / shadowRMS | 0.017085618 |
| Dark Surround / transition / chromaticityDrift | 6.3389358e-08 |
| Dark Surround / transition / clippedFraction | 0 |
| Dark Surround / transition / inputClippedFraction | 0 |
| Dark Surround / transition / newClippedFraction | 0 |
| Dark Surround / transition / shadowRMS | 0.0071611527 |
| Light Center / background / chromaticityDrift | 0 |
| Light Center / background / clippedFraction | 0 |
| Light Center / background / inputClippedFraction | 0 |
| Light Center / background / newClippedFraction | 0 |
| Light Center / background / shadowRMS | 0.012788318 |
| Light Center / dark clothing / chromaticityDrift | 3.1772844e-08 |
| Light Center / dark clothing / clippedFraction | 0 |
| Light Center / dark clothing / inputClippedFraction | 0 |
| Light Center / dark clothing / newClippedFraction | 0 |
| Light Center / dark clothing / shadowRMS | 0.0024018575 |
| Light Center / eyes / chromaticityDrift | 9.7557035e-08 |
| Light Center / eyes / clippedFraction | 0 |
| Light Center / eyes / inputClippedFraction | 0 |
| Light Center / eyes / newClippedFraction | 0 |
| Light Center / eyes / shadowRMS | 0.039632815 |
| Light Center / hair / chromaticityDrift | 7.7387311e-08 |
| Light Center / hair / clippedFraction | 0 |
| Light Center / hair / inputClippedFraction | 0 |
| Light Center / hair / newClippedFraction | 0 |
| Light Center / hair / shadowRMS | 0.0072173882 |
| Light Center / skin / chromaticityDrift | 9.5971945e-08 |
| Light Center / skin / clippedFraction | 0 |
| Light Center / skin / inputClippedFraction | 0 |
| Light Center / skin / newClippedFraction | 0 |
| Light Center / skin / shadowRMS | 0.024967501 |
| Light Center / transition / chromaticityDrift | 7.7387311e-08 |
| Light Center / transition / clippedFraction | 0 |
| Light Center / transition / inputClippedFraction | 0 |
| Light Center / transition / newClippedFraction | 0 |
| Light Center / transition / shadowRMS | 0.011682573 |
| Narrow Focus / background / chromaticityDrift | 6.1649946e-08 |
| Narrow Focus / background / clippedFraction | 0 |
| Narrow Focus / background / inputClippedFraction | 0 |
| Narrow Focus / background / newClippedFraction | 0 |
| Narrow Focus / background / shadowRMS | 0.0087346788 |
| Narrow Focus / dark clothing / chromaticityDrift | 6.0324033e-08 |
| Narrow Focus / dark clothing / clippedFraction | 0 |
| Narrow Focus / dark clothing / inputClippedFraction | 0 |
| Narrow Focus / dark clothing / newClippedFraction | 0 |
| Narrow Focus / dark clothing / shadowRMS | 0.001640517 |
| Narrow Focus / eyes / chromaticityDrift | 8.895335e-08 |
| Narrow Focus / eyes / clippedFraction | 0 |
| Narrow Focus / eyes / inputClippedFraction | 0 |
| Narrow Focus / eyes / newClippedFraction | 0 |
| Narrow Focus / eyes / shadowRMS | 0.034702272 |
| Narrow Focus / hair / chromaticityDrift | 6.509434e-08 |
| Narrow Focus / hair / clippedFraction | 0 |
| Narrow Focus / hair / inputClippedFraction | 0 |
| Narrow Focus / hair / newClippedFraction | 0 |
| Narrow Focus / hair / shadowRMS | 0.0042842191 |
| Narrow Focus / skin / chromaticityDrift | 9.3810693e-08 |
| Narrow Focus / skin / clippedFraction | 0 |
| Narrow Focus / skin / inputClippedFraction | 0 |
| Narrow Focus / skin / newClippedFraction | 0 |
| Narrow Focus / skin / shadowRMS | 0.022325768 |
| Narrow Focus / transition / chromaticityDrift | 6.0324033e-08 |
| Narrow Focus / transition / clippedFraction | 0 |
| Narrow Focus / transition / inputClippedFraction | 0 |
| Narrow Focus / transition / newClippedFraction | 0 |
| Narrow Focus / transition / shadowRMS | 0.0079556056 |
| Off-Center Drama / background / chromaticityDrift | 5.6937269e-08 |
| Off-Center Drama / background / clippedFraction | 0 |
| Off-Center Drama / background / inputClippedFraction | 0 |
| Off-Center Drama / background / newClippedFraction | 0 |
| Off-Center Drama / background / shadowRMS | 0.00734496 |
| Off-Center Drama / dark clothing / chromaticityDrift | 6.8513283e-08 |
| Off-Center Drama / dark clothing / clippedFraction | 0 |
| Off-Center Drama / dark clothing / inputClippedFraction | 0 |
| Off-Center Drama / dark clothing / newClippedFraction | 0 |
| Off-Center Drama / dark clothing / shadowRMS | 0.001380637 |
| Off-Center Drama / eyes / chromaticityDrift | 8.6315539e-08 |
| Off-Center Drama / eyes / clippedFraction | 0 |
| Off-Center Drama / eyes / inputClippedFraction | 0 |
| Off-Center Drama / eyes / newClippedFraction | 0 |
| Off-Center Drama / eyes / shadowRMS | 0.035744121 |
| Off-Center Drama / hair / chromaticityDrift | 7.1616341e-08 |
| Off-Center Drama / hair / clippedFraction | 0 |
| Off-Center Drama / hair / inputClippedFraction | 0 |
| Off-Center Drama / hair / newClippedFraction | 0 |
| Off-Center Drama / hair / shadowRMS | 0.0052031574 |
| Off-Center Drama / skin / chromaticityDrift | 9.9944818e-08 |
| Off-Center Drama / skin / clippedFraction | 0 |
| Off-Center Drama / skin / inputClippedFraction | 0 |
| Off-Center Drama / skin / newClippedFraction | 0 |
| Off-Center Drama / skin / shadowRMS | 0.022527124 |
| Off-Center Drama / transition / chromaticityDrift | 7.0802107e-08 |
| Off-Center Drama / transition / clippedFraction | 0 |
| Off-Center Drama / transition / inputClippedFraction | 0 |
| Off-Center Drama / transition / newClippedFraction | 0 |
| Off-Center Drama / transition / shadowRMS | 0.0067613706 |
| Portrait Focus / background / chromaticityDrift | 6.2454872e-08 |
| Portrait Focus / background / clippedFraction | 0 |
| Portrait Focus / background / inputClippedFraction | 0 |
| Portrait Focus / background / newClippedFraction | 0 |
| Portrait Focus / background / shadowRMS | 0.0093615963 |
| Portrait Focus / dark clothing / chromaticityDrift | 6.5941697e-08 |
| Portrait Focus / dark clothing / clippedFraction | 0 |
| Portrait Focus / dark clothing / inputClippedFraction | 0 |
| Portrait Focus / dark clothing / newClippedFraction | 0 |
| Portrait Focus / dark clothing / shadowRMS | 0.0017582625 |
| Portrait Focus / eyes / chromaticityDrift | 8.6884066e-08 |
| Portrait Focus / eyes / clippedFraction | 0 |
| Portrait Focus / eyes / inputClippedFraction | 0 |
| Portrait Focus / eyes / newClippedFraction | 0 |
| Portrait Focus / eyes / shadowRMS | 0.033694316 |
| Portrait Focus / hair / chromaticityDrift | 6.6263372e-08 |
| Portrait Focus / hair / clippedFraction | 0 |
| Portrait Focus / hair / inputClippedFraction | 0 |
| Portrait Focus / hair / newClippedFraction | 0 |
| Portrait Focus / hair / shadowRMS | 0.0050369122 |
| Portrait Focus / skin / chromaticityDrift | 9.2306829e-08 |
| Portrait Focus / skin / clippedFraction | 0 |
| Portrait Focus / skin / inputClippedFraction | 0 |
| Portrait Focus / skin / newClippedFraction | 0 |
| Portrait Focus / skin / shadowRMS | 0.021044035 |
| Portrait Focus / transition / chromaticityDrift | 6.54982e-08 |
| Portrait Focus / transition / clippedFraction | 0 |
| Portrait Focus / transition / inputClippedFraction | 0 |
| Portrait Focus / transition / newClippedFraction | 0 |
| Portrait Focus / transition / shadowRMS | 0.0085236275 |
| Reverse Focus / background / chromaticityDrift | 6.5620354e-08 |
| Reverse Focus / background / clippedFraction | 0 |
| Reverse Focus / background / inputClippedFraction | 0 |
| Reverse Focus / background / newClippedFraction | 0 |
| Reverse Focus / background / shadowRMS | 0.015207959 |
| Reverse Focus / dark clothing / chromaticityDrift | 6.7662032e-08 |
| Reverse Focus / dark clothing / clippedFraction | 0 |
| Reverse Focus / dark clothing / inputClippedFraction | 0 |
| Reverse Focus / dark clothing / newClippedFraction | 0 |
| Reverse Focus / dark clothing / shadowRMS | 0.0028563828 |
| Reverse Focus / eyes / chromaticityDrift | 8.6448894e-08 |
| Reverse Focus / eyes / clippedFraction | 0 |
| Reverse Focus / eyes / inputClippedFraction | 0 |
| Reverse Focus / eyes / newClippedFraction | 0 |
| Reverse Focus / eyes / shadowRMS | 0.021129747 |
| Reverse Focus / hair / chromaticityDrift | 6.3486811e-08 |
| Reverse Focus / hair / clippedFraction | 0 |
| Reverse Focus / hair / inputClippedFraction | 0 |
| Reverse Focus / hair / newClippedFraction | 0 |
| Reverse Focus / hair / shadowRMS | 0.0059689302 |
| Reverse Focus / skin / chromaticityDrift | 8.9853265e-08 |
| Reverse Focus / skin / clippedFraction | 0 |
| Reverse Focus / skin / inputClippedFraction | 0 |
| Reverse Focus / skin / newClippedFraction | 0 |
| Reverse Focus / skin / shadowRMS | 0.0129749 |
| Reverse Focus / transition / chromaticityDrift | 7.3066411e-08 |
| Reverse Focus / transition / clippedFraction | 0 |
| Reverse Focus / transition / inputClippedFraction | 0 |
| Reverse Focus / transition / newClippedFraction | 0 |
| Reverse Focus / transition / shadowRMS | 0.013340093 |
| Subtle Focus / background / chromaticityDrift | 6.2705027e-08 |
| Subtle Focus / background / clippedFraction | 0 |
| Subtle Focus / background / inputClippedFraction | 0 |
| Subtle Focus / background / newClippedFraction | 0 |
| Subtle Focus / background / shadowRMS | 0.011293299 |
| Subtle Focus / dark clothing / chromaticityDrift | 6.541362e-08 |
| Subtle Focus / dark clothing / clippedFraction | 0 |
| Subtle Focus / dark clothing / inputClippedFraction | 0 |
| Subtle Focus / dark clothing / newClippedFraction | 0 |
| Subtle Focus / dark clothing / shadowRMS | 0.0021406241 |
| Subtle Focus / eyes / chromaticityDrift | 8.4596524e-08 |
| Subtle Focus / eyes / clippedFraction | 0 |
| Subtle Focus / eyes / inputClippedFraction | 0 |
| Subtle Focus / eyes / newClippedFraction | 0 |
| Subtle Focus / eyes / shadowRMS | 0.029681417 |
| Subtle Focus / hair / chromaticityDrift | 6.7526777e-08 |
| Subtle Focus / hair / clippedFraction | 0 |
| Subtle Focus / hair / inputClippedFraction | 0 |
| Subtle Focus / hair / newClippedFraction | 0 |
| Subtle Focus / hair / shadowRMS | 0.0063283333 |
| Subtle Focus / skin / chromaticityDrift | 9.7388071e-08 |
| Subtle Focus / skin / clippedFraction | 0 |
| Subtle Focus / skin / inputClippedFraction | 0 |
| Subtle Focus / skin / newClippedFraction | 0 |
| Subtle Focus / skin / shadowRMS | 0.018526001 |
| Subtle Focus / transition / chromaticityDrift | 6.6120012e-08 |
| Subtle Focus / transition / clippedFraction | 0 |
| Subtle Focus / transition / inputClippedFraction | 0 |
| Subtle Focus / transition / newClippedFraction | 0 |
| Subtle Focus / transition / shadowRMS | 0.010919261 |
| Wide Focus / background / chromaticityDrift | 6.3836513e-08 |
| Wide Focus / background / clippedFraction | 0 |
| Wide Focus / background / inputClippedFraction | 0 |
| Wide Focus / background / newClippedFraction | 0 |
| Wide Focus / background / shadowRMS | 0.011032039 |
| Wide Focus / dark clothing / chromaticityDrift | 7.7380557e-08 |
| Wide Focus / dark clothing / clippedFraction | 0 |
| Wide Focus / dark clothing / inputClippedFraction | 0 |
| Wide Focus / dark clothing / newClippedFraction | 0 |
| Wide Focus / dark clothing / shadowRMS | 0.0020053842 |
| Wide Focus / eyes / chromaticityDrift | 9.2167123e-08 |
| Wide Focus / eyes / clippedFraction | 0 |
| Wide Focus / eyes / inputClippedFraction | 0 |
| Wide Focus / eyes / newClippedFraction | 0 |
| Wide Focus / eyes / shadowRMS | 0.030523974 |
| Wide Focus / hair / chromaticityDrift | 6.7439167e-08 |
| Wide Focus / hair / clippedFraction | 0 |
| Wide Focus / hair / inputClippedFraction | 0 |
| Wide Focus / hair / newClippedFraction | 0 |
| Wide Focus / hair / shadowRMS | 0.0067205294 |
| Wide Focus / skin / chromaticityDrift | 9.9761448e-08 |
| Wide Focus / skin / clippedFraction | 0 |
| Wide Focus / skin / inputClippedFraction | 0 |
| Wide Focus / skin / newClippedFraction | 0 |
| Wide Focus / skin / shadowRMS | 0.019281141 |
| Wide Focus / transition / chromaticityDrift | 6.5346616e-08 |
| Wide Focus / transition / clippedFraction | 0 |
| Wide Focus / transition / inputClippedFraction | 0 |
| Wide Focus / transition / newClippedFraction | 0 |
| Wide Focus / transition / shadowRMS | 0.011659408 |

Fixed top-left subject coordinates: (0.45, 0.44). Native ROIs use lower-left image coordinates. No face detection or automated subject placement.

### DLC_photo_landscape — WARN

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Subtle Focus finite | hard invariant | PASS | Full-frame float sample |
| Subtle Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Subtle Focus / clouds hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / green landscape hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / rocks hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus finite | hard invariant | PASS | Full-frame float sample |
| Portrait Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Portrait Focus / clouds hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / green landscape hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / rocks hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround finite | hard invariant | PASS | Full-frame float sample |
| Dark Surround new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Dark Surround / clouds hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / green landscape hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / rocks hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center finite | hard invariant | PASS | Full-frame float sample |
| Light Center new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Light Center / clouds hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / green landscape hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / rocks hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus finite | hard invariant | PASS | Full-frame float sample |
| Wide Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Wide Focus / clouds hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / green landscape hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / rocks hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus finite | hard invariant | PASS | Full-frame float sample |
| Narrow Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Narrow Focus / clouds hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / green landscape hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / rocks hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama finite | hard invariant | PASS | Full-frame float sample |
| Off-Center Drama new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Off-Center Drama / clouds hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / green landscape hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / rocks hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus finite | hard invariant | PASS | Full-frame float sample |
| Reverse Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Reverse Focus / clouds hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / green landscape hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / rocks hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Source unchanged | hard invariant | PASS | Original SHA256 before/after |

| Mesure | Valeur |
|---|---:|
| Dark Surround / blue sky / chromaticityDrift | 5.7529957e-08 |
| Dark Surround / blue sky / clippedFraction | 0 |
| Dark Surround / blue sky / inputClippedFraction | 0 |
| Dark Surround / blue sky / newClippedFraction | 0 |
| Dark Surround / blue sky / shadowRMS | 0 |
| Dark Surround / clouds / chromaticityDrift | 6.7241192e-08 |
| Dark Surround / clouds / clippedFraction | 0 |
| Dark Surround / clouds / inputClippedFraction | 6.1035156e-05 |
| Dark Surround / clouds / newClippedFraction | 0 |
| Dark Surround / clouds / shadowRMS | 0.00387695 |
| Dark Surround / green landscape / chromaticityDrift | 7.3742362e-08 |
| Dark Surround / green landscape / clippedFraction | 0 |
| Dark Surround / green landscape / inputClippedFraction | 0 |
| Dark Surround / green landscape / newClippedFraction | 0 |
| Dark Surround / green landscape / shadowRMS | 0.021398368 |
| Dark Surround / rocks / chromaticityDrift | 9.7069858e-08 |
| Dark Surround / rocks / clippedFraction | 0 |
| Dark Surround / rocks / inputClippedFraction | 0.0013427734 |
| Dark Surround / rocks / newClippedFraction | 0 |
| Dark Surround / rocks / shadowRMS | 0.016675138 |
| Light Center / blue sky / chromaticityDrift | 0 |
| Light Center / blue sky / clippedFraction | 0 |
| Light Center / blue sky / inputClippedFraction | 0 |
| Light Center / blue sky / newClippedFraction | 0 |
| Light Center / blue sky / shadowRMS | 0 |
| Light Center / clouds / chromaticityDrift | 0 |
| Light Center / clouds / clippedFraction | 6.1035156e-05 |
| Light Center / clouds / inputClippedFraction | 6.1035156e-05 |
| Light Center / clouds / newClippedFraction | 0 |
| Light Center / clouds / shadowRMS | 0.0069882064 |
| Light Center / green landscape / chromaticityDrift | 7.7604205e-08 |
| Light Center / green landscape / clippedFraction | 0.00048828125 |
| Light Center / green landscape / inputClippedFraction | 0 |
| Light Center / green landscape / newClippedFraction | 0.00048828125 |
| Light Center / green landscape / shadowRMS | 0.031339027 |
| Light Center / rocks / chromaticityDrift | 8.6321168e-08 |
| Light Center / rocks / clippedFraction | 0.0013427734 |
| Light Center / rocks / inputClippedFraction | 0.0013427734 |
| Light Center / rocks / newClippedFraction | 0 |
| Light Center / rocks / shadowRMS | 0.028414348 |
| Narrow Focus / blue sky / chromaticityDrift | 4.6970075e-08 |
| Narrow Focus / blue sky / clippedFraction | 0 |
| Narrow Focus / blue sky / inputClippedFraction | 0 |
| Narrow Focus / blue sky / newClippedFraction | 0 |
| Narrow Focus / blue sky / shadowRMS | 0 |
| Narrow Focus / clouds / chromaticityDrift | 6.5782794e-08 |
| Narrow Focus / clouds / clippedFraction | 0 |
| Narrow Focus / clouds / inputClippedFraction | 6.1035156e-05 |
| Narrow Focus / clouds / newClippedFraction | 0 |
| Narrow Focus / clouds / shadowRMS | 0.0047730862 |
| Narrow Focus / green landscape / chromaticityDrift | 8.0074197e-08 |
| Narrow Focus / green landscape / clippedFraction | 0.00012207031 |
| Narrow Focus / green landscape / inputClippedFraction | 0 |
| Narrow Focus / green landscape / newClippedFraction | 0.00012207031 |
| Narrow Focus / green landscape / shadowRMS | 0.029070409 |
| Narrow Focus / rocks / chromaticityDrift | 8.3004047e-08 |
| Narrow Focus / rocks / clippedFraction | 0 |
| Narrow Focus / rocks / inputClippedFraction | 0.0013427734 |
| Narrow Focus / rocks / newClippedFraction | 0 |
| Narrow Focus / rocks / shadowRMS | 0.019368099 |
| Off-Center Drama / blue sky / chromaticityDrift | 5.7649785e-08 |
| Off-Center Drama / blue sky / clippedFraction | 0 |
| Off-Center Drama / blue sky / inputClippedFraction | 0 |
| Off-Center Drama / blue sky / newClippedFraction | 0 |
| Off-Center Drama / blue sky / shadowRMS | 0 |
| Off-Center Drama / clouds / chromaticityDrift | 6.7540407e-08 |
| Off-Center Drama / clouds / clippedFraction | 0 |
| Off-Center Drama / clouds / inputClippedFraction | 6.1035156e-05 |
| Off-Center Drama / clouds / newClippedFraction | 0 |
| Off-Center Drama / clouds / shadowRMS | 0.0040136707 |
| Off-Center Drama / green landscape / chromaticityDrift | 8.0907092e-08 |
| Off-Center Drama / green landscape / clippedFraction | 0.00012207031 |
| Off-Center Drama / green landscape / inputClippedFraction | 0 |
| Off-Center Drama / green landscape / newClippedFraction | 0.00012207031 |
| Off-Center Drama / green landscape / shadowRMS | 0.028258952 |
| Off-Center Drama / rocks / chromaticityDrift | 7.4873037e-08 |
| Off-Center Drama / rocks / clippedFraction | 0 |
| Off-Center Drama / rocks / inputClippedFraction | 0.0013427734 |
| Off-Center Drama / rocks / newClippedFraction | 0 |
| Off-Center Drama / rocks / shadowRMS | 0.016927348 |
| Portrait Focus / blue sky / chromaticityDrift | 4.2939069e-08 |
| Portrait Focus / blue sky / clippedFraction | 0 |
| Portrait Focus / blue sky / inputClippedFraction | 0 |
| Portrait Focus / blue sky / newClippedFraction | 0 |
| Portrait Focus / blue sky / shadowRMS | 0 |
| Portrait Focus / clouds / chromaticityDrift | 6.7568133e-08 |
| Portrait Focus / clouds / clippedFraction | 0 |
| Portrait Focus / clouds / inputClippedFraction | 6.1035156e-05 |
| Portrait Focus / clouds / newClippedFraction | 0 |
| Portrait Focus / clouds / shadowRMS | 0.0051156664 |
| Portrait Focus / green landscape / chromaticityDrift | 8.0218597e-08 |
| Portrait Focus / green landscape / clippedFraction | 0.00012207031 |
| Portrait Focus / green landscape / inputClippedFraction | 0 |
| Portrait Focus / green landscape / newClippedFraction | 0.00012207031 |
| Portrait Focus / green landscape / shadowRMS | 0.026322895 |
| Portrait Focus / rocks / chromaticityDrift | 8.0620998e-08 |
| Portrait Focus / rocks / clippedFraction | 0 |
| Portrait Focus / rocks / inputClippedFraction | 0.0013427734 |
| Portrait Focus / rocks / newClippedFraction | 0 |
| Portrait Focus / rocks / shadowRMS | 0.021284633 |
| Reverse Focus / blue sky / chromaticityDrift | 4.9567277e-08 |
| Reverse Focus / blue sky / clippedFraction | 0 |
| Reverse Focus / blue sky / inputClippedFraction | 0 |
| Reverse Focus / blue sky / newClippedFraction | 0 |
| Reverse Focus / blue sky / shadowRMS | 0 |
| Reverse Focus / clouds / chromaticityDrift | 6.1663969e-08 |
| Reverse Focus / clouds / clippedFraction | 0.0026245117 |
| Reverse Focus / clouds / inputClippedFraction | 6.1035156e-05 |
| Reverse Focus / clouds / newClippedFraction | 0.0025634766 |
| Reverse Focus / clouds / shadowRMS | 0.0083104248 |
| Reverse Focus / green landscape / chromaticityDrift | 8.1758598e-08 |
| Reverse Focus / green landscape / clippedFraction | 0 |
| Reverse Focus / green landscape / inputClippedFraction | 0 |
| Reverse Focus / green landscape / newClippedFraction | 0 |
| Reverse Focus / green landscape / shadowRMS | 0.016149888 |
| Reverse Focus / rocks / chromaticityDrift | 7.878863e-08 |
| Reverse Focus / rocks / clippedFraction | 0.010009766 |
| Reverse Focus / rocks / inputClippedFraction | 0.0013427734 |
| Reverse Focus / rocks / newClippedFraction | 0.0086669922 |
| Reverse Focus / rocks / shadowRMS | 0.033121248 |
| Subtle Focus / blue sky / chromaticityDrift | 6.3175967e-08 |
| Subtle Focus / blue sky / clippedFraction | 0 |
| Subtle Focus / blue sky / inputClippedFraction | 0 |
| Subtle Focus / blue sky / newClippedFraction | 0 |
| Subtle Focus / blue sky / shadowRMS | 0 |
| Subtle Focus / clouds / chromaticityDrift | 6.1140547e-08 |
| Subtle Focus / clouds / clippedFraction | 0 |
| Subtle Focus / clouds / inputClippedFraction | 6.1035156e-05 |
| Subtle Focus / clouds / newClippedFraction | 0 |
| Subtle Focus / clouds / shadowRMS | 0.0061685112 |
| Subtle Focus / green landscape / chromaticityDrift | 7.1731877e-08 |
| Subtle Focus / green landscape / clippedFraction | 0 |
| Subtle Focus / green landscape / inputClippedFraction | 0 |
| Subtle Focus / green landscape / newClippedFraction | 0 |
| Subtle Focus / green landscape / shadowRMS | 0.023197325 |
| Subtle Focus / rocks / chromaticityDrift | 9.3561566e-08 |
| Subtle Focus / rocks / clippedFraction | 0 |
| Subtle Focus / rocks / inputClippedFraction | 0.0013427734 |
| Subtle Focus / rocks / newClippedFraction | 0 |
| Subtle Focus / rocks / shadowRMS | 0.026092292 |
| Wide Focus / blue sky / chromaticityDrift | 6.2020448e-08 |
| Wide Focus / blue sky / clippedFraction | 0 |
| Wide Focus / blue sky / inputClippedFraction | 0 |
| Wide Focus / blue sky / newClippedFraction | 0 |
| Wide Focus / blue sky / shadowRMS | 0 |
| Wide Focus / clouds / chromaticityDrift | 6.3513504e-08 |
| Wide Focus / clouds / clippedFraction | 0 |
| Wide Focus / clouds / inputClippedFraction | 6.1035156e-05 |
| Wide Focus / clouds / newClippedFraction | 0 |
| Wide Focus / clouds / shadowRMS | 0.0056761866 |
| Wide Focus / green landscape / chromaticityDrift | 8.2525453e-08 |
| Wide Focus / green landscape / clippedFraction | 0 |
| Wide Focus / green landscape / inputClippedFraction | 0 |
| Wide Focus / green landscape / newClippedFraction | 0 |
| Wide Focus / green landscape / shadowRMS | 0.024187864 |
| Wide Focus / rocks / chromaticityDrift | 7.5819339e-08 |
| Wide Focus / rocks / clippedFraction | 0 |
| Wide Focus / rocks / inputClippedFraction | 0.0013427734 |
| Wide Focus / rocks / newClippedFraction | 0 |
| Wide Focus / rocks / shadowRMS | 0.023409136 |

Fixed top-left subject coordinates: (0.5, 0.65). Native ROIs use lower-left image coordinates. No face detection or automated subject placement.

### DLC_photo_backlight — WARN

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Subtle Focus finite | hard invariant | PASS | Full-frame float sample |
| Subtle Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Subtle Focus / sun hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / face hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / sea reflection hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / shoulder hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus finite | hard invariant | PASS | Full-frame float sample |
| Portrait Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Portrait Focus / sun hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / face hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / sea reflection hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / shoulder hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround finite | hard invariant | PASS | Full-frame float sample |
| Dark Surround new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Dark Surround / sun hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / face hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / sea reflection hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / shoulder hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center finite | hard invariant | PASS | Full-frame float sample |
| Light Center new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Light Center / sun hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / face hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / sea reflection hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / shoulder hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus finite | hard invariant | PASS | Full-frame float sample |
| Wide Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Wide Focus / sun hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / face hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / sea reflection hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / shoulder hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus finite | hard invariant | PASS | Full-frame float sample |
| Narrow Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Narrow Focus / sun hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / face hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / sea reflection hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / shoulder hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama finite | hard invariant | PASS | Full-frame float sample |
| Off-Center Drama new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Off-Center Drama / sun hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / face hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / sea reflection hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / shoulder hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus finite | hard invariant | PASS | Full-frame float sample |
| Reverse Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Reverse Focus / sun hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / face hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / sea reflection hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / shoulder hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Source unchanged | hard invariant | PASS | Original SHA256 before/after |

| Mesure | Valeur |
|---|---:|
| Dark Surround / face / chromaticityDrift | 9.1890927e-08 |
| Dark Surround / face / clippedFraction | 0 |
| Dark Surround / face / inputClippedFraction | 0 |
| Dark Surround / face / newClippedFraction | 0 |
| Dark Surround / face / shadowRMS | 0.017881007 |
| Dark Surround / hair / chromaticityDrift | 8.5934985e-08 |
| Dark Surround / hair / clippedFraction | 0 |
| Dark Surround / hair / inputClippedFraction | 0 |
| Dark Surround / hair / newClippedFraction | 0 |
| Dark Surround / hair / shadowRMS | 0.0045892814 |
| Dark Surround / sea reflection / chromaticityDrift | 1.0428518e-07 |
| Dark Surround / sea reflection / clippedFraction | 0 |
| Dark Surround / sea reflection / inputClippedFraction | 0.15319824 |
| Dark Surround / sea reflection / newClippedFraction | 0 |
| Dark Surround / sea reflection / shadowRMS | 0 |
| Dark Surround / shoulder / chromaticityDrift | 9.9220821e-08 |
| Dark Surround / shoulder / clippedFraction | 0 |
| Dark Surround / shoulder / inputClippedFraction | 0 |
| Dark Surround / shoulder / newClippedFraction | 0 |
| Dark Surround / shoulder / shadowRMS | 0.0062701576 |
| Dark Surround / sun / chromaticityDrift | 5.8101959e-08 |
| Dark Surround / sun / clippedFraction | 0 |
| Dark Surround / sun / inputClippedFraction | 0.073303223 |
| Dark Surround / sun / newClippedFraction | 0 |
| Dark Surround / sun / shadowRMS | 0 |
| Light Center / face / chromaticityDrift | 1.0410204e-07 |
| Light Center / face / clippedFraction | 0 |
| Light Center / face / inputClippedFraction | 0 |
| Light Center / face / newClippedFraction | 0 |
| Light Center / face / shadowRMS | 0.0258465 |
| Light Center / hair / chromaticityDrift | 9.0288917e-08 |
| Light Center / hair / clippedFraction | 0 |
| Light Center / hair / inputClippedFraction | 0 |
| Light Center / hair / newClippedFraction | 0 |
| Light Center / hair / shadowRMS | 0.006702048 |
| Light Center / sea reflection / chromaticityDrift | 1.0483629e-07 |
| Light Center / sea reflection / clippedFraction | 0.85229492 |
| Light Center / sea reflection / inputClippedFraction | 0.15319824 |
| Light Center / sea reflection / newClippedFraction | 0.69909668 |
| Light Center / sea reflection / shadowRMS | 0 |
| Light Center / shoulder / chromaticityDrift | 9.597731e-08 |
| Light Center / shoulder / clippedFraction | 0 |
| Light Center / shoulder / inputClippedFraction | 0 |
| Light Center / shoulder / newClippedFraction | 0 |
| Light Center / shoulder / shadowRMS | 0.0089757976 |
| Light Center / sun / chromaticityDrift | 6.1949341e-08 |
| Light Center / sun / clippedFraction | 1 |
| Light Center / sun / inputClippedFraction | 0.073303223 |
| Light Center / sun / newClippedFraction | 0.92669678 |
| Light Center / sun / shadowRMS | 0 |
| Narrow Focus / face / chromaticityDrift | 9.6758653e-08 |
| Narrow Focus / face / clippedFraction | 0 |
| Narrow Focus / face / inputClippedFraction | 0 |
| Narrow Focus / face / newClippedFraction | 0 |
| Narrow Focus / face / shadowRMS | 0.020797535 |
| Narrow Focus / hair / chromaticityDrift | 9.2231518e-08 |
| Narrow Focus / hair / clippedFraction | 0 |
| Narrow Focus / hair / inputClippedFraction | 0 |
| Narrow Focus / hair / newClippedFraction | 0 |
| Narrow Focus / hair / shadowRMS | 0.0058183021 |
| Narrow Focus / sea reflection / chromaticityDrift | 9.0446492e-08 |
| Narrow Focus / sea reflection / clippedFraction | 0 |
| Narrow Focus / sea reflection / inputClippedFraction | 0.15319824 |
| Narrow Focus / sea reflection / newClippedFraction | 0 |
| Narrow Focus / sea reflection / shadowRMS | 0 |
| Narrow Focus / shoulder / chromaticityDrift | 9.1249505e-08 |
| Narrow Focus / shoulder / clippedFraction | 0 |
| Narrow Focus / shoulder / inputClippedFraction | 0 |
| Narrow Focus / shoulder / newClippedFraction | 0 |
| Narrow Focus / shoulder / shadowRMS | 0.0066678028 |
| Narrow Focus / sun / chromaticityDrift | 5.8131011e-08 |
| Narrow Focus / sun / clippedFraction | 0 |
| Narrow Focus / sun / inputClippedFraction | 0.073303223 |
| Narrow Focus / sun / newClippedFraction | 0 |
| Narrow Focus / sun / shadowRMS | 0 |
| Off-Center Drama / face / chromaticityDrift | 9.9092788e-08 |
| Off-Center Drama / face / clippedFraction | 0 |
| Off-Center Drama / face / inputClippedFraction | 0 |
| Off-Center Drama / face / newClippedFraction | 0 |
| Off-Center Drama / face / shadowRMS | 0.022475305 |
| Off-Center Drama / hair / chromaticityDrift | 8.8323328e-08 |
| Off-Center Drama / hair / clippedFraction | 0 |
| Off-Center Drama / hair / inputClippedFraction | 0 |
| Off-Center Drama / hair / newClippedFraction | 0 |
| Off-Center Drama / hair / shadowRMS | 0.0061323038 |
| Off-Center Drama / sea reflection / chromaticityDrift | 1.2451686e-07 |
| Off-Center Drama / sea reflection / clippedFraction | 0 |
| Off-Center Drama / sea reflection / inputClippedFraction | 0.15319824 |
| Off-Center Drama / sea reflection / newClippedFraction | 0 |
| Off-Center Drama / sea reflection / shadowRMS | 0 |
| Off-Center Drama / shoulder / chromaticityDrift | 9.895463e-08 |
| Off-Center Drama / shoulder / clippedFraction | 0 |
| Off-Center Drama / shoulder / inputClippedFraction | 0 |
| Off-Center Drama / shoulder / newClippedFraction | 0 |
| Off-Center Drama / shoulder / shadowRMS | 0.0085432765 |
| Off-Center Drama / sun / chromaticityDrift | 5.6738297e-08 |
| Off-Center Drama / sun / clippedFraction | 0.010681152 |
| Off-Center Drama / sun / inputClippedFraction | 0.073303223 |
| Off-Center Drama / sun / newClippedFraction | 0.010009766 |
| Off-Center Drama / sun / shadowRMS | 0 |
| Portrait Focus / face / chromaticityDrift | 9.7862234e-08 |
| Portrait Focus / face / clippedFraction | 0 |
| Portrait Focus / face / inputClippedFraction | 0 |
| Portrait Focus / face / newClippedFraction | 0 |
| Portrait Focus / face / shadowRMS | 0.021759904 |
| Portrait Focus / hair / chromaticityDrift | 8.9012082e-08 |
| Portrait Focus / hair / clippedFraction | 0 |
| Portrait Focus / hair / inputClippedFraction | 0 |
| Portrait Focus / hair / newClippedFraction | 0 |
| Portrait Focus / hair / shadowRMS | 0.0058172689 |
| Portrait Focus / sea reflection / chromaticityDrift | 1.0250941e-07 |
| Portrait Focus / sea reflection / clippedFraction | 0 |
| Portrait Focus / sea reflection / inputClippedFraction | 0.15319824 |
| Portrait Focus / sea reflection / newClippedFraction | 0 |
| Portrait Focus / sea reflection / shadowRMS | 0 |
| Portrait Focus / shoulder / chromaticityDrift | 1.0168495e-07 |
| Portrait Focus / shoulder / clippedFraction | 0 |
| Portrait Focus / shoulder / inputClippedFraction | 0 |
| Portrait Focus / shoulder / newClippedFraction | 0 |
| Portrait Focus / shoulder / shadowRMS | 0.0073913074 |
| Portrait Focus / sun / chromaticityDrift | 5.6063276e-08 |
| Portrait Focus / sun / clippedFraction | 0.0014038086 |
| Portrait Focus / sun / inputClippedFraction | 0.073303223 |
| Portrait Focus / sun / newClippedFraction | 0.001159668 |
| Portrait Focus / sun / shadowRMS | 0 |
| Reverse Focus / face / chromaticityDrift | 9.9032439e-08 |
| Reverse Focus / face / clippedFraction | 0 |
| Reverse Focus / face / inputClippedFraction | 0 |
| Reverse Focus / face / newClippedFraction | 0 |
| Reverse Focus / face / shadowRMS | 0.014820552 |
| Reverse Focus / hair / chromaticityDrift | 8.3564296e-08 |
| Reverse Focus / hair / clippedFraction | 0 |
| Reverse Focus / hair / inputClippedFraction | 0 |
| Reverse Focus / hair / newClippedFraction | 0 |
| Reverse Focus / hair / shadowRMS | 0.0033962026 |
| Reverse Focus / sea reflection / chromaticityDrift | 1.154817e-07 |
| Reverse Focus / sea reflection / clippedFraction | 0.48431396 |
| Reverse Focus / sea reflection / inputClippedFraction | 0.15319824 |
| Reverse Focus / sea reflection / newClippedFraction | 0.39251709 |
| Reverse Focus / sea reflection / shadowRMS | 0 |
| Reverse Focus / shoulder / chromaticityDrift | 9.716854e-08 |
| Reverse Focus / shoulder / clippedFraction | 0 |
| Reverse Focus / shoulder / inputClippedFraction | 0 |
| Reverse Focus / shoulder / newClippedFraction | 0 |
| Reverse Focus / shoulder / shadowRMS | 0.0052352058 |
| Reverse Focus / sun / chromaticityDrift | 6.2126863e-08 |
| Reverse Focus / sun / clippedFraction | 0.13122559 |
| Reverse Focus / sun / inputClippedFraction | 0.073303223 |
| Reverse Focus / sun / newClippedFraction | 0.12304688 |
| Reverse Focus / sun / shadowRMS | 0 |
| Subtle Focus / face / chromaticityDrift | 1.0629886e-07 |
| Subtle Focus / face / clippedFraction | 0 |
| Subtle Focus / face / inputClippedFraction | 0 |
| Subtle Focus / face / newClippedFraction | 0 |
| Subtle Focus / face / shadowRMS | 0.019691676 |
| Subtle Focus / hair / chromaticityDrift | 8.8944116e-08 |
| Subtle Focus / hair / clippedFraction | 0 |
| Subtle Focus / hair / inputClippedFraction | 0 |
| Subtle Focus / hair / newClippedFraction | 0 |
| Subtle Focus / hair / shadowRMS | 0.0049219038 |
| Subtle Focus / sea reflection / chromaticityDrift | 9.7738875e-08 |
| Subtle Focus / sea reflection / clippedFraction | 0.12384033 |
| Subtle Focus / sea reflection / inputClippedFraction | 0.15319824 |
| Subtle Focus / sea reflection / newClippedFraction | 0.088012695 |
| Subtle Focus / sea reflection / shadowRMS | 0 |
| Subtle Focus / shoulder / chromaticityDrift | 1.0655774e-07 |
| Subtle Focus / shoulder / clippedFraction | 0 |
| Subtle Focus / shoulder / inputClippedFraction | 0 |
| Subtle Focus / shoulder / newClippedFraction | 0 |
| Subtle Focus / shoulder / shadowRMS | 0.0067230395 |
| Subtle Focus / sun / chromaticityDrift | 6.581577e-08 |
| Subtle Focus / sun / clippedFraction | 0.512146 |
| Subtle Focus / sun / inputClippedFraction | 0.073303223 |
| Subtle Focus / sun / newClippedFraction | 0.46038818 |
| Subtle Focus / sun / shadowRMS | 0 |
| Wide Focus / face / chromaticityDrift | 1.0304787e-07 |
| Wide Focus / face / clippedFraction | 0 |
| Wide Focus / face / inputClippedFraction | 0 |
| Wide Focus / face / newClippedFraction | 0 |
| Wide Focus / face / shadowRMS | 0.020175894 |
| Wide Focus / hair / chromaticityDrift | 9.7955771e-08 |
| Wide Focus / hair / clippedFraction | 0 |
| Wide Focus / hair / inputClippedFraction | 0 |
| Wide Focus / hair / newClippedFraction | 0 |
| Wide Focus / hair / shadowRMS | 0.0050873105 |
| Wide Focus / sea reflection / chromaticityDrift | 1.1903825e-07 |
| Wide Focus / sea reflection / clippedFraction | 0.36273193 |
| Wide Focus / sea reflection / inputClippedFraction | 0.15319824 |
| Wide Focus / sea reflection / newClippedFraction | 0.29138184 |
| Wide Focus / sea reflection / shadowRMS | 0 |
| Wide Focus / shoulder / chromaticityDrift | 9.6273569e-08 |
| Wide Focus / shoulder / clippedFraction | 0 |
| Wide Focus / shoulder / inputClippedFraction | 0 |
| Wide Focus / shoulder / newClippedFraction | 0 |
| Wide Focus / shoulder / shadowRMS | 0.0070291692 |
| Wide Focus / sun / chromaticityDrift | 5.8486629e-08 |
| Wide Focus / sun / clippedFraction | 0.77581787 |
| Wide Focus / sun / inputClippedFraction | 0.073303223 |
| Wide Focus / sun / newClippedFraction | 0.71044922 |
| Wide Focus / sun / shadowRMS | 0 |

Fixed top-left subject coordinates: (0.4, 0.4). Native ROIs use lower-left image coordinates. No face detection or automated subject placement.

### DLC_photo_night — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Subtle Focus finite | hard invariant | PASS | Full-frame float sample |
| Subtle Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Subtle Focus / lamp hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / stone hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / wet pavement hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus finite | hard invariant | PASS | Full-frame float sample |
| Portrait Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Portrait Focus / lamp hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / stone hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / wet pavement hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround finite | hard invariant | PASS | Full-frame float sample |
| Dark Surround new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Dark Surround / lamp hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / stone hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / wet pavement hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center finite | hard invariant | PASS | Full-frame float sample |
| Light Center new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Light Center / lamp hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / stone hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / wet pavement hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus finite | hard invariant | PASS | Full-frame float sample |
| Wide Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Wide Focus / lamp hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / stone hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / wet pavement hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus finite | hard invariant | PASS | Full-frame float sample |
| Narrow Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Narrow Focus / lamp hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / stone hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / wet pavement hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama finite | hard invariant | PASS | Full-frame float sample |
| Off-Center Drama new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Off-Center Drama / lamp hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / stone hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / wet pavement hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus finite | hard invariant | PASS | Full-frame float sample |
| Reverse Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Reverse Focus / lamp hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / stone hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / wet pavement hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Source unchanged | hard invariant | PASS | Original SHA256 before/after |

| Mesure | Valeur |
|---|---:|
| Dark Surround / lamp / chromaticityDrift | 1.2004683e-07 |
| Dark Surround / lamp / clippedFraction | 0 |
| Dark Surround / lamp / inputClippedFraction | 0.033569336 |
| Dark Surround / lamp / newClippedFraction | 0 |
| Dark Surround / lamp / shadowRMS | 0.012605839 |
| Dark Surround / sky / chromaticityDrift | 5.9665351e-08 |
| Dark Surround / sky / clippedFraction | 0 |
| Dark Surround / sky / inputClippedFraction | 0 |
| Dark Surround / sky / newClippedFraction | 0 |
| Dark Surround / sky / shadowRMS | 0.00036184866 |
| Dark Surround / stone / chromaticityDrift | 1.246532e-07 |
| Dark Surround / stone / clippedFraction | 0 |
| Dark Surround / stone / inputClippedFraction | 0.0068969727 |
| Dark Surround / stone / newClippedFraction | 0 |
| Dark Surround / stone / shadowRMS | 0.011899557 |
| Dark Surround / wet pavement / chromaticityDrift | 9.7863721e-08 |
| Dark Surround / wet pavement / clippedFraction | 0 |
| Dark Surround / wet pavement / inputClippedFraction | 0.0009765625 |
| Dark Surround / wet pavement / newClippedFraction | 0 |
| Dark Surround / wet pavement / shadowRMS | 0.016684601 |
| Light Center / lamp / chromaticityDrift | 0 |
| Light Center / lamp / clippedFraction | 0.033569336 |
| Light Center / lamp / inputClippedFraction | 0.033569336 |
| Light Center / lamp / newClippedFraction | 0 |
| Light Center / lamp / shadowRMS | 0.02272204 |
| Light Center / sky / chromaticityDrift | 0 |
| Light Center / sky / clippedFraction | 0 |
| Light Center / sky / inputClippedFraction | 0 |
| Light Center / sky / newClippedFraction | 0 |
| Light Center / sky / shadowRMS | 0.00065223268 |
| Light Center / stone / chromaticityDrift | 0 |
| Light Center / stone / clippedFraction | 0.0068969727 |
| Light Center / stone / inputClippedFraction | 0.0068969727 |
| Light Center / stone / newClippedFraction | 0 |
| Light Center / stone / shadowRMS | 0.021447962 |
| Light Center / wet pavement / chromaticityDrift | 1.0653244e-07 |
| Light Center / wet pavement / clippedFraction | 0.0051269531 |
| Light Center / wet pavement / inputClippedFraction | 0.0009765625 |
| Light Center / wet pavement / newClippedFraction | 0.0041503906 |
| Light Center / wet pavement / shadowRMS | 0.024091692 |
| Narrow Focus / lamp / chromaticityDrift | 1.0115965e-07 |
| Narrow Focus / lamp / clippedFraction | 0 |
| Narrow Focus / lamp / inputClippedFraction | 0.033569336 |
| Narrow Focus / lamp / newClippedFraction | 0 |
| Narrow Focus / lamp / shadowRMS | 0.01551961 |
| Narrow Focus / sky / chromaticityDrift | 5.7923325e-08 |
| Narrow Focus / sky / clippedFraction | 0 |
| Narrow Focus / sky / inputClippedFraction | 0 |
| Narrow Focus / sky / newClippedFraction | 0 |
| Narrow Focus / sky / shadowRMS | 0.000445488 |
| Narrow Focus / stone / chromaticityDrift | 1.2536721e-07 |
| Narrow Focus / stone / clippedFraction | 0 |
| Narrow Focus / stone / inputClippedFraction | 0.0068969727 |
| Narrow Focus / stone / newClippedFraction | 0 |
| Narrow Focus / stone / shadowRMS | 0.01464939 |
| Narrow Focus / wet pavement / chromaticityDrift | 1.0686718e-07 |
| Narrow Focus / wet pavement / clippedFraction | 0 |
| Narrow Focus / wet pavement / inputClippedFraction | 0.0009765625 |
| Narrow Focus / wet pavement / newClippedFraction | 0 |
| Narrow Focus / wet pavement / shadowRMS | 0.014948542 |
| Off-Center Drama / lamp / chromaticityDrift | 1.2491405e-07 |
| Off-Center Drama / lamp / clippedFraction | 0 |
| Off-Center Drama / lamp / inputClippedFraction | 0.033569336 |
| Off-Center Drama / lamp / newClippedFraction | 0 |
| Off-Center Drama / lamp / shadowRMS | 0.013050384 |
| Off-Center Drama / sky / chromaticityDrift | 7.6721805e-08 |
| Off-Center Drama / sky / clippedFraction | 0 |
| Off-Center Drama / sky / inputClippedFraction | 0 |
| Off-Center Drama / sky / newClippedFraction | 0 |
| Off-Center Drama / sky / shadowRMS | 0.0003746093 |
| Off-Center Drama / stone / chromaticityDrift | 1.4170886e-07 |
| Off-Center Drama / stone / clippedFraction | 0 |
| Off-Center Drama / stone / inputClippedFraction | 0.0068969727 |
| Off-Center Drama / stone / newClippedFraction | 0 |
| Off-Center Drama / stone / shadowRMS | 0.012328577 |
| Off-Center Drama / wet pavement / chromaticityDrift | 9.2981383e-08 |
| Off-Center Drama / wet pavement / clippedFraction | 0.0021972656 |
| Off-Center Drama / wet pavement / inputClippedFraction | 0.0009765625 |
| Off-Center Drama / wet pavement / newClippedFraction | 0.0013427734 |
| Off-Center Drama / wet pavement / shadowRMS | 0.020935037 |
| Portrait Focus / lamp / chromaticityDrift | 1.0467909e-07 |
| Portrait Focus / lamp / clippedFraction | 0 |
| Portrait Focus / lamp / inputClippedFraction | 0.033569336 |
| Portrait Focus / lamp / newClippedFraction | 0 |
| Portrait Focus / lamp / shadowRMS | 0.016633505 |
| Portrait Focus / sky / chromaticityDrift | 6.0176026e-08 |
| Portrait Focus / sky / clippedFraction | 0 |
| Portrait Focus / sky / inputClippedFraction | 0 |
| Portrait Focus / sky / newClippedFraction | 0 |
| Portrait Focus / sky / shadowRMS | 0.00047746227 |
| Portrait Focus / stone / chromaticityDrift | 1.311793e-07 |
| Portrait Focus / stone / clippedFraction | 0 |
| Portrait Focus / stone / inputClippedFraction | 0.0068969727 |
| Portrait Focus / stone / newClippedFraction | 0 |
| Portrait Focus / stone / shadowRMS | 0.015700826 |
| Portrait Focus / wet pavement / chromaticityDrift | 9.1719568e-08 |
| Portrait Focus / wet pavement / clippedFraction | 0.0018920898 |
| Portrait Focus / wet pavement / inputClippedFraction | 0.0009765625 |
| Portrait Focus / wet pavement / newClippedFraction | 0.0012207031 |
| Portrait Focus / wet pavement / shadowRMS | 0.02062923 |
| Reverse Focus / lamp / chromaticityDrift | 1.0688334e-07 |
| Reverse Focus / lamp / clippedFraction | 0.30279541 |
| Reverse Focus / lamp / inputClippedFraction | 0.033569336 |
| Reverse Focus / lamp / newClippedFraction | 0.26922607 |
| Reverse Focus / lamp / shadowRMS | 0.027021211 |
| Reverse Focus / sky / chromaticityDrift | 6.436379e-08 |
| Reverse Focus / sky / clippedFraction | 0 |
| Reverse Focus / sky / inputClippedFraction | 0 |
| Reverse Focus / sky / newClippedFraction | 0 |
| Reverse Focus / sky / shadowRMS | 0.00077563986 |
| Reverse Focus / stone / chromaticityDrift | 1.1947034e-07 |
| Reverse Focus / stone / clippedFraction | 0.11907959 |
| Reverse Focus / stone / inputClippedFraction | 0.0068969727 |
| Reverse Focus / stone / newClippedFraction | 0.11218262 |
| Reverse Focus / stone / shadowRMS | 0.025506069 |
| Reverse Focus / wet pavement / chromaticityDrift | 9.1509327e-08 |
| Reverse Focus / wet pavement / clippedFraction | 0 |
| Reverse Focus / wet pavement / inputClippedFraction | 0.0009765625 |
| Reverse Focus / wet pavement / newClippedFraction | 0 |
| Reverse Focus / wet pavement / shadowRMS | 0.019206898 |
| Subtle Focus / lamp / chromaticityDrift | 1.0700798e-07 |
| Subtle Focus / lamp / clippedFraction | 0 |
| Subtle Focus / lamp / inputClippedFraction | 0.033569336 |
| Subtle Focus / lamp / newClippedFraction | 0 |
| Subtle Focus / lamp / shadowRMS | 0.020056811 |
| Subtle Focus / sky / chromaticityDrift | 5.7038643e-08 |
| Subtle Focus / sky / clippedFraction | 0 |
| Subtle Focus / sky / inputClippedFraction | 0 |
| Subtle Focus / sky / newClippedFraction | 0 |
| Subtle Focus / sky / shadowRMS | 0.00057572773 |
| Subtle Focus / stone / chromaticityDrift | 1.2852201e-07 |
| Subtle Focus / stone / clippedFraction | 0 |
| Subtle Focus / stone / inputClippedFraction | 0.0068969727 |
| Subtle Focus / stone / newClippedFraction | 0 |
| Subtle Focus / stone / shadowRMS | 0.01897698 |
| Subtle Focus / wet pavement / chromaticityDrift | 1.0205329e-07 |
| Subtle Focus / wet pavement / clippedFraction | 0.0015869141 |
| Subtle Focus / wet pavement / inputClippedFraction | 0.0009765625 |
| Subtle Focus / wet pavement / newClippedFraction | 0.00061035156 |
| Subtle Focus / wet pavement / shadowRMS | 0.02083291 |
| Wide Focus / lamp / chromaticityDrift | 1.0916668e-07 |
| Wide Focus / lamp / clippedFraction | 0 |
| Wide Focus / lamp / inputClippedFraction | 0.033569336 |
| Wide Focus / lamp / newClippedFraction | 0 |
| Wide Focus / lamp / shadowRMS | 0.01845603 |
| Wide Focus / sky / chromaticityDrift | 6.6722802e-08 |
| Wide Focus / sky / clippedFraction | 0 |
| Wide Focus / sky / inputClippedFraction | 0 |
| Wide Focus / sky / newClippedFraction | 0 |
| Wide Focus / sky / shadowRMS | 0.00052977749 |
| Wide Focus / stone / chromaticityDrift | 1.2004676e-07 |
| Wide Focus / stone / clippedFraction | 0 |
| Wide Focus / stone / inputClippedFraction | 0.0068969727 |
| Wide Focus / stone / newClippedFraction | 0 |
| Wide Focus / stone / shadowRMS | 0.017421158 |
| Wide Focus / wet pavement / chromaticityDrift | 1.0055568e-07 |
| Wide Focus / wet pavement / clippedFraction | 0.00048828125 |
| Wide Focus / wet pavement / inputClippedFraction | 0.0009765625 |
| Wide Focus / wet pavement / newClippedFraction | 0.00018310547 |
| Wide Focus / wet pavement / shadowRMS | 0.019833671 |

Fixed top-left subject coordinates: (0.45, 0.68). Native ROIs use lower-left image coordinates. No face detection or automated subject placement.

### DLC_photo_indoor — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Subtle Focus finite | hard invariant | PASS | Full-frame float sample |
| Subtle Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Subtle Focus / dark interior hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / sunlit wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / wood table hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / window hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus finite | hard invariant | PASS | Full-frame float sample |
| Portrait Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Portrait Focus / dark interior hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / sunlit wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / wood table hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / window hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround finite | hard invariant | PASS | Full-frame float sample |
| Dark Surround new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Dark Surround / dark interior hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / sunlit wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / wood table hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / window hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center finite | hard invariant | PASS | Full-frame float sample |
| Light Center new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Light Center / dark interior hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / sunlit wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / wood table hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / window hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus finite | hard invariant | PASS | Full-frame float sample |
| Wide Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Wide Focus / dark interior hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / sunlit wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / wood table hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / window hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus finite | hard invariant | PASS | Full-frame float sample |
| Narrow Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Narrow Focus / dark interior hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / sunlit wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / wood table hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / window hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama finite | hard invariant | PASS | Full-frame float sample |
| Off-Center Drama new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Off-Center Drama / dark interior hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / sunlit wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / wood table hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / window hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus finite | hard invariant | PASS | Full-frame float sample |
| Reverse Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Reverse Focus / dark interior hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / sunlit wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / wood table hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / window hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Source unchanged | hard invariant | PASS | Original SHA256 before/after |

| Mesure | Valeur |
|---|---:|
| Dark Surround / dark interior / chromaticityDrift | 7.9495619e-08 |
| Dark Surround / dark interior / clippedFraction | 0 |
| Dark Surround / dark interior / inputClippedFraction | 0 |
| Dark Surround / dark interior / newClippedFraction | 0 |
| Dark Surround / dark interior / shadowRMS | 0.0029408474 |
| Dark Surround / sunlit wall / chromaticityDrift | 6.2355324e-08 |
| Dark Surround / sunlit wall / clippedFraction | 0 |
| Dark Surround / sunlit wall / inputClippedFraction | 0 |
| Dark Surround / sunlit wall / newClippedFraction | 0 |
| Dark Surround / sunlit wall / shadowRMS | 0.0086080378 |
| Dark Surround / window / chromaticityDrift | 9.2944967e-08 |
| Dark Surround / window / clippedFraction | 0 |
| Dark Surround / window / inputClippedFraction | 0.00079345703 |
| Dark Surround / window / newClippedFraction | 0 |
| Dark Surround / window / shadowRMS | 0.016691571 |
| Dark Surround / wood table / chromaticityDrift | 8.790869e-08 |
| Dark Surround / wood table / clippedFraction | 0 |
| Dark Surround / wood table / inputClippedFraction | 0 |
| Dark Surround / wood table / newClippedFraction | 0 |
| Dark Surround / wood table / shadowRMS | 0.023975978 |
| Light Center / dark interior / chromaticityDrift | 7.9441754e-08 |
| Light Center / dark interior / clippedFraction | 0 |
| Light Center / dark interior / inputClippedFraction | 0 |
| Light Center / dark interior / newClippedFraction | 0 |
| Light Center / dark interior / shadowRMS | 0.0048262033 |
| Light Center / sunlit wall / chromaticityDrift | 0 |
| Light Center / sunlit wall / clippedFraction | 0 |
| Light Center / sunlit wall / inputClippedFraction | 0 |
| Light Center / sunlit wall / newClippedFraction | 0 |
| Light Center / sunlit wall / shadowRMS | 0.015513067 |
| Light Center / window / chromaticityDrift | 0 |
| Light Center / window / clippedFraction | 0.00079345703 |
| Light Center / window / inputClippedFraction | 0.00079345703 |
| Light Center / window / newClippedFraction | 0 |
| Light Center / window / shadowRMS | 0.030086576 |
| Light Center / wood table / chromaticityDrift | 8.3795398e-08 |
| Light Center / wood table / clippedFraction | 0.14471436 |
| Light Center / wood table / inputClippedFraction | 0 |
| Light Center / wood table / newClippedFraction | 0.14471436 |
| Light Center / wood table / shadowRMS | 0.035087911 |
| Narrow Focus / dark interior / chromaticityDrift | 5.7923325e-08 |
| Narrow Focus / dark interior / clippedFraction | 0 |
| Narrow Focus / dark interior / inputClippedFraction | 0 |
| Narrow Focus / dark interior / newClippedFraction | 0 |
| Narrow Focus / dark interior / shadowRMS | 0.0032743335 |
| Narrow Focus / sunlit wall / chromaticityDrift | 6.4151148e-08 |
| Narrow Focus / sunlit wall / clippedFraction | 0 |
| Narrow Focus / sunlit wall / inputClippedFraction | 0 |
| Narrow Focus / sunlit wall / newClippedFraction | 0 |
| Narrow Focus / sunlit wall / shadowRMS | 0.010595737 |
| Narrow Focus / window / chromaticityDrift | 7.8241676e-08 |
| Narrow Focus / window / clippedFraction | 0 |
| Narrow Focus / window / inputClippedFraction | 0.00079345703 |
| Narrow Focus / window / newClippedFraction | 0 |
| Narrow Focus / window / shadowRMS | 0.020549737 |
| Narrow Focus / wood table / chromaticityDrift | 9.265208e-08 |
| Narrow Focus / wood table / clippedFraction | 0.10437012 |
| Narrow Focus / wood table / inputClippedFraction | 0 |
| Narrow Focus / wood table / newClippedFraction | 0.10437012 |
| Narrow Focus / wood table / shadowRMS | 0.032280389 |
| Off-Center Drama / dark interior / chromaticityDrift | 8.6291656e-08 |
| Off-Center Drama / dark interior / clippedFraction | 0 |
| Off-Center Drama / dark interior / inputClippedFraction | 0 |
| Off-Center Drama / dark interior / newClippedFraction | 0 |
| Off-Center Drama / dark interior / shadowRMS | 0.0032962229 |
| Off-Center Drama / sunlit wall / chromaticityDrift | 5.68838e-08 |
| Off-Center Drama / sunlit wall / clippedFraction | 0 |
| Off-Center Drama / sunlit wall / inputClippedFraction | 0 |
| Off-Center Drama / sunlit wall / newClippedFraction | 0 |
| Off-Center Drama / sunlit wall / shadowRMS | 0.0089094082 |
| Off-Center Drama / window / chromaticityDrift | 8.3036858e-08 |
| Off-Center Drama / window / clippedFraction | 0 |
| Off-Center Drama / window / inputClippedFraction | 0.00079345703 |
| Off-Center Drama / window / newClippedFraction | 0 |
| Off-Center Drama / window / shadowRMS | 0.0172802 |
| Off-Center Drama / wood table / chromaticityDrift | 8.5126872e-08 |
| Off-Center Drama / wood table / clippedFraction | 0.090698242 |
| Off-Center Drama / wood table / inputClippedFraction | 0 |
| Off-Center Drama / wood table / newClippedFraction | 0.090698242 |
| Off-Center Drama / wood table / shadowRMS | 0.03162426 |
| Portrait Focus / dark interior / chromaticityDrift | 7.5153631e-08 |
| Portrait Focus / dark interior / clippedFraction | 0 |
| Portrait Focus / dark interior / inputClippedFraction | 0 |
| Portrait Focus / dark interior / newClippedFraction | 0 |
| Portrait Focus / dark interior / shadowRMS | 0.0036090187 |
| Portrait Focus / sunlit wall / chromaticityDrift | 6.2018774e-08 |
| Portrait Focus / sunlit wall / clippedFraction | 0 |
| Portrait Focus / sunlit wall / inputClippedFraction | 0 |
| Portrait Focus / sunlit wall / newClippedFraction | 0 |
| Portrait Focus / sunlit wall / shadowRMS | 0.011355738 |
| Portrait Focus / window / chromaticityDrift | 7.6616946e-08 |
| Portrait Focus / window / clippedFraction | 0 |
| Portrait Focus / window / inputClippedFraction | 0.00079345703 |
| Portrait Focus / window / newClippedFraction | 0 |
| Portrait Focus / window / shadowRMS | 0.022024661 |
| Portrait Focus / wood table / chromaticityDrift | 9.2741709e-08 |
| Portrait Focus / wood table / clippedFraction | 0.055053711 |
| Portrait Focus / wood table / inputClippedFraction | 0 |
| Portrait Focus / wood table / newClippedFraction | 0.055053711 |
| Portrait Focus / wood table / shadowRMS | 0.029518587 |
| Reverse Focus / dark interior / chromaticityDrift | 7.7719667e-08 |
| Reverse Focus / dark interior / clippedFraction | 0 |
| Reverse Focus / dark interior / inputClippedFraction | 0 |
| Reverse Focus / dark interior / newClippedFraction | 0 |
| Reverse Focus / dark interior / shadowRMS | 0.0054817714 |
| Reverse Focus / sunlit wall / chromaticityDrift | 5.8299537e-08 |
| Reverse Focus / sunlit wall / clippedFraction | 0.33538818 |
| Reverse Focus / sunlit wall / inputClippedFraction | 0 |
| Reverse Focus / sunlit wall / newClippedFraction | 0.33538818 |
| Reverse Focus / sunlit wall / shadowRMS | 0.018448264 |
| Reverse Focus / window / chromaticityDrift | 8.2264883e-08 |
| Reverse Focus / window / clippedFraction | 0.043395996 |
| Reverse Focus / window / inputClippedFraction | 0.00079345703 |
| Reverse Focus / window / newClippedFraction | 0.042602539 |
| Reverse Focus / window / shadowRMS | 0.035779169 |
| Reverse Focus / wood table / chromaticityDrift | 8.2756556e-08 |
| Reverse Focus / wood table / clippedFraction | 0 |
| Reverse Focus / wood table / inputClippedFraction | 0 |
| Reverse Focus / wood table / newClippedFraction | 0 |
| Reverse Focus / wood table / shadowRMS | 0.018177743 |
| Subtle Focus / dark interior / chromaticityDrift | 7.382722e-08 |
| Subtle Focus / dark interior / clippedFraction | 0 |
| Subtle Focus / dark interior / inputClippedFraction | 0 |
| Subtle Focus / dark interior / newClippedFraction | 0 |
| Subtle Focus / dark interior / shadowRMS | 0.0044861523 |
| Subtle Focus / sunlit wall / chromaticityDrift | 6.7046129e-08 |
| Subtle Focus / sunlit wall / clippedFraction | 0 |
| Subtle Focus / sunlit wall / inputClippedFraction | 0 |
| Subtle Focus / sunlit wall / newClippedFraction | 0 |
| Subtle Focus / sunlit wall / shadowRMS | 0.013764846 |
| Subtle Focus / window / chromaticityDrift | 8.5921853e-08 |
| Subtle Focus / window / clippedFraction | 0 |
| Subtle Focus / window / inputClippedFraction | 0.00079345703 |
| Subtle Focus / window / newClippedFraction | 0 |
| Subtle Focus / window / shadowRMS | 0.026557507 |
| Subtle Focus / wood table / chromaticityDrift | 9.0031306e-08 |
| Subtle Focus / wood table / clippedFraction | 0.007019043 |
| Subtle Focus / wood table / inputClippedFraction | 0 |
| Subtle Focus / wood table / newClippedFraction | 0.007019043 |
| Subtle Focus / wood table / shadowRMS | 0.026030234 |
| Wide Focus / dark interior / chromaticityDrift | 6.8121686e-08 |
| Wide Focus / dark interior / clippedFraction | 0 |
| Wide Focus / dark interior / inputClippedFraction | 0 |
| Wide Focus / dark interior / newClippedFraction | 0 |
| Wide Focus / dark interior / shadowRMS | 0.0040824227 |
| Wide Focus / sunlit wall / chromaticityDrift | 5.6843027e-08 |
| Wide Focus / sunlit wall / clippedFraction | 0 |
| Wide Focus / sunlit wall / inputClippedFraction | 0 |
| Wide Focus / sunlit wall / newClippedFraction | 0 |
| Wide Focus / sunlit wall / shadowRMS | 0.012600578 |
| Wide Focus / window / chromaticityDrift | 7.5070774e-08 |
| Wide Focus / window / clippedFraction | 0 |
| Wide Focus / window / inputClippedFraction | 0.00079345703 |
| Wide Focus / window / newClippedFraction | 0 |
| Wide Focus / window / shadowRMS | 0.024437892 |
| Wide Focus / wood table / chromaticityDrift | 9.4945106e-08 |
| Wide Focus / wood table / clippedFraction | 0.018188477 |
| Wide Focus / wood table / inputClippedFraction | 0 |
| Wide Focus / wood table / newClippedFraction | 0.018188477 |
| Wide Focus / wood table / shadowRMS | 0.027112059 |

Fixed top-left subject coordinates: (0.56, 0.67). Native ROIs use lower-left image coordinates. No face detection or automated subject placement.

### DLC_photo_white_subject — WARN

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Subtle Focus finite | hard invariant | PASS | Full-frame float sample |
| Subtle Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Subtle Focus / white dress hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / white wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus finite | hard invariant | PASS | Full-frame float sample |
| Portrait Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Portrait Focus / white dress hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / white wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround finite | hard invariant | PASS | Full-frame float sample |
| Dark Surround new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Dark Surround / white dress hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / white wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center finite | hard invariant | PASS | Full-frame float sample |
| Light Center new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Light Center / white dress hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / white wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus finite | hard invariant | PASS | Full-frame float sample |
| Wide Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Wide Focus / white dress hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / white wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus finite | hard invariant | PASS | Full-frame float sample |
| Narrow Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Narrow Focus / white dress hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / white wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama finite | hard invariant | PASS | Full-frame float sample |
| Off-Center Drama new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Off-Center Drama / white dress hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / white wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus finite | hard invariant | PASS | Full-frame float sample |
| Reverse Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Reverse Focus / white dress hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / white wall hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / blue sky hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / transition hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Source unchanged | hard invariant | PASS | Original SHA256 before/after |

| Mesure | Valeur |
|---|---:|
| Dark Surround / blue sky / chromaticityDrift | 8.2690081e-08 |
| Dark Surround / blue sky / clippedFraction | 0 |
| Dark Surround / blue sky / inputClippedFraction | 0 |
| Dark Surround / blue sky / newClippedFraction | 0 |
| Dark Surround / blue sky / shadowRMS | 0 |
| Dark Surround / skin / chromaticityDrift | 9.0068239e-08 |
| Dark Surround / skin / clippedFraction | 0 |
| Dark Surround / skin / inputClippedFraction | 0.0043334961 |
| Dark Surround / skin / newClippedFraction | 0 |
| Dark Surround / skin / shadowRMS | 0.018402585 |
| Dark Surround / transition / chromaticityDrift | 6.1826224e-08 |
| Dark Surround / transition / clippedFraction | 0 |
| Dark Surround / transition / inputClippedFraction | 0 |
| Dark Surround / transition / newClippedFraction | 0 |
| Dark Surround / transition / shadowRMS | 0.0058949986 |
| Dark Surround / white dress / chromaticityDrift | 7.1806889e-08 |
| Dark Surround / white dress / clippedFraction | 0 |
| Dark Surround / white dress / inputClippedFraction | 0 |
| Dark Surround / white dress / newClippedFraction | 0 |
| Dark Surround / white dress / shadowRMS | 0 |
| Dark Surround / white wall / chromaticityDrift | 6.3469784e-08 |
| Dark Surround / white wall / clippedFraction | 0 |
| Dark Surround / white wall / inputClippedFraction | 0.009765625 |
| Dark Surround / white wall / newClippedFraction | 0 |
| Dark Surround / white wall / shadowRMS | 0 |
| Light Center / blue sky / chromaticityDrift | 0 |
| Light Center / blue sky / clippedFraction | 0 |
| Light Center / blue sky / inputClippedFraction | 0 |
| Light Center / blue sky / newClippedFraction | 0 |
| Light Center / blue sky / shadowRMS | 0 |
| Light Center / skin / chromaticityDrift | 1.0334447e-07 |
| Light Center / skin / clippedFraction | 0.061523438 |
| Light Center / skin / inputClippedFraction | 0.0043334961 |
| Light Center / skin / newClippedFraction | 0.057189941 |
| Light Center / skin / shadowRMS | 0.027537272 |
| Light Center / transition / chromaticityDrift | 7.0643693e-08 |
| Light Center / transition / clippedFraction | 0.054199219 |
| Light Center / transition / inputClippedFraction | 0 |
| Light Center / transition / newClippedFraction | 0.054199219 |
| Light Center / transition / shadowRMS | 0.0083716133 |
| Light Center / white dress / chromaticityDrift | 6.6361204e-08 |
| Light Center / white dress / clippedFraction | 0.014343262 |
| Light Center / white dress / inputClippedFraction | 0 |
| Light Center / white dress / newClippedFraction | 0.014343262 |
| Light Center / white dress / shadowRMS | 0 |
| Light Center / white wall / chromaticityDrift | 6.0649848e-08 |
| Light Center / white wall / clippedFraction | 0.009765625 |
| Light Center / white wall / inputClippedFraction | 0.009765625 |
| Light Center / white wall / newClippedFraction | 0 |
| Light Center / white wall / shadowRMS | 0 |
| Narrow Focus / blue sky / chromaticityDrift | 7.2653257e-08 |
| Narrow Focus / blue sky / clippedFraction | 0 |
| Narrow Focus / blue sky / inputClippedFraction | 0 |
| Narrow Focus / blue sky / newClippedFraction | 0 |
| Narrow Focus / blue sky / shadowRMS | 0 |
| Narrow Focus / skin / chromaticityDrift | 9.0714191e-08 |
| Narrow Focus / skin / clippedFraction | 0 |
| Narrow Focus / skin / inputClippedFraction | 0.0043334961 |
| Narrow Focus / skin / newClippedFraction | 0 |
| Narrow Focus / skin / shadowRMS | 0.017659132 |
| Narrow Focus / transition / chromaticityDrift | 6.2051636e-08 |
| Narrow Focus / transition / clippedFraction | 0 |
| Narrow Focus / transition / inputClippedFraction | 0 |
| Narrow Focus / transition / newClippedFraction | 0 |
| Narrow Focus / transition / shadowRMS | 0.0043747357 |
| Narrow Focus / white dress / chromaticityDrift | 6.9445421e-08 |
| Narrow Focus / white dress / clippedFraction | 0 |
| Narrow Focus / white dress / inputClippedFraction | 0 |
| Narrow Focus / white dress / newClippedFraction | 0 |
| Narrow Focus / white dress / shadowRMS | 0 |
| Narrow Focus / white wall / chromaticityDrift | 6.4151148e-08 |
| Narrow Focus / white wall / clippedFraction | 0 |
| Narrow Focus / white wall / inputClippedFraction | 0.009765625 |
| Narrow Focus / white wall / newClippedFraction | 0 |
| Narrow Focus / white wall / shadowRMS | 0 |
| Off-Center Drama / blue sky / chromaticityDrift | 8.0153492e-08 |
| Off-Center Drama / blue sky / clippedFraction | 0 |
| Off-Center Drama / blue sky / inputClippedFraction | 0 |
| Off-Center Drama / blue sky / newClippedFraction | 0 |
| Off-Center Drama / blue sky / shadowRMS | 0 |
| Off-Center Drama / skin / chromaticityDrift | 8.9424431e-08 |
| Off-Center Drama / skin / clippedFraction | 0 |
| Off-Center Drama / skin / inputClippedFraction | 0.0043334961 |
| Off-Center Drama / skin / newClippedFraction | 0 |
| Off-Center Drama / skin / shadowRMS | 0.021389262 |
| Off-Center Drama / transition / chromaticityDrift | 6.6949592e-08 |
| Off-Center Drama / transition / clippedFraction | 0.01171875 |
| Off-Center Drama / transition / inputClippedFraction | 0 |
| Off-Center Drama / transition / newClippedFraction | 0.01171875 |
| Off-Center Drama / transition / shadowRMS | 0.0090612165 |
| Off-Center Drama / white dress / chromaticityDrift | 6.5542752e-08 |
| Off-Center Drama / white dress / clippedFraction | 0 |
| Off-Center Drama / white dress / inputClippedFraction | 0 |
| Off-Center Drama / white dress / newClippedFraction | 0 |
| Off-Center Drama / white dress / shadowRMS | 0 |
| Off-Center Drama / white wall / chromaticityDrift | 6.0848382e-08 |
| Off-Center Drama / white wall / clippedFraction | 0 |
| Off-Center Drama / white wall / inputClippedFraction | 0.009765625 |
| Off-Center Drama / white wall / newClippedFraction | 0 |
| Off-Center Drama / white wall / shadowRMS | 0 |
| Portrait Focus / blue sky / chromaticityDrift | 8.4458786e-08 |
| Portrait Focus / blue sky / clippedFraction | 0 |
| Portrait Focus / blue sky / inputClippedFraction | 0 |
| Portrait Focus / blue sky / newClippedFraction | 0 |
| Portrait Focus / blue sky / shadowRMS | 0 |
| Portrait Focus / skin / chromaticityDrift | 9.5469558e-08 |
| Portrait Focus / skin / clippedFraction | 0 |
| Portrait Focus / skin / inputClippedFraction | 0.0043334961 |
| Portrait Focus / skin / newClippedFraction | 0 |
| Portrait Focus / skin / shadowRMS | 0.023763453 |
| Portrait Focus / transition / chromaticityDrift | 6.8565413e-08 |
| Portrait Focus / transition / clippedFraction | 0.0018310547 |
| Portrait Focus / transition / inputClippedFraction | 0 |
| Portrait Focus / transition / newClippedFraction | 0.0018310547 |
| Portrait Focus / transition / shadowRMS | 0.0076788047 |
| Portrait Focus / white dress / chromaticityDrift | 6.8027316e-08 |
| Portrait Focus / white dress / clippedFraction | 0 |
| Portrait Focus / white dress / inputClippedFraction | 0 |
| Portrait Focus / white dress / newClippedFraction | 0 |
| Portrait Focus / white dress / shadowRMS | 0 |
| Portrait Focus / white wall / chromaticityDrift | 6.3658639e-08 |
| Portrait Focus / white wall / clippedFraction | 0 |
| Portrait Focus / white wall / inputClippedFraction | 0.009765625 |
| Portrait Focus / white wall / newClippedFraction | 0 |
| Portrait Focus / white wall / shadowRMS | 0 |
| Reverse Focus / blue sky / chromaticityDrift | 8.3658196e-08 |
| Reverse Focus / blue sky / clippedFraction | 0 |
| Reverse Focus / blue sky / inputClippedFraction | 0 |
| Reverse Focus / blue sky / newClippedFraction | 0 |
| Reverse Focus / blue sky / shadowRMS | 0 |
| Reverse Focus / skin / chromaticityDrift | 9.0499858e-08 |
| Reverse Focus / skin / clippedFraction | 0.05456543 |
| Reverse Focus / skin / inputClippedFraction | 0.0043334961 |
| Reverse Focus / skin / newClippedFraction | 0.050842285 |
| Reverse Focus / skin / shadowRMS | 0.026548881 |
| Reverse Focus / transition / chromaticityDrift | 6.5855502e-08 |
| Reverse Focus / transition / clippedFraction | 0 |
| Reverse Focus / transition / inputClippedFraction | 0 |
| Reverse Focus / transition / newClippedFraction | 0 |
| Reverse Focus / transition / shadowRMS | 0.0052460536 |
| Reverse Focus / white dress / chromaticityDrift | 6.719661e-08 |
| Reverse Focus / white dress / clippedFraction | 0 |
| Reverse Focus / white dress / inputClippedFraction | 0 |
| Reverse Focus / white dress / newClippedFraction | 0 |
| Reverse Focus / white dress / shadowRMS | 0 |
| Reverse Focus / white wall / chromaticityDrift | 7.0671205e-08 |
| Reverse Focus / white wall / clippedFraction | 0.46118164 |
| Reverse Focus / white wall / inputClippedFraction | 0.009765625 |
| Reverse Focus / white wall / newClippedFraction | 0.45141602 |
| Reverse Focus / white wall / shadowRMS | 0 |
| Subtle Focus / blue sky / chromaticityDrift | 9.9973649e-08 |
| Subtle Focus / blue sky / clippedFraction | 0 |
| Subtle Focus / blue sky / inputClippedFraction | 0 |
| Subtle Focus / blue sky / newClippedFraction | 0 |
| Subtle Focus / blue sky / shadowRMS | 0 |
| Subtle Focus / skin / chromaticityDrift | 9.8729815e-08 |
| Subtle Focus / skin / clippedFraction | 0.00042724609 |
| Subtle Focus / skin / inputClippedFraction | 0.0043334961 |
| Subtle Focus / skin / newClippedFraction | 0 |
| Subtle Focus / skin / shadowRMS | 0.025155869 |
| Subtle Focus / transition / chromaticityDrift | 6.7659819e-08 |
| Subtle Focus / transition / clippedFraction | 0.0015258789 |
| Subtle Focus / transition / inputClippedFraction | 0 |
| Subtle Focus / transition / newClippedFraction | 0.0015258789 |
| Subtle Focus / transition / shadowRMS | 0.0063471061 |
| Subtle Focus / white dress / chromaticityDrift | 6.5421709e-08 |
| Subtle Focus / white dress / clippedFraction | 0 |
| Subtle Focus / white dress / inputClippedFraction | 0 |
| Subtle Focus / white dress / newClippedFraction | 0 |
| Subtle Focus / white dress / shadowRMS | 0 |
| Subtle Focus / white wall / chromaticityDrift | 6.5881082e-08 |
| Subtle Focus / white wall / clippedFraction | 0 |
| Subtle Focus / white wall / inputClippedFraction | 0.009765625 |
| Subtle Focus / white wall / newClippedFraction | 0 |
| Subtle Focus / white wall / shadowRMS | 0 |
| Wide Focus / blue sky / chromaticityDrift | 9.0620258e-08 |
| Wide Focus / blue sky / clippedFraction | 0 |
| Wide Focus / blue sky / inputClippedFraction | 0 |
| Wide Focus / blue sky / newClippedFraction | 0 |
| Wide Focus / blue sky / shadowRMS | 0 |
| Wide Focus / skin / chromaticityDrift | 9.0256913e-08 |
| Wide Focus / skin / clippedFraction | 0 |
| Wide Focus / skin / inputClippedFraction | 0.0043334961 |
| Wide Focus / skin / newClippedFraction | 0 |
| Wide Focus / skin / shadowRMS | 0.022830786 |
| Wide Focus / transition / chromaticityDrift | 6.3953233e-08 |
| Wide Focus / transition / clippedFraction | 0.011779785 |
| Wide Focus / transition / inputClippedFraction | 0 |
| Wide Focus / transition / newClippedFraction | 0.011779785 |
| Wide Focus / transition / shadowRMS | 0.0062613326 |
| Wide Focus / white dress / chromaticityDrift | 6.6717764e-08 |
| Wide Focus / white dress / clippedFraction | 0 |
| Wide Focus / white dress / inputClippedFraction | 0 |
| Wide Focus / white dress / newClippedFraction | 0 |
| Wide Focus / white dress / shadowRMS | 0 |
| Wide Focus / white wall / chromaticityDrift | 6.5140149e-08 |
| Wide Focus / white wall / clippedFraction | 0 |
| Wide Focus / white wall / inputClippedFraction | 0.009765625 |
| Wide Focus / white wall / newClippedFraction | 0 |
| Wide Focus / white wall / shadowRMS | 0 |

Fixed top-left subject coordinates: (0.42, 0.47). Native ROIs use lower-left image coordinates. No face detection or automated subject placement.

### DLC_photo_fine_texture — WARN

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Subtle Focus finite | hard invariant | PASS | Full-frame float sample |
| Subtle Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Subtle Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / fabric hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Subtle Focus / water hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus finite | hard invariant | PASS | Full-frame float sample |
| Portrait Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Portrait Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / fabric hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Portrait Focus / water hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround finite | hard invariant | PASS | Full-frame float sample |
| Dark Surround new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Dark Surround / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / fabric hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Dark Surround / water hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center finite | hard invariant | PASS | Full-frame float sample |
| Light Center new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Light Center / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / fabric hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Light Center / water hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus finite | hard invariant | PASS | Full-frame float sample |
| Wide Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Wide Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / fabric hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Wide Focus / water hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus finite | hard invariant | PASS | Full-frame float sample |
| Narrow Focus new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Narrow Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / fabric hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Narrow Focus / water hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama finite | hard invariant | PASS | Full-frame float sample |
| Off-Center Drama new clipping | quality heuristic | PASS | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Off-Center Drama / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / fabric hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Off-Center Drama / water hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus finite | hard invariant | PASS | Full-frame float sample |
| Reverse Focus new clipping | quality heuristic | WARN | Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation |
| Reverse Focus / skin hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / hair hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / fabric hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Reverse Focus / water hue | hard invariant | PASS | Native ROI RGB ratios before gamut conversion; DLC is not a color effect |
| Source unchanged | hard invariant | PASS | Original SHA256 before/after |

| Mesure | Valeur |
|---|---:|
| Dark Surround / fabric / chromaticityDrift | 7.0914182e-08 |
| Dark Surround / fabric / clippedFraction | 0 |
| Dark Surround / fabric / inputClippedFraction | 0 |
| Dark Surround / fabric / newClippedFraction | 0 |
| Dark Surround / fabric / shadowRMS | 0.0099417293 |
| Dark Surround / hair / chromaticityDrift | 1.1289841e-07 |
| Dark Surround / hair / clippedFraction | 0 |
| Dark Surround / hair / inputClippedFraction | 0 |
| Dark Surround / hair / newClippedFraction | 0 |
| Dark Surround / hair / shadowRMS | 0.011791392 |
| Dark Surround / skin / chromaticityDrift | 1.323452e-07 |
| Dark Surround / skin / clippedFraction | 0.00024414062 |
| Dark Surround / skin / inputClippedFraction | 0.0080566406 |
| Dark Surround / skin / newClippedFraction | 0 |
| Dark Surround / skin / shadowRMS | 0.029217114 |
| Dark Surround / water / chromaticityDrift | 1.1043241e-07 |
| Dark Surround / water / clippedFraction | 0 |
| Dark Surround / water / inputClippedFraction | 0.011535645 |
| Dark Surround / water / newClippedFraction | 0 |
| Dark Surround / water / shadowRMS | 0.0045820429 |
| Light Center / fabric / chromaticityDrift | 7.9754124e-08 |
| Light Center / fabric / clippedFraction | 0 |
| Light Center / fabric / inputClippedFraction | 0 |
| Light Center / fabric / newClippedFraction | 0 |
| Light Center / fabric / shadowRMS | 0.014046762 |
| Light Center / hair / chromaticityDrift | 1.0371104e-07 |
| Light Center / hair / clippedFraction | 0.0010986328 |
| Light Center / hair / inputClippedFraction | 0 |
| Light Center / hair / newClippedFraction | 0.0010986328 |
| Light Center / hair / shadowRMS | 0.017049563 |
| Light Center / skin / chromaticityDrift | 1.3904703e-07 |
| Light Center / skin / clippedFraction | 0.15002441 |
| Light Center / skin / inputClippedFraction | 0.0080566406 |
| Light Center / skin / newClippedFraction | 0.14196777 |
| Light Center / skin / shadowRMS | 0.042549458 |
| Light Center / water / chromaticityDrift | 1.0918813e-07 |
| Light Center / water / clippedFraction | 0.015991211 |
| Light Center / water / inputClippedFraction | 0.011535645 |
| Light Center / water / newClippedFraction | 0.0045166016 |
| Light Center / water / shadowRMS | 0.0026696875 |
| Narrow Focus / fabric / chromaticityDrift | 6.8106084e-08 |
| Narrow Focus / fabric / clippedFraction | 0 |
| Narrow Focus / fabric / inputClippedFraction | 0 |
| Narrow Focus / fabric / newClippedFraction | 0 |
| Narrow Focus / fabric / shadowRMS | 0.0098271193 |
| Narrow Focus / hair / chromaticityDrift | 1.1014777e-07 |
| Narrow Focus / hair / clippedFraction | 0 |
| Narrow Focus / hair / inputClippedFraction | 0 |
| Narrow Focus / hair / newClippedFraction | 0 |
| Narrow Focus / hair / shadowRMS | 0.012431817 |
| Narrow Focus / skin / chromaticityDrift | 1.2515566e-07 |
| Narrow Focus / skin / clippedFraction | 0.11260986 |
| Narrow Focus / skin / inputClippedFraction | 0.0080566406 |
| Narrow Focus / skin / newClippedFraction | 0.10516357 |
| Narrow Focus / skin / shadowRMS | 0.036948426 |
| Narrow Focus / water / chromaticityDrift | 1.1489727e-07 |
| Narrow Focus / water / clippedFraction | 0 |
| Narrow Focus / water / inputClippedFraction | 0.011535645 |
| Narrow Focus / water / newClippedFraction | 0 |
| Narrow Focus / water / shadowRMS | 0.001341477 |
| Off-Center Drama / fabric / chromaticityDrift | 7.8238521e-08 |
| Off-Center Drama / fabric / clippedFraction | 0 |
| Off-Center Drama / fabric / inputClippedFraction | 0 |
| Off-Center Drama / fabric / newClippedFraction | 0 |
| Off-Center Drama / fabric / shadowRMS | 0.013541375 |
| Off-Center Drama / hair / chromaticityDrift | 1.0641927e-07 |
| Off-Center Drama / hair / clippedFraction | 0.00018310547 |
| Off-Center Drama / hair / inputClippedFraction | 0 |
| Off-Center Drama / hair / newClippedFraction | 0.00018310547 |
| Off-Center Drama / hair / shadowRMS | 0.015016247 |
| Off-Center Drama / skin / chromaticityDrift | 1.2913385e-07 |
| Off-Center Drama / skin / clippedFraction | 0.13116455 |
| Off-Center Drama / skin / inputClippedFraction | 0.0080566406 |
| Off-Center Drama / skin / newClippedFraction | 0.12310791 |
| Off-Center Drama / skin / shadowRMS | 0.038111425 |
| Off-Center Drama / water / chromaticityDrift | 1.2096809e-07 |
| Off-Center Drama / water / clippedFraction | 0 |
| Off-Center Drama / water / inputClippedFraction | 0.011535645 |
| Off-Center Drama / water / newClippedFraction | 0 |
| Off-Center Drama / water / shadowRMS | 0.0039596398 |
| Portrait Focus / fabric / chromaticityDrift | 7.6822901e-08 |
| Portrait Focus / fabric / clippedFraction | 0 |
| Portrait Focus / fabric / inputClippedFraction | 0 |
| Portrait Focus / fabric / newClippedFraction | 0 |
| Portrait Focus / fabric / shadowRMS | 0.012418774 |
| Portrait Focus / hair / chromaticityDrift | 1.4596884e-07 |
| Portrait Focus / hair / clippedFraction | 0 |
| Portrait Focus / hair / inputClippedFraction | 0 |
| Portrait Focus / hair / newClippedFraction | 0 |
| Portrait Focus / hair / shadowRMS | 0.013882783 |
| Portrait Focus / skin / chromaticityDrift | 1.3120171e-07 |
| Portrait Focus / skin / clippedFraction | 0.11529541 |
| Portrait Focus / skin / inputClippedFraction | 0.0080566406 |
| Portrait Focus / skin / newClippedFraction | 0.10723877 |
| Portrait Focus / skin / shadowRMS | 0.036007603 |
| Portrait Focus / water / chromaticityDrift | 1.0646383e-07 |
| Portrait Focus / water / clippedFraction | 0 |
| Portrait Focus / water / inputClippedFraction | 0.011535645 |
| Portrait Focus / water / newClippedFraction | 0 |
| Portrait Focus / water / shadowRMS | 0.0014441314 |
| Reverse Focus / fabric / chromaticityDrift | 6.2489515e-08 |
| Reverse Focus / fabric / clippedFraction | 0 |
| Reverse Focus / fabric / inputClippedFraction | 0 |
| Reverse Focus / fabric / newClippedFraction | 0 |
| Reverse Focus / fabric / shadowRMS | 0.01093894 |
| Reverse Focus / hair / chromaticityDrift | 1.0630526e-07 |
| Reverse Focus / hair / clippedFraction | 0 |
| Reverse Focus / hair / inputClippedFraction | 0 |
| Reverse Focus / hair / newClippedFraction | 0 |
| Reverse Focus / hair / shadowRMS | 0.009586623 |
| Reverse Focus / skin / chromaticityDrift | 1.1784054e-07 |
| Reverse Focus / skin / clippedFraction | 0 |
| Reverse Focus / skin / inputClippedFraction | 0.0080566406 |
| Reverse Focus / skin / newClippedFraction | 0 |
| Reverse Focus / skin / shadowRMS | 0.022548223 |
| Reverse Focus / water / chromaticityDrift | 1.1885713e-07 |
| Reverse Focus / water / clippedFraction | 0.40582275 |
| Reverse Focus / water / inputClippedFraction | 0.011535645 |
| Reverse Focus / water / newClippedFraction | 0.39428711 |
| Reverse Focus / water / shadowRMS | 0.0041704485 |
| Subtle Focus / fabric / chromaticityDrift | 6.793023e-08 |
| Subtle Focus / fabric / clippedFraction | 0 |
| Subtle Focus / fabric / inputClippedFraction | 0 |
| Subtle Focus / fabric / newClippedFraction | 0 |
| Subtle Focus / fabric / shadowRMS | 0.011302642 |
| Subtle Focus / hair / chromaticityDrift | 1.1028648e-07 |
| Subtle Focus / hair / clippedFraction | 0 |
| Subtle Focus / hair / inputClippedFraction | 0 |
| Subtle Focus / hair / newClippedFraction | 0 |
| Subtle Focus / hair / shadowRMS | 0.013038236 |
| Subtle Focus / skin / chromaticityDrift | 1.4024139e-07 |
| Subtle Focus / skin / clippedFraction | 0.065185547 |
| Subtle Focus / skin / inputClippedFraction | 0.0080566406 |
| Subtle Focus / skin / newClippedFraction | 0.057128906 |
| Subtle Focus / skin / shadowRMS | 0.031811523 |
| Subtle Focus / water / chromaticityDrift | 1.1992952e-07 |
| Subtle Focus / water / clippedFraction | 0 |
| Subtle Focus / water / inputClippedFraction | 0.011535645 |
| Subtle Focus / water / newClippedFraction | 0 |
| Subtle Focus / water / shadowRMS | 0.0032560608 |
| Wide Focus / fabric / chromaticityDrift | 7.0358808e-08 |
| Wide Focus / fabric / clippedFraction | 0 |
| Wide Focus / fabric / inputClippedFraction | 0 |
| Wide Focus / fabric / newClippedFraction | 0 |
| Wide Focus / fabric / shadowRMS | 0.011011431 |
| Wide Focus / hair / chromaticityDrift | 1.3417696e-07 |
| Wide Focus / hair / clippedFraction | 0 |
| Wide Focus / hair / inputClippedFraction | 0 |
| Wide Focus / hair / newClippedFraction | 0 |
| Wide Focus / hair / shadowRMS | 0.013593115 |
| Wide Focus / skin / chromaticityDrift | 1.4635226e-07 |
| Wide Focus / skin / clippedFraction | 0.087585449 |
| Wide Focus / skin / inputClippedFraction | 0.0080566406 |
| Wide Focus / skin / newClippedFraction | 0.079528809 |
| Wide Focus / skin / shadowRMS | 0.032871031 |
| Wide Focus / water / chromaticityDrift | 1.2498269e-07 |
| Wide Focus / water / clippedFraction | 6.1035156e-05 |
| Wide Focus / water / inputClippedFraction | 0.011535645 |
| Wide Focus / water / newClippedFraction | 0 |
| Wide Focus / water / shadowRMS | 0.0052782771 |

Fixed top-left subject coordinates: (0.35, 0.45). Native ROIs use lower-left image coordinates. No face detection or automated subject placement.

### DLC_preset_diversity — PASS

| Contrôle | Type | État | Critère |
|---|---|---|---|
| Portrait Focus / Subtle Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Dark Surround / Subtle Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Dark Surround / Portrait Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Light Center / Subtle Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Light Center / Portrait Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Light Center / Dark Surround | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Wide Focus / Subtle Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Wide Focus / Portrait Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Wide Focus / Dark Surround | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Wide Focus / Light Center | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Narrow Focus / Subtle Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Narrow Focus / Portrait Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Narrow Focus / Dark Surround | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Narrow Focus / Light Center | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Narrow Focus / Wide Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Off-Center Drama / Subtle Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Off-Center Drama / Portrait Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Off-Center Drama / Dark Surround | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Off-Center Drama / Light Center | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Off-Center Drama / Wide Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Off-Center Drama / Narrow Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Reverse Focus / Subtle Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Reverse Focus / Portrait Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Reverse Focus / Dark Surround | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Reverse Focus / Light Center | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Reverse Focus / Wide Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Reverse Focus / Narrow Focus | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |
| Reverse Focus / Off-Center Drama | quality heuristic | PASS | WARN only for non-subtle looks close on photos and uniform chart; no tuning |

| Mesure | Valeur |
|---|---:|
| Dark Surround / Portrait Focus-photoMAE | 0.034802562 |
| Dark Surround / Subtle Focus-photoMAE | 0.064651572 |
| Light Center / Dark Surround-photoMAE | 0.092996746 |
| Light Center / Portrait Focus-photoMAE | 0.058202088 |
| Light Center / Subtle Focus-photoMAE | 0.028345177 |
| Narrow Focus / Dark Surround-photoMAE | 0.024639216 |
| Narrow Focus / Light Center-photoMAE | 0.077096854 |
| Narrow Focus / Portrait Focus-photoMAE | 0.019606179 |
| Narrow Focus / Subtle Focus-photoMAE | 0.05120122 |
| Narrow Focus / Wide Focus-photoMAE | 0.042340642 |
| Off-Center Drama / Dark Surround-photoMAE | 0.024886331 |
| Off-Center Drama / Light Center-photoMAE | 0.088161326 |
| Off-Center Drama / Narrow Focus-photoMAE | 0.032240136 |
| Off-Center Drama / Portrait Focus-photoMAE | 0.042226315 |
| Off-Center Drama / Subtle Focus-photoMAE | 0.064632102 |
| Off-Center Drama / Wide Focus-photoMAE | 0.05740237 |
| Portrait Focus / Subtle Focus-photoMAE | 0.034025599 |
| Reverse Focus / Dark Surround-photoMAE | 0.10958711 |
| Reverse Focus / Light Center-photoMAE | 0.04782702 |
| Reverse Focus / Narrow Focus-photoMAE | 0.096034983 |
| Reverse Focus / Off-Center Drama-photoMAE | 0.10524218 |
| Reverse Focus / Portrait Focus-photoMAE | 0.085144003 |
| Reverse Focus / Subtle Focus-photoMAE | 0.053987129 |
| Reverse Focus / Wide Focus-photoMAE | 0.064104754 |
| Wide Focus / Dark Surround-photoMAE | 0.056357567 |
| Wide Focus / Light Center-photoMAE | 0.036652511 |
| Wide Focus / Portrait Focus-photoMAE | 0.025449688 |
| Wide Focus / Subtle Focus-photoMAE | 0.012810939 |



## Tableau photographique

Originaire et réglages positionnés séparés ; `fixed_photo_settings.json` documente tous les centres choisis une seule fois, sans détection. Statistiques en RGBAf après réduction pleine image à 512px. Shadow RMS = écart-type de Y de sortie pour les pixels dont Y d’entrée <.1. Chromaticité = erreur maximale des ratios RGB/somme. Le redimensionnement après un gain variable peut produire une très faible différence de ratios sur des couleurs voisines ; les hard checks utilisent des ROI natives sans ce rééchantillonnage.

| Photo / preset | Mean Y | P01 | P05 | P50 | P95 | Clipped | New clipped | Shadow RMS | Chroma drift | Nonfinite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 01_portrait_light_skin.png / Dark Surround | 0.2137596 | 0.009700059 | 0.02365929 | 0.1624881 | 0.5184127 | 0 | 0 | 0.02063395 | 8.533382 | 0 |
| 01_portrait_light_skin.png / Light Center | 0.3541001 | 0.01623962 | 0.03857081 | 0.2767315 | 0.8869716 | 0.02348905 | 0.02195404 | 0.03093749 | 5.070917 | 0 |
| 01_portrait_light_skin.png / Narrow Focus | 0.238957 | 0.01099813 | 0.02591061 | 0.1847371 | 0.6002497 | 0.002004674 | 0.001998946 | 0.0214449 | 1.033478 | 0 |
| 01_portrait_light_skin.png / Off-Center Drama | 0.2204947 | 0.0109548 | 0.02699472 | 0.1802606 | 0.5120479 | 0 | 0 | 0.02308287 | 17.80007 | 0 |
| 01_portrait_light_skin.png / Portrait Focus | 0.2662374 | 0.01212609 | 0.02935875 | 0.2048536 | 0.655385 | 0.003075742 | 0.003007011 | 0.02477528 | 7.196695 | 0 |
| 01_portrait_light_skin.png / Reverse Focus | 0.3733764 | 0.01750726 | 0.03693687 | 0.287075 | 1.009884 | 0.1347484 | 0.1333223 | 0.02985884 | 22.87332 | 0 |
| 01_portrait_light_skin.png / Subtle Focus | 0.3130072 | 0.01480917 | 0.03438923 | 0.2431848 | 0.7938052 | 0.001300174 | 0.001197077 | 0.02606445 | 3.544802 | 0 |
| 01_portrait_light_skin.png / Wide Focus | 0.3019817 | 0.01375466 | 0.03289969 | 0.2376254 | 0.7528013 | 0.001494914 | 0.001391816 | 0.02601412 | 5.541931 | 0 |
| 01_portrait_light_skin.png / positioned Dark Surround | 0.2089659 | 0.009999396 | 0.02479286 | 0.1687473 | 0.4970174 | 0 | 0 | 0.01969088 | 10.04245 | 0 |
| 01_portrait_light_skin.png / positioned Light Center | 0.3505525 | 0.01661083 | 0.03949039 | 0.2811032 | 0.8743931 | 0.00485131 | 0.003316303 | 0.03005038 | 7.826633 | 0 |
| 01_portrait_light_skin.png / positioned Narrow Focus | 0.2369349 | 0.01095709 | 0.02555152 | 0.1888524 | 0.594339 | 0 | 0 | 0.02063092 | 0.2169897 | 0 |
| 01_portrait_light_skin.png / positioned Off-Center Drama | 0.2213518 | 0.01061166 | 0.02682045 | 0.1772946 | 0.5099368 | 0.0002577438 | 0.0002520161 | 0.02311779 | 12.14563 | 0 |
| 01_portrait_light_skin.png / positioned Portrait Focus | 0.2612883 | 0.01273689 | 0.03037848 | 0.2098343 | 0.6399026 | 5.727639e-06 | 5.727639e-06 | 0.0234037 | 10.19304 | 0 |
| 01_portrait_light_skin.png / positioned Reverse Focus | 0.3781817 | 0.0165575 | 0.03628262 | 0.2851062 | 1.026565 | 0.1517939 | 0.1502646 | 0.03049637 | 70.65256 | 0 |
| 01_portrait_light_skin.png / positioned Subtle Focus | 0.3105136 | 0.0148784 | 0.03477481 | 0.2482309 | 0.7790895 | 0.0001947397 | 0.0001890121 | 0.02565085 | 4.298037 | 0 |
| 01_portrait_light_skin.png / positioned Wide Focus | 0.2989907 | 0.013864 | 0.0332313 | 0.2436982 | 0.7381748 | 0.0002634714 | 0.0002577438 | 0.02541807 | 6.632214 | 0 |
| 02_portrait_dark_skin.png / Dark Surround | 0.09230272 | 0.000414308 | 0.001566786 | 0.02753713 | 0.3999338 | 0 | 0 | 0.0182266 | 174.5152 | 0 |
| 02_portrait_dark_skin.png / Light Center | 0.1566088 | 0.0006442328 | 0.002510695 | 0.04629849 | 0.6979806 | 0.003877612 | 0.003705783 | 0.02834838 | 147.8831 | 0 |
| 02_portrait_dark_skin.png / Narrow Focus | 0.1058998 | 0.0004137143 | 0.001648587 | 0.03139542 | 0.4687592 | 0 | 0 | 0.01965182 | 51.52929 | 0 |
| 02_portrait_dark_skin.png / Off-Center Drama | 0.110195 | 0.0003527587 | 0.001379263 | 0.03045561 | 0.4678845 | 0.004284274 | 0.004267091 | 0.02120387 | 270.6185 | 0 |
| 02_portrait_dark_skin.png / Portrait Focus | 0.1164753 | 0.0004940606 | 0.001927676 | 0.03480441 | 0.5103132 | 5.727639e-06 | 0 | 0.02267559 | 153.842 | 0 |
| 02_portrait_dark_skin.png / Reverse Focus | 0.1705582 | 0.000551525 | 0.00232442 | 0.04726867 | 0.7943173 | 0.0276244 | 0.02746976 | 0.02736036 | 35.52801 | 0 |
| 02_portrait_dark_skin.png / Subtle Focus | 0.1381515 | 0.000566829 | 0.002227443 | 0.04086782 | 0.619577 | 0.0001202804 | 9.736987e-05 | 0.02433795 | 112.2497 | 0 |
| 02_portrait_dark_skin.png / Wide Focus | 0.134234 | 0.0005466541 | 0.002107388 | 0.03954359 | 0.6014029 | 0.0006873167 | 0.0006472232 | 0.02371057 | 110.5815 | 0 |
| 02_portrait_dark_skin.png / positioned Dark Surround | 0.09456797 | 0.0003861754 | 0.001467234 | 0.02797296 | 0.4072845 | 5.727639e-06 | 0 | 0.01838911 | 149.0158 | 0 |
| 02_portrait_dark_skin.png / positioned Light Center | 0.1584147 | 0.0006177735 | 0.002430246 | 0.04665833 | 0.7041333 | 0.006048387 | 0.005876558 | 0.02849454 | 153.2711 | 0 |
| 02_portrait_dark_skin.png / positioned Narrow Focus | 0.1078549 | 0.0003990096 | 0.001593128 | 0.03132619 | 0.4724055 | 1.145528e-05 | 5.727639e-06 | 0.01975542 | 153.1833 | 0 |
| 02_portrait_dark_skin.png / positioned Off-Center Drama | 0.1011057 | 0.0004092365 | 0.001571485 | 0.02965453 | 0.425674 | 0.0009106946 | 0.0008935117 | 0.0217902 | 161.3394 | 0 |
| 02_portrait_dark_skin.png / positioned Portrait Focus | 0.119033 | 0.0004588891 | 0.001817146 | 0.03528003 | 0.5201224 | 0.0004009348 | 0.0003894795 | 0.02283524 | 157.9484 | 0 |
| 02_portrait_dark_skin.png / positioned Reverse Focus | 0.1684566 | 0.0005865546 | 0.002447039 | 0.04676929 | 0.7882206 | 0.02677099 | 0.02662207 | 0.02723078 | 52.19125 | 0 |
| 02_portrait_dark_skin.png / positioned Subtle Focus | 0.1393699 | 0.0005578934 | 0.002177322 | 0.04104888 | 0.6230169 | 0.0003322031 | 0.0002921096 | 0.02442573 | 110.2483 | 0 |
| 02_portrait_dark_skin.png / positioned Wide Focus | 0.1350904 | 0.0005337303 | 0.002048337 | 0.03975769 | 0.5976447 | 0.0008305077 | 0.0008133248 | 0.02376189 | 119.9303 | 0 |
| 03_landscape_clouds.png / Dark Surround | 0.1507585 | -0.001409078 | 0.003662957 | 0.09123367 | 0.513405 | 1.356337e-05 | 0 | 0.01986697 | 8.670814 | 0 |
| 03_landscape_clouds.png / Light Center | 0.2432927 | -0.002538306 | 0.006504636 | 0.1599191 | 0.8136412 | 0.02224392 | 0.01953803 | 0.03255669 | 1.228977 | 0 |
| 03_landscape_clouds.png / Narrow Focus | 0.1643574 | -0.001733714 | 0.004438338 | 0.1079928 | 0.5632751 | 0.001342773 | 0.001308865 | 0.02162701 | 0.04518053 | 0 |
| 03_landscape_clouds.png / Off-Center Drama | 0.1723913 | -0.001457875 | 0.003732546 | 0.09334019 | 0.6073518 | 0.00897895 | 0.008511013 | 0.01822557 | 0.1447385 | 0 |
| 03_landscape_clouds.png / Portrait Focus | 0.186224 | -0.00185815 | 0.004791629 | 0.1175992 | 0.6355597 | 0.004408095 | 0.004041884 | 0.02434197 | 3.275764 | 0 |
| 03_landscape_clouds.png / Reverse Focus | 0.2404319 | -0.003018372 | 0.00768204 | 0.172453 | 0.8213973 | 0.02705214 | 0.02505832 | 0.03573997 | 5.905094 | 0 |
| 03_landscape_clouds.png / Subtle Focus | 0.2122567 | -0.002248064 | 0.005823869 | 0.1410928 | 0.7067739 | 0.003119575 | 0.002326118 | 0.02909211 | 5.999757 | 0 |
| 03_landscape_clouds.png / Wide Focus | 0.2037096 | -0.002061745 | 0.005327984 | 0.1323456 | 0.6775847 | 0.002109104 | 0.001681858 | 0.02823446 | 22.50795 | 0 |
| 03_landscape_clouds.png / positioned Dark Surround | 0.138475 | -0.001556188 | 0.004099739 | 0.09144331 | 0.4498727 | 0 | 0 | 0.0215403 | 38.51602 | 0 |
| 03_landscape_clouds.png / positioned Light Center | 0.2336816 | -0.002585699 | 0.006870353 | 0.1597476 | 0.7703855 | 0.00922309 | 0.006517198 | 0.03413766 | 36.71228 | 0 |
| 03_landscape_clouds.png / positioned Narrow Focus | 0.1579855 | -0.001746296 | 0.004527166 | 0.1085862 | 0.5269748 | 0.0001017253 | 9.494358e-05 | 0.02411856 | 2.976306 | 0 |
| 03_landscape_clouds.png / positioned Off-Center Drama | 0.1483528 | -0.001621075 | 0.004264782 | 0.09497775 | 0.4896885 | 0.002733019 | 0.002678765 | 0.02427335 | 41.57477 | 0 |
| 03_landscape_clouds.png / positioned Portrait Focus | 0.1756245 | -0.001925403 | 0.005118418 | 0.1178598 | 0.5793146 | 0.001478407 | 0.00145128 | 0.02609194 | 32.87819 | 0 |
| 03_landscape_clouds.png / positioned Reverse Focus | 0.2525776 | -0.002852608 | 0.006524027 | 0.1753387 | 0.862497 | 0.03642442 | 0.03385417 | 0.03521402 | 32.38102 | 0 |
| 03_landscape_clouds.png / positioned Subtle Focus | 0.2060143 | -0.002336964 | 0.006160061 | 0.1409421 | 0.6780802 | 0.002590603 | 0.00245497 | 0.02961944 | 171.6877 | 0 |
| 03_landscape_clouds.png / positioned Wide Focus | 0.1934403 | -0.002164809 | 0.005829505 | 0.1314557 | 0.6298925 | 0.004353841 | 0.004218207 | 0.02937029 | 41.3413 | 0 |
| 04_backlight.png / Dark Surround | 0.1660026 | 0.0008857758 | 0.002073548 | 0.03271932 | 0.731641 | 0.0005097599 | 0 | 0.01659278 | 2.340829 | 0 |
| 04_backlight.png / Light Center | 0.268795 | 0.001595991 | 0.003732691 | 0.05067044 | 1.07071 | 0.08716321 | 0.08321687 | 0.02474275 | 0.8185087 | 0 |
| 04_backlight.png / Narrow Focus | 0.1797309 | 0.001090094 | 0.002549046 | 0.03451472 | 0.6739501 | 0.0123087 | 0.01152401 | 0.01823434 | 0.0232357 | 0 |
| 04_backlight.png / Off-Center Drama | 0.163861 | 0.0009173654 | 0.002146138 | 0.03385183 | 0.6186886 | 0.006758614 | 0.006403501 | 0.01849336 | 9.295933 | 0 |
| 04_backlight.png / Portrait Focus | 0.204453 | 0.001168788 | 0.002733634 | 0.04006234 | 0.845804 | 0.03547127 | 0.03368997 | 0.0202154 | 2.444338 | 0 |
| 04_backlight.png / Reverse Focus | 0.2679616 | 0.001895421 | 0.004402137 | 0.04286274 | 0.9712767 | 0.0913673 | 0.09018741 | 0.02121336 | 2.457314 | 0 |
| 04_backlight.png / Subtle Focus | 0.2349942 | 0.001409334 | 0.003305977 | 0.04276326 | 0.9579197 | 0.04899423 | 0.04594712 | 0.0208343 | 1.028029 | 0 |
| 04_backlight.png / Wide Focus | 0.2256572 | 0.001297214 | 0.003034758 | 0.04216712 | 0.926124 | 0.04732176 | 0.0446985 | 0.02079348 | 1.648752 | 0 |
| 04_backlight.png / positioned Dark Surround | 0.1645787 | 0.000886023 | 0.002072155 | 0.03053745 | 0.7203249 | 0.0001947397 | 0 | 0.01614789 | 11.86191 | 0 |
| 04_backlight.png / positioned Light Center | 0.2652359 | 0.001596612 | 0.003732022 | 0.04818147 | 1.060484 | 0.09063989 | 0.08669355 | 0.02449561 | 1.807907 | 0 |
| 04_backlight.png / positioned Narrow Focus | 0.1750246 | 0.001090094 | 0.002549046 | 0.03322961 | 0.6661625 | 0.004994501 | 0.004753941 | 0.01811794 | 0.002604534 | 0 |
| 04_backlight.png / positioned Off-Center Drama | 0.1732715 | 0.0009166561 | 0.002144525 | 0.03513262 | 0.7360226 | 0.02094598 | 0.02010974 | 0.01971217 | 5.718909 | 0 |
| 04_backlight.png / positioned Portrait Focus | 0.1968992 | 0.001168334 | 0.002732325 | 0.03835346 | 0.7636754 | 0.01572237 | 0.01500069 | 0.01987529 | 1.080548 | 0 |
| 04_backlight.png / positioned Reverse Focus | 0.269512 | 0.001895337 | 0.00439087 | 0.0440934 | 0.9724162 | 0.09035924 | 0.08801091 | 0.02187868 | 2.161813 | 0 |
| 04_backlight.png / positioned Subtle Focus | 0.2354126 | 0.001409334 | 0.003295549 | 0.04179603 | 0.9593945 | 0.04017366 | 0.03843819 | 0.02053416 | 1.75503 | 0 |
| 04_backlight.png / positioned Wide Focus | 0.2311324 | 0.001297096 | 0.003033248 | 0.03992818 | 0.9807023 | 0.05972209 | 0.0580439 | 0.02021018 | 2.226013 | 0 |
| 05_night.png / Dark Surround | 0.02411383 | -0.003447999 | 5.977907e-05 | 0.005569092 | 0.1062558 | 6.781684e-05 | 0 | 0.01346822 | 88.22242 | 0 |
| 05_night.png / Light Center | 0.0405745 | -0.005577999 | 0.0001010227 | 0.009270666 | 0.1766289 | 0.004876031 | 0.001376682 | 0.02186966 | 92.18443 | 0 |
| 05_night.png / Narrow Focus | 0.02761051 | -0.003668301 | 6.639738e-05 | 0.006143183 | 0.1195489 | 0.0006239149 | 0.0004475911 | 0.01485562 | 130.5548 | 0 |
| 05_night.png / Off-Center Drama | 0.02848643 | -0.003925712 | 5.963765e-05 | 0.005788466 | 0.1215593 | 0.003316243 | 0.002610948 | 0.01528615 | 136.8905 | 0 |
| 05_night.png / Portrait Focus | 0.03050652 | -0.004166803 | 7.420928e-05 | 0.007047272 | 0.1332141 | 0.0008951823 | 0.0006917318 | 0.01664649 | 136.3802 | 0 |
| 05_night.png / Reverse Focus | 0.0437644 | -0.005750279 | 9.930627e-05 | 0.009704908 | 0.1909967 | 0.01229519 | 0.008999295 | 0.02304771 | 1124.801 | 0 |
| 05_night.png / Subtle Focus | 0.03586604 | -0.004987742 | 8.910068e-05 | 0.008299317 | 0.1576234 | 0.0006374783 | 0.000386556 | 0.0191451 | 187.766 | 0 |
| 05_night.png / Wide Focus | 0.03372084 | -0.004862707 | 8.678943e-05 | 0.00772609 | 0.1498329 | 0.0006713867 | 0.0004679362 | 0.01840158 | 98.34801 | 0 |
| 05_night.png / positioned Dark Surround | 0.02565397 | -0.00345429 | 5.626581e-05 | 0.005236385 | 0.1120401 | 0.0001017253 | 0 | 0.01445582 | 364.1015 | 0 |
| 05_night.png / positioned Light Center | 0.04194215 | -0.005677956 | 9.624097e-05 | 0.009044725 | 0.1846674 | 0.006334093 | 0.002834744 | 0.0227186 | 348.8881 | 0 |
| 05_night.png / positioned Narrow Focus | 0.02862212 | -0.003837119 | 6.505653e-05 | 0.006108517 | 0.1274042 | 0.0005696615 | 0.0003458659 | 0.01565428 | 347.5518 | 0 |
| 05_night.png / positioned Off-Center Drama | 0.02844574 | -0.003776887 | 5.667921e-05 | 0.005452856 | 0.1237849 | 0.001586914 | 0.0009629991 | 0.01659536 | 390.0027 | 0 |
| 05_night.png / positioned Portrait Focus | 0.03248751 | -0.00429242 | 7.067302e-05 | 0.006660915 | 0.1425098 | 0.001803928 | 0.0009969076 | 0.01772962 | 363.8851 | 0 |
| 05_night.png / positioned Reverse Focus | 0.04218838 | -0.005683238 | 0.0001065311 | 0.01005651 | 0.183644 | 0.01065403 | 0.00789388 | 0.02226639 | 1113.481 | 0 |
| 05_night.png / positioned Subtle Focus | 0.03651673 | -0.004975131 | 8.712089e-05 | 0.008013017 | 0.1599626 | 0.001539442 | 0.0004747179 | 0.01957979 | 242.4539 | 0 |
| 05_night.png / positioned Wide Focus | 0.03454908 | -0.004713813 | 8.307184e-05 | 0.007517344 | 0.1510506 | 0.000922309 | 0.0003797743 | 0.01899755 | 318.0264 | 0 |
| 06_indoor_high_contrast.png / Dark Surround | 0.05191121 | -0.001463646 | 1.322239e-06 | 0.003769906 | 0.3822666 | 0 | 0 | 0.01333034 | 138.6796 | 0 |
| 06_indoor_high_contrast.png / Light Center | 0.08480457 | -0.002381925 | 2.293886e-06 | 0.006314971 | 0.6349113 | 0.006953354 | 0.006392045 | 0.02169902 | 1425.478 | 0 |
| 06_indoor_high_contrast.png / Narrow Focus | 0.05591357 | -0.00169587 | 1.530619e-06 | 0.004261621 | 0.4193747 | 0 | 0 | 0.01462174 | 106.8338 | 0 |
| 06_indoor_high_contrast.png / Off-Center Drama | 0.04796283 | -0.001511573 | 1.483896e-06 | 0.00510925 | 0.3549035 | 0 | 0 | 0.01240168 | 1445.212 | 0 |
| 06_indoor_high_contrast.png / Portrait Focus | 0.06352218 | -0.001822225 | 1.714605e-06 | 0.004651692 | 0.4783705 | 2.291056e-05 | 1.718292e-05 | 0.01635217 | 304.4078 | 0 |
| 06_indoor_high_contrast.png / Reverse Focus | 0.08861544 | -0.00241414 | 2.51791e-06 | 0.006945536 | 0.6670318 | 0.01589993 | 0.01534435 | 0.02312049 | 238.4006 | 0 |
| 06_indoor_high_contrast.png / Subtle Focus | 0.07546031 | -0.002107009 | 2.016969e-06 | 0.005667074 | 0.565318 | 5.727639e-05 | 4.009348e-05 | 0.01913297 | 1578.518 | 0 |
| 06_indoor_high_contrast.png / Wide Focus | 0.07213646 | -0.002003515 | 1.921198e-06 | 0.005478454 | 0.5405785 | 0.0003722966 | 0.0003264754 | 0.01837562 | 254.8565 | 0 |
| 06_indoor_high_contrast.png / positioned Dark Surround | 0.05362034 | -0.001503577 | 1.282197e-06 | 0.00362896 | 0.4121555 | 5.727639e-06 | 0 | 0.01417913 | 221.4228 | 0 |
| 06_indoor_high_contrast.png / positioned Light Center | 0.08720057 | -0.002424816 | 2.225148e-06 | 0.006292252 | 0.668167 | 0.01057322 | 0.01001191 | 0.02254806 | 215.0353 | 0 |
| 06_indoor_high_contrast.png / positioned Narrow Focus | 0.05992644 | -0.001594865 | 1.512453e-06 | 0.004253017 | 0.460395 | 0.003459494 | 0.003453766 | 0.01539929 | 17.31459 | 0 |
| 06_indoor_high_contrast.png / positioned Off-Center Drama | 0.05839565 | -0.00155685 | 1.322679e-06 | 0.003822946 | 0.441392 | 0.005275156 | 0.005257973 | 0.01605667 | 374.8529 | 0 |
| 06_indoor_high_contrast.png / positioned Portrait Focus | 0.06584499 | -0.001761365 | 1.628905e-06 | 0.004645466 | 0.5017407 | 0.003694327 | 0.003682872 | 0.01721963 | 256.7389 | 0 |
| 06_indoor_high_contrast.png / positioned Reverse Focus | 0.08699068 | -0.002283773 | 2.591314e-06 | 0.006980544 | 0.6302846 | 0.01658152 | 0.01604885 | 0.0225196 | 195.2638 | 0 |
| 06_indoor_high_contrast.png / positioned Subtle Focus | 0.07597114 | -0.002143778 | 1.974165e-06 | 0.005566273 | 0.581286 | 0.001036703 | 0.000967971 | 0.01946715 | 137.3233 | 0 |
| 06_indoor_high_contrast.png / positioned Wide Focus | 0.07337564 | -0.002083429 | 1.864079e-06 | 0.005224708 | 0.5679101 | 0.00327621 | 0.003047104 | 0.01891852 | 214.6959 | 0 |
| 07_white_subject.png / Dark Surround | 0.3189904 | 0.008336309 | 0.05778085 | 0.3100578 | 0.6075129 | 0 | 0 | 0.02011379 | 30.19878 | 0 |
| 07_white_subject.png / Light Center | 0.5278763 | 0.01394063 | 0.09798195 | 0.5406149 | 0.9622443 | 0.03258599 | 0.027398 | 0.03191239 | 5.108334 | 0 |
| 07_white_subject.png / Narrow Focus | 0.3555972 | 0.009304583 | 0.06530151 | 0.3652396 | 0.6551487 | 0.001776801 | 0.001749674 | 0.02187692 | 0.1944373 | 0 |
| 07_white_subject.png / Off-Center Drama | 0.3356796 | 0.01196335 | 0.0680172 | 0.319471 | 0.7078395 | 0.006673177 | 0.005859375 | 0.02817655 | 38.31135 | 0 |
| 07_white_subject.png / Portrait Focus | 0.3968794 | 0.01061803 | 0.07275589 | 0.3997586 | 0.7190793 | 0.005805122 | 0.005499946 | 0.02441921 | 4.659618 | 0 |
| 07_white_subject.png / Reverse Focus | 0.5529903 | 0.01519884 | 0.09751458 | 0.552869 | 1.073131 | 0.110928 | 0.1065538 | 0.03352571 | 513.0895 | 0 |
| 07_white_subject.png / Subtle Focus | 0.4651959 | 0.01266485 | 0.08757229 | 0.4792105 | 0.8635755 | 0.003994412 | 0.00313992 | 0.02810043 | 5.261558 | 0 |
| 07_white_subject.png / Wide Focus | 0.4454762 | 0.01160315 | 0.08285134 | 0.4468957 | 0.8570702 | 0.01043701 | 0.009494358 | 0.02739834 | 16.382 | 0 |
| 07_white_subject.png / positioned Dark Surround | 0.3183424 | 0.008961606 | 0.05882745 | 0.308329 | 0.6194426 | 2.712674e-05 | 0 | 0.02097351 | 57.21967 | 0 |
| 07_white_subject.png / positioned Light Center | 0.5274379 | 0.01459505 | 0.09940265 | 0.5384493 | 0.9699663 | 0.03899468 | 0.03380669 | 0.03281837 | 25.13948 | 0 |
| 07_white_subject.png / positioned Narrow Focus | 0.3550592 | 0.009594082 | 0.06641995 | 0.3616447 | 0.6580082 | 0.0003323025 | 0.0002441406 | 0.02244021 | 0.3238165 | 0 |
| 07_white_subject.png / positioned Off-Center Drama | 0.3404094 | 0.009924231 | 0.06323812 | 0.3213465 | 0.7145107 | 0.005900065 | 0.00539822 | 0.02494273 | 118.0899 | 0 |
| 07_white_subject.png / positioned Portrait Focus | 0.3960908 | 0.01152851 | 0.07537063 | 0.3966698 | 0.7269793 | 0.005567763 | 0.005133735 | 0.02585281 | 26.12202 | 0 |
| 07_white_subject.png / positioned Reverse Focus | 0.5535106 | 0.01427133 | 0.09644192 | 0.5520473 | 1.05181 | 0.1067573 | 0.1024984 | 0.03350456 | 501.726 | 0 |
| 07_white_subject.png / positioned Subtle Focus | 0.4647115 | 0.01298248 | 0.08781962 | 0.4780329 | 0.8744746 | 0.007500543 | 0.006510417 | 0.02824858 | 5.947937 | 0 |
| 07_white_subject.png / positioned Wide Focus | 0.4438967 | 0.01196947 | 0.08348412 | 0.445871 | 0.8550578 | 0.01323785 | 0.01226128 | 0.02768855 | 21.15995 | 0 |
| 08_fine_texture.png / Dark Surround | 0.1224383 | 0.001755762 | 0.005148835 | 0.09131394 | 0.3378384 | 0.0002170139 | 0 | 0.02209559 | 14.43191 | 0 |
| 08_fine_texture.png / Light Center | 0.2031021 | 0.002970609 | 0.008763946 | 0.1515698 | 0.5408846 | 0.04050022 | 0.03463406 | 0.03313119 | 1.143874 | 0 |
| 08_fine_texture.png / Narrow Focus | 0.1380953 | 0.001959948 | 0.005827325 | 0.1028824 | 0.3624191 | 0.005167643 | 0.004916721 | 0.02287522 | 1.110824 | 0 |
| 08_fine_texture.png / Off-Center Drama | 0.125067 | 0.002167189 | 0.006311554 | 0.09561504 | 0.3498519 | 0.003058539 | 0.002807617 | 0.02485372 | 58.18287 | 0 |
| 08_fine_texture.png / Portrait Focus | 0.1523403 | 0.002183768 | 0.00641906 | 0.1146728 | 0.4024024 | 0.006137424 | 0.005649143 | 0.02691299 | 5.361007 | 0 |
| 08_fine_texture.png / Reverse Focus | 0.2126025 | 0.003155551 | 0.009506788 | 0.1534202 | 0.570703 | 0.09029134 | 0.08575439 | 0.03016718 | 16.81632 | 0 |
| 08_fine_texture.png / Subtle Focus | 0.1786045 | 0.002661359 | 0.007816494 | 0.1336505 | 0.468653 | 0.005038791 | 0.003458659 | 0.02805961 | 6.710305 | 0 |
| 08_fine_texture.png / Wide Focus | 0.1711625 | 0.002511295 | 0.007436592 | 0.1260117 | 0.463012 | 0.0172526 | 0.01456706 | 0.0272573 | 18.41966 | 0 |
| 08_fine_texture.png / positioned Dark Surround | 0.1178155 | 0.001950409 | 0.005683616 | 0.09042715 | 0.31078 | 8.138021e-05 | 0 | 0.02161841 | 50.87653 | 0 |
| 08_fine_texture.png / positioned Light Center | 0.1990341 | 0.003185046 | 0.009343481 | 0.1503834 | 0.5139266 | 0.01627604 | 0.01040988 | 0.03275863 | 49.13784 | 0 |
| 08_fine_texture.png / positioned Narrow Focus | 0.13442 | 0.002126414 | 0.006254784 | 0.1035735 | 0.3464523 | 0.001756456 | 0.001675076 | 0.02379449 | 9.438366 | 0 |
| 08_fine_texture.png / positioned Off-Center Drama | 0.1251035 | 0.002106853 | 0.006221128 | 0.09786939 | 0.3311296 | 0.004326714 | 0.00398763 | 0.02559837 | 56.2517 | 0 |
| 08_fine_texture.png / positioned Portrait Focus | 0.1488269 | 0.002426542 | 0.007131578 | 0.1143832 | 0.3870709 | 0.00309923 | 0.002773709 | 0.02596929 | 22.91269 | 0 |
| 08_fine_texture.png / positioned Reverse Focus | 0.2171231 | 0.002776317 | 0.008733431 | 0.1573351 | 0.5783074 | 0.1000909 | 0.09459771 | 0.03084305 | 56.63262 | 0 |
| 08_fine_texture.png / positioned Subtle Focus | 0.1763965 | 0.002745403 | 0.008015585 | 0.1328354 | 0.458223 | 0.001824273 | 0.001444499 | 0.02777337 | 25.42461 | 0 |
| 08_fine_texture.png / positioned Wide Focus | 0.1681382 | 0.002637365 | 0.00768374 | 0.1244573 | 0.4467746 | 0.003567166 | 0.002726237 | 0.02728131 | 45.44172 | 0 |

## Performance et limites

GPU command timestamps sur entrée variable (pas un simple générateur uniforme), cinq répétitions après chauffe, sortie texture RGBA32Float sans readback dans la mesure GPU. CPU : validation/préparation du graphe, séparée du temps mur d’encodage/synchronisation. Multi-instance : matérialisation complète avec readback, protocole explicitement différent. RSS par lots de changements ne remplace pas Instruments. Mesures Mac, pas certification iPhone 48MP/thermique. Aucun masque raster ni cache d’image propre à DLC.

## Bilan de campagne et preuves externes

**831 contrôles PASS / 13 quality WARN / 0 FAIL**, dont **751 hard invariants PASS**, dans le banc DLC. Les comptages par cas en tête du rapport sont distincts des comptages de contrôles. Les WARN restent ouverts à validation photographique manuelle.

| Vérification externe | Type | Résultat |
|---|---|---|
| Build Lumora + cible UI iOS Simulator, iPhone 18 Pro / iOS 27 | hard invariant | PASS, `build-for-testing` |
| Compilation LumoraVisualTestLab + campagne complète et calibration du readback | hard invariant | PASS |
| Cœur partagé | hard invariant | PASS, 97 tests |
| 77 presets des 12 effets antérieurs, référence `5cbf732` | hard invariant | PASS, buffers Float32 bit-identiques |
| Protocole commun + mire indépendante + FFT | hard invariants / quality heuristics | PASS technique ; consulter les neuf WARN historiques du rapport commun |
| Drag, Undo/Redo, coordonnées stables sous zoom/pan, rotation et changement de panneau | hard invariant | PASS, XCTest UI sur simulateur |
| Évaluation photographique humaine finale | quality heuristic | En attente ; aucun Golden Master |

Le renderer est identique pour interactive/HQ/export : aucun paramètre de qualité ne modifie le champ analytique. Les tailles 1024/2048/4096 mesurent ce même chemin GPU ; le vrai RenderEngine est testé séparément à ses dimensions habituelles. Le test UI ne certifie pas VoiceOver avec une personne, toutes les tailles Dynamic Type ou la fluidité thermique sur appareil physique.

### Corrections techniques, sans raffinement esthétique

Le premier lancement n’a pas compilé le kernel : `coreimage::destination` doit être le dernier argument. Seule sa position dans la signature a changé. Le premier banc complet a ensuite signalé 41 hard checks en échec, conservés dans `ValidationHistory/initial_bank_checks.json`. Le diagnostic indépendant a établi que :

- `CIContext.render(toBitmap:)` écrit la première ligne en haut ; l’oracle et les moments inversaient une seconde fois Y. Un test à deux demi-plans blanc/noir vérifie maintenant explicitement cette convention.
- Une translation fractionnaire de l’image 512² produit ici un extent arrondi 513², puis 514² au retour. Le test d’identité compare désormais des translations entières ; un oracle distinct vérifie le champ dans l’extent fractionnaire réellement reçu, sans supposer à tort que sa taille reste 512².
- La réduction Lanczos de la mire lisait du transparent hors de l’image ; les statistiques de résolution et de centroïde incluaient ce bord. Le helper local au banc prolonge les pixels de bord avant réduction. Les moments utilisent un résiduel linéaire signé autour de la moyenne du fond, évitant de redresser et accumuler le bruit de quantification 8 bits.

Aucun seuil n’a été assoupli. Aucune modification du modèle, des EV, des presets ou du feather n’a été faite après les mesures. L’ensemble du banc a été relancé. Le renderer n’a subi aucune correction après sa signature Metal.

Le premier test UI a montré que la poignée était absorbée par l’élément d’accessibilité du canvas. Elle est maintenant une vue sœur de l’image ; son drag est isolé du pan simultané. Le même test repasse avec Undo/Redo et zoom/pan. La correction touche seulement l’intégration de cette nouvelle poignée.

### WARN photographiques conservés

- **DLC_photo_portrait_light / Light Center new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_portrait_light / Reverse Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_portrait_dark / Reverse Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_landscape / Reverse Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_backlight / Subtle Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_backlight / Portrait Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_backlight / Light Center new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_backlight / Wide Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_backlight / Reverse Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_white_subject / Light Center new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_white_subject / Reverse Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_fine_texture / Light Center new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation
- **DLC_photo_fine_texture / Reverse Focus new clipping** : Quality heuristic: >2 percentage points newly SDR-clipped pixels requires inspection, no hidden highlight compensation

### Inspection des planches

La planche décentrée montre le déplacement utile de l’éclairage vers le visage et le premier plan, avec une variation progressive du fond. Sur le portrait sombre, Subtle/Portrait Focus conservent les nuances de peau et les détails des cheveux à l’échelle de la planche ; Dark Surround et Off-Center Drama assombrissent davantage les vêtements et le fond. Sur le contre-jour, les variantes éclaircissantes étendent les plages blanches du soleil/reflet ; sur le sujet blanc, Light Center et Reverse Focus demandent une inspection des textures de robe et du mur. Ces observations ne remplacent pas l’approbation visuelle de l’utilisateur et ne rendent pas les WARN caducs.

Sur la nuit, Dark Surround réduit les valeurs du ciel et des murs, tandis que Reverse Focus relève les bords et la lampe. Les textures restent présentes sur la planche ; les crops 100 % restent la référence pour juger leur lisibilité.

Les cartes EV et profils montrent un champ continu, sans contour ajouté. L’absence de modification de texture par voisinage résulte aussi de l’architecture pointwise : le gain spatial multiplie le signal existant, sans flou, bruit ni sharpen. Cela ne signifie pas que tout réglage extrême est photographiquement discret.

Les crops natifs, cartes de différence et tableaux par région sont disponibles. Les originaux du corpus sont inchangés (SHA256). Les planches photographiques restent locales, conformément au corpus existant ; les rapports, JSON et mires synthétiques sont versionnés. Les archives d’échecs décrivent les étapes corrigées, pas l’état final.

### Performances retenues

| Taille | GPU commande médiane (ms) | CPU préparation (ms) | Mur sans readback (ms) |
|---|---:|---:|---:|
| 1024 | 0.180 | 0.044 | 0.733 |
| 2048 | 0.732 | 0.037 | 2.088 |
| 4096 | 2.908 | 0.037 | 5.045 |

Mesures Apple M2 Pro, cinq répétitions après chauffe ; protocole complet dans la section automatique. [Preuve UI](DarkenLightenCenter/ui_zoom_pan.png), [non-régression](DarkenLightenCenter/existing_effects_regression.json), [rapport commun](DarkenLightenCenter/Common/CreativeFXValidationReport.md).

## Priority Visual Inspection

Première planche : **off_center_real_photos.png**. Les planches réelles restent locales ; les résultats ne sont pas des Golden Masters.

- [off_center_real_photos.png](DarkenLightenCenter/off_center_real_photos.png)
- [ev_field_map.png](DarkenLightenCenter/ev_field_map.png)
- [ev_field_isolines.png](DarkenLightenCenter/ev_field_isolines.png)
- [circle_aspect_ratio.png](DarkenLightenCenter/circle_aspect_ratio.png)
- [rotation.png](DarkenLightenCenter/rotation.png)
- [feather_response.png](DarkenLightenCenter/feather_response.png)
- [center_border_independence.png](DarkenLightenCenter/center_border_independence.png)
- [not_just_a_vignette.png](DarkenLightenCenter/not_just_a_vignette.png)
- [compositional_examples.png](DarkenLightenCenter/compositional_examples.png)
- [RealPhotos/01_portrait_light_skin/portrait_light_focus_comparison.png](DarkenLightenCenter/RealPhotos/01_portrait_light_skin/portrait_light_focus_comparison.png)
- [RealPhotos/02_portrait_dark_skin/portrait_dark_focus_comparison.png](DarkenLightenCenter/RealPhotos/02_portrait_dark_skin/portrait_dark_focus_comparison.png)
- [RealPhotos/03_landscape_clouds/landscape_focus_comparison.png](DarkenLightenCenter/RealPhotos/03_landscape_clouds/landscape_focus_comparison.png)
- [RealPhotos/04_backlight/backlight_focus_comparison.png](DarkenLightenCenter/RealPhotos/04_backlight/backlight_focus_comparison.png)
- [RealPhotos/05_night/night_focus_comparison.png](DarkenLightenCenter/RealPhotos/05_night/night_focus_comparison.png)
- [RealPhotos/07_white_subject/white_subject_focus_comparison.png](DarkenLightenCenter/RealPhotos/07_white_subject/white_subject_focus_comparison.png)
