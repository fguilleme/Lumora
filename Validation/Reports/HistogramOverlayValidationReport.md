# Histogramme flottant — validation initiale

## Ancien comportement et cause du pic droit

L'éditeur réservait au-dessus de la photo une ligne d'histogramme de 52 pt plus 8 pt de marge verticale. Le graphe était normalisé linéairement par le bin le plus haut. `RenderEngine` produit un `CGImage` Display P3 **8 bits SDR** ; `Histogram.compute` le redessine en sRGB 8 bits sur 160 × 160 pixels, puis compte exactement les codes 0…255 de chaque canal. Ainsi le pic au bord droit est un vrai compte du **code 255 de l'aperçu SDR**, renforcé visuellement par l'ancienne normalisation linéaire. Il peut contenir du blanc diffus, des hautes lumières et des valeurs > 1 déjà comprimées ou écrêtées lors du rendu SDR. Il ne mesure pas l'écrêtage irrécupérable du RAW.

## Convention finale et modèle de clipping

Les 256 bins RVB restent des comptes d'échantillons du même aperçu, sans changement de calcul photographique. Le bin 0 correspond au code sRGB 0 et le dernier bin au code sRGB **255** après conversion. Une mire RGBA float linéaire contenant 0, 0,01, 1 et 4 confirme que 1 et 4 aboutissent tous deux au bord droit de cet histogramme : l'information HDR n'est plus distinguable à cette étape. La planche 0→4 représente la projection SDR de ce cas ; le test Core utilise, lui, une vraie source RGBA float.

Le diagnostic « Noirs » compte un échantillon si **tous** ses canaux sont ≤ 1 ; « Blancs » compte un échantillon si **au moins un** canal est ≥ 254. Ces seuils désignent la proximité de l'extrémité **d'affichage**, pas la récupération possible de la source. Les compteurs et fractions sont accessibles via VoiceOver même si l'alerte visuelle est absente. Un indicateur visuel apparaît seulement quand la fraction atteint **0,2 %** des 25 600 échantillons, soit au moins 52 pixels échantillonnés. Son opacité augmente avec la racine carrée de l'occupation. Le seuil prévient l'alerte voyante pour un seul pixel aberrant, au prix d'une possible absence de signal pour un petit reflet réellement saturé.

Le graphe affiche `sqrt(count / peak)` au lieu de `count / peak`. Pour un bin de 100 face à un pic de 10 000, la hauteur vaut 10 % avec la racine, contre 1 % en linéaire ; une échelle logarithmique donnerait environ 50 % et aplatirait davantage la hiérarchie. Seule la hauteur dessinée change : les comptes et les tests des bins restent linéaires. Les trois canaux continuent de se superposer en mode additif.

## UI, espace et interactions

L'histogramme est superposé au `PhotoCanvas`, en haut à gauche du rectangle de l'image ajustée à la zone d'aperçu. Il reste ancré à cette zone lors du zoom et du pan ; ses données décrivent toujours l'image entière développée, après géométrie/crop, jamais le viewport. Le bouton ne capture que son rectangle ; un glissement commencé ailleurs reste un geste photo. Le tap alterne les deux états avec animation de 0,18 s. L'état `@State` est temporaire, initialisé compact pour chaque document, absent d'`EditState` et des sidecars. Agrandir ne relance pas `Histogram.compute` : le même `RenderResult.histogram` alimente les deux dessins. Le pipeline de preview continue de remplacer les résultats au rythme de rendu existant dans l'actor, hors MainActor.

Sur une photo dont la largeur affichée est 390 pt : **compact 164 × 62 pt** (42 % de la largeur ; plafond à 220 pt), **agrandi 328 × 150 pt** (84 %). Le bouton compact dépasse la cible tactile de 44 pt. La bande verticale supprimée libère **60 pt de hauteur de canvas**. Pour une image portrait 2:3 dans une zone de 390 × 600 pt, le fit théorique passe de 360 × 540 pt (ancien canvas de 390 × 540 pt) à 390 × 585 pt, soit **45 pt de hauteur photo visible gagnés** ; le gain exact dépend du ratio et de la taille réelle du viewport. La source `07_flat_foggy_landscape.png` étant en réalité verticale 2:3, les planches horizontales utilisent un crop central 3:2 de cette photo, sans modifier le corpus. Elles montrent que l'overlay reste dans l'image et que les barres noires ne sont pas prises pour la zone photo. Le test iPhone confirme que la hauteur du canvas ne varie pas entre compact et agrandi.

