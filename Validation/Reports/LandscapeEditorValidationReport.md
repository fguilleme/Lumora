# Landscape Editor — validation du layout iPhone

Date : 23 septembre 2026. Les captures de `Validation/LandscapeValidation/` sont des captures **natives du simulateur**. Les captures XCTest de cet environnement portent une orientation PNG incorrecte en paysage ; elles n'ont pas été utilisées comme artefacts visuels finaux.

## Architecture et périmètre

`EditorWorkspaceLayout` place les deux mêmes sous-vues SwiftUI (canvas et contrôles) verticalement en portrait, horizontalement en paysage iPhone. L'activation exige `userInterfaceIdiom == .phone` et une largeur de zone disponible supérieure à sa hauteur. Le canvas garde son identité lors d'une rotation ou d'un changement de côté, ce qui préserve son état temporaire de zoom/pan dans la mesure permise par SwiftUI. Aucun renderer, EditState, Creative FX ni calcul d'histogramme n'a été modifié.

La largeur demandée pour Controls est `clamp(35 % de la largeur disponible, 248 pt, 340 pt)` ; la photo reçoit le reste. La préférence `editor.controlsSide` utilise `@AppStorage` avec les valeurs sémantiques `leading` et `trailing`. Le placement tient compte de `layoutDirection` pour RTL. Elle est indépendante du document et persiste après rotation, changement de document et relance. Le bouton de 44 pt, accessible sous « Changer le côté des contrôles », se trouve en haut de la colonne. La barre des modules reste horizontale et scrollable ; le contenu du module conserve son propre scroll vertical. Les sliders de cette colonne placent nom/valeur/reset au-dessus de la piste, qui utilise ainsi toute la largeur. Le layout portrait des sliders et de la barre reste inchangé.

L'histogramme reste un overlay du canvas : en paysage compact il vise 36 % de la colonne photo, bornés à 128–220 pt ; agrandi, 78 %. Ses dimensions portrait antérieures sont conservées. Les gestes tap et appui long gardent la même logique. Le header reste hors des deux colonnes et garde les actions Photos, Bibliothèque, Undo/Redo et menu. Les zones sûres sont laissées au conteneur SwiftUI ; les deux orientations paysage ont été exécutées.

## Dimensions et preuve photo