## Campagne

**Bilan : 8 PASS / 2 WARN / 0 FAIL.** Les WARN décrivent des limites de diagnostic et de validation sur appareil, pas une régression du rendu.

| Contrôle | Nature | Résultat |
|---|---|---|
| Build Lumora iOS Simulator | hard | PASS |
| 115 tests `LumoraCoreTests`, dont 3 tests histogramme dédiés | hard | PASS |
| Bins 0, 1, 118, 253, 254, 255 ; rampes ; canal R/G/B isolé | hard | PASS |
| Source RGBA float linéaire 0/0,01/1/4, résultat fini et bord SDR | hard | PASS |
| Un pixel blanc sur 25 600 vs 50 % de pixels blancs | hard | PASS — 1/25 600 reste sans alerte visuelle ; 50 % l'affiche |
| iPhone Simulator : tap compact/agrandi/compact, glissement extérieur, canvas stable | hard | PASS — 1 test XCTest UI |
| Agrandissement sans nouveau calcul histogramme | hard | PASS — même donnée `Histogram`, aucun appel dans la vue |
| Quatre photos du corpus stress et un crop horizontal supplémentaire | diagnostic | PASS — planche générée |
| Identification d'un écrêtage irrécupérable du RAW | limite | WARN — impossible depuis l'aperçu SDR ; aucune telle affirmation dans l'UI |
| Validation ergonomique sur iPhone physique et tous les ratios extrêmes | qualité | WARN — inspection humaine encore nécessaire |

Sur les quatre photos brutes du corpus diagnostique, la fraction d'échantillons près du blanc SDR est de **0,66 %** (portrait intérieur sombre), **39,94 %** (portrait plage surexposé), **0,70 %** (nuit pluvieuse) et **0 %** (paysage brumeux). Les chiffres sont les codes d'affichage des images du corpus, pas une mesure du capteur. Le cas de plage révèle une large occupation du bord droit ; la petite source lumineuse de nuit reste visible numériquement sans dominer le graphe. Les comptes détaillés sont dans `Validation/HistogramValidation/clipping_diagnostics.json`.

## Performance et non-régression

Sur Apple M2 Pro/macOS, après chauffe, la médiane de 40 calculs histogramme 160 × 160 sur le portrait est **3,83 ms**. Les snapshots SwiftUI réutilisant ces bins prennent **0,82 ms** en compact et **1,01 ms** en agrandi (8 répétitions chacun). La différence concerne la surface dessinée ; le mode agrandi effectue **zéro calcul histogramme supplémentaire**. Ce sont des mesures locales macOS, pas une garantie de latence sur iPhone. `RenderEngine`, Light, Color, Curves, Auto et tous les traitements photographiques sont inchangés. Les tests Core existants de rendu et d'export passent ; le build iOS et le test UI ciblé passent. Aucun nouvel accès CPU aux pixels par frame d'animation n'a été ajouté.

## Artefacts à inspecter

- `Validation/HistogramValidation/iphone_compact.png` et `Validation/HistogramValidation/iphone_expanded.png` : captures de l'éditeur iPhone Simulator.
- `Validation/HistogramValidation/compact_portrait.png`, `expanded_portrait.png`, `compact_landscape.png`, `expanded_landscape.png` : rendu de la vraie vue SwiftUI sur les photos portrait/paysage du corpus, dans un canevas de validation.
- `Validation/HistogramValidation/clipping_cases.png` : dix mires synthétiques, histogramme agrandi.
- `Validation/HistogramValidation/photo_histograms.png` : quatre photos du corpus avec histogramme agrandi.
- `Validation/HistogramValidation/clipping_diagnostics.json` et `measurements.json` : comptes et temps mesurés.

Les planches synthétiques et corpus sont des diagnostics, pas des Golden Masters. L'inspection humaine de l'overlay sur appareil reste à faire avant toute retouche esthétique.