Mesures XCTest en points (frames d'accessibilité du canvas) :

| Appareil simulé | Portrait | Paysage | Photo 2:3 visible en paysage | Contrôles |
| --- | ---: | ---: | ---: | ---: |
| iPhone 13 mini, iOS 27 | 375 × 348 | 462,7 × 311 | ≈207,3 × 311 | largeur de layout ≈299 ; frame AX ≈309–321 |
| iPhone 18 Pro Max, iOS 27 | 440 × 480 | 540,7 × 376 | ≈250,7 × 376 | plafond de layout 340 ; frame AX ≈372 |

Les frames AX de la colonne incluent des descendants/paddings et ne sont pas la largeur proposée par le layout. Sur l'iPhone compact, l'ancien empilement demandait 336 pt de contrôles (252 + 56 + 28) dans une zone de 311 pt : la hauteur restante pour la photo était 0 pt. Le nouveau canvas reçoit 311 pt. `Validation/LandscapeValidation/portrait_photo_before_after.png` indique explicitement que la valeur « avant » est dérivée du code, pas une ancienne capture. Les captures 2:3, 1:1 et 3:2 vérifient l'`aspect fit` sans étirement. Le 3:2 remplit presque toute la colonne photo.

## Résultats

| Contrôle | Type | État | Évidence |
| --- | --- | --- | --- |
| Build Lumora et bundle de tests UI | hard | PASS | `xcodebuild build` puis `xcodebuild test` sur iPhone 13 mini et Pro Max |
| Photo visible en paysage compact/grand | hard | PASS | frames ci-dessus, captures 2:3/1:1/3:2 |
| `leading` / `trailing`, RTL par placement sémantique | hard | PASS | test des deux côtés ; branche RTL inspectée dans le layout, sans simulateur RTL dédié |
| Persistance côté après rotation et relance | hard | PASS | `testLandscapeColumnsSidePreferenceAndRotation` |
| Side switch sans Undo ni nouveau rendu | hard | PASS | état Undo inchangé et valeur de génération du canvas identique |
| Rotation portrait → landscapeLeft → portrait → landscapeRight | hard | PASS | test UI compact et grand, sélection Courbes/Edit conservée |
| Histogramme sur la photo, tap, appui long | hard | PASS | `testLandscapeHistogramAndSlider` et 2 tests `HistogramOverlayUITests` |
| Curseur Lumière utilisable et Undo actif | hard | PASS | test UI d'ajustement d'exposition, capture de la piste pleine largeur |
| Courbes en Edit, point sélectionné, rotation | hard | PASS | test UI compact et grand ; aucun changement mathématique de courbe |
| Creative, Couleur, Grading, Effets, Masques accessibles | hard | PASS | tests UI et captures de chaque panneau |
| Portrait inchangé | hard | PASS | capture `portrait_non_regression.png`, test `CompactEditorUITests` et tests histogramme |
| iPad / Mac | qualité | WARN | branche paysage limitée explicitement à l'iPhone ; aucun run UI iPad/Mac dans cette campagne |
| Gestes fins masque/zoom/pan sur appareil réel | qualité | WARN | canvas partagé et panneau Masques capturé ; manipulation tactile complète à inspecter sur appareil |
| Balayage très rapide de la barre des modules | qualité | WARN | sur mini, un flick XCTest saute plusieurs onglets ; un glissement court atteint les onglets intermédiaires |

**Bilan : 11 PASS, 3 WARN, 0 FAIL.** Les WARN concernent la couverture ergonomique et les plateformes non exécutées, pas un échec de rendu. Le test portrait historique attendait à tort `isHittable` pour le graphe Courbes en View Mode ; il vérifie maintenant que le graphe est réellement visible dans le scroll, conformément au mode passif existant. Le premier parcours XCTest de la barre des modules utilisait un flick qui dépassait les onglets intermédiaires ; le scénario final utilise un glissement court. Ces deux corrections ne modifient pas la production photographique.

## Performance, transactions et limites

Le switch côté et la rotation à l'état idle ont conservé la même génération de rendu dans les tests des deux tailles ; **0 rerender déclenché** observé. Le changement de côté n'a pas modifié l'état Undo. Aucune préparation CPU/GPU photo supplémentaire n'a été ajoutée au layout ; seule la disposition SwiftUI est recalculée. Aucune mesure en millisecondes de layout, de mémoire, ni de session prolongée n'a été réalisée. Si une rotation termine une interaction de slider ou de masque déjà active, `finishInteraction()` clôt sa transaction existante ; cette fin d'édition peut lancer le rendu normal de l'ajustement, ce qui est distinct d'un rerender dû au layout.

Les safe areas sont visibles sur les captures landscapeLeft et landscapeRight et les contrôles restent dans le conteneur. Le bouton de côté et les actions principales ont une cible de 44 pt. Une revue manuelle sur iPhone reste recommandée pour le pan/pinch à fort zoom, le déplacement/feather d'un masque et le comportement à taille de texte élevée. Le placement RTL est sémantiquement codé mais n'a pas été validé dans un simulateur arabe/hébreu.

## Captures à inspecter

1. `Validation/LandscapeValidation/portrait_photo_before_after.png` — comparaison mesurée 2:3.
2. `Validation/LandscapeValidation/controls_leading.png` et `Validation/LandscapeValidation/controls_trailing.png` — même image et mêmes réglages.
3. `Validation/LandscapeValidation/light_panel.png` — largeur utile des sliders.
4. `Validation/LandscapeValidation/curves_panel.png` — graphe dans la colonne.
5. `Validation/LandscapeValidation/creative_panel.png`, `Validation/LandscapeValidation/color_panel.png`, `Validation/LandscapeValidation/grading_panel.png`, `Validation/LandscapeValidation/effects_panel.png`, `Validation/LandscapeValidation/masks_panel.png`.
6. `Validation/LandscapeValidation/landscape_photo.png`, `Validation/LandscapeValidation/square_photo.png`, `Validation/LandscapeValidation/aspect_landscape.png`.
7. `Validation/LandscapeValidation/portrait_non_regression.png`.

Les captures sont des artefacts de validation et non des Golden Masters. L'implémentation/tests et la documentation/artefacts sont conservés dans deux commits séparés.
