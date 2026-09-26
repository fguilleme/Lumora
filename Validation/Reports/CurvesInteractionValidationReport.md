# Curves Interaction — validation initiale

Date : 22 septembre 2026. Plateforme : macOS / Xcode iOS 27 Simulator, iPhone compact « Lumora Compact UI » et iPhone 18 Pro Max. Les captures sont des diagnostics ; aucun Golden Master n’a été créé.

## Architecture et périmètre

`EditorView` conserve le canal, le mode édition, la pipette et son échantillon en état UI temporaire. La consultation est l’état initial. Quitter Courbes ou changer de document vide ces états ; seules les courbes réelles restent dans `EditState`. Le renderer Curves, Auto Curves, les styles Natural/Balanced/Punchy, l’interpolation, la conversion Light↔Curves et les autres moteurs ne sont pas modifiés.

En consultation, le `Canvas` du graphe ne reçoit aucun hit test et son geste de tap est désactivé ; le `ScrollView` garde les drags. En édition, chaque point possède une cible de 44 pt autour d’un cercle dessiné plus petit. Un `DragGesture` démarrant sur cette cible déplace le point et groupe le mouvement en une opération d’historique. Le tap de création est un `SpatialTapGesture` du graphe, dans son repère nommé ; sa classification tap/drag reste celle du système, sans seuil inventé. La zone des trois outils dans le coin supérieur droit est exclue de la création. Un drag du fond peut défiler et ne crée jamais de point. Les points proches de moins de 0,03 sur l’axe X sont sélectionnés plutôt que doublés ; les contraintes existantes de 0,02 d’espacement et 16 points maximum restent inchangées. La suppression n’agit que sur un point intérieur sélectionné.

## Pipette et coordonnées

À l’activation, `CurveSamplingBuffer` construit une seule preview bornée à 512 px sur le grand côté. Elle repart de l’original de preview, applique les corrections optiques et la balance des blancs/exposition en amont, puis la géométrie du document. Elle lit une bitmap RGBA flottante en **extended linear sRGB** une seule fois. Chaque déplacement du doigt calcule la moyenne 3 × 3 autour du pixel normalisé, convertit les canaux en sRGB perceptuel, puis applique le décalage tonal de `TonalResponse.map` sans les courbes. Il s’agit donc de l’entrée logique de la courbe, et non de la couleur finale affichée après Curves/Grading/Creative FX. La sortie du marqueur reste dans le domaine 0…1 éditable par Curves.

La courbe RVB prend la même pondération perceptuelle que `TonalResponse.color` (R 0,2126 ; G 0,7152 ; B 0,0722). Rouge, Vert et Bleu utilisent directement leur canal respectif. Changer de canal conserve l’édition et recalcule immédiatement la position du même échantillon. La pipette affiche un trait vertical et un cercle creux mint, un anneau sur la photo et une petite valeur en haut à gauche du graphe. Elle ne modifie ni courbe, ni état Custom, ni historique ; `+` est l’action explicite qui crée un point à cette abscisse sur la courbe courante.

`PhotoCanvas.normalized` convertit la position du doigt en coordonnées image avec l’ajustement aspect-fit, le zoom et le pan déjà utilisés pour les masques ; `sampledImageRect` reconstruit la position de l’anneau avec les mêmes paramètres. La preview de pipette reçoit la géométrie (crop, rotation, miroir) avant la lecture. En pipette, le glissement à un doigt échantillonne ; le pincement reste affecté au zoom. Sur un calque masqué, la pipette est désactivée : le pipeline privé de composition locale n’est pas reproduit par ce tampon, ce qui évite d’afficher une valeur fausse.

## Résultats

| Contrôle | Nature | Résultat | Preuve / limite |
|---|---|---|---|
| Scroll depuis le graphe en consultation | Hard invariant | PASS | 10 drags verticaux/diagonaux sur iPhone compact et grand ; points identiques après chaque geste. |
| Drag du fond en édition | Hard invariant | PASS | Aucun point ajouté ni déplacé dans le parcours UI. |
| Tap de création et point sélectionnable | Hard invariant | PASS | Création depuis un vrai tap, cible 44 pt, sélection accessible sur les deux tailles. |
| Déplacement, suppression et Undo/Redo | Hard invariant | PASS | Drag d’un point, Undo/Redo puis Undo ; ajout et suppression contrôlés sur simulateur compact. |
| Pipette sans création ni historique | Hard invariant | PASS | La courbe et la disponibilité d’Undo restent identiques pendant l’échantillonnage ; `+` seul ajoute un point. |
| RVB/Rouge/Vert/Bleu | Hard invariant | PASS | Mire en pixels linéaires explicites : gris 0/0,18/0,5/0,75/1, primaires et secondaires ; changement RVB→Rouge dans le parcours UI avec échantillon conservé. |
| Zoom, pan et lecture du même point | Hard invariant | PASS | Valeur centrale identique à ±2 points de pourcentage avant/après zoom 2×, puis après pan de 24 pt en suivant le point à l’écran. |
| Crop, rotation par quart de tour, miroir | Hard invariant | PASS | Mire géométrique du cœur ; couleur attendue retrouvée après chaque transformation. |
| Corps des courbes/Auto inchangés | Hard invariant | PASS | Diff limité aux vues et au tampon de lecture ; 110 tests `LumoraCoreTests` réussis. |
| Build iOS et UI deux tailles | Hard invariant | PASS | `xcodebuild build-for-testing` réussi ; parcours UI réussi sur les deux iPhone. |
| Performance du glissement | Quality heuristic | PASS | 4,46–7,20 µs par lecture de 3 × 3 pixels sur le Mac de test ; aucun rendu par mouvement. |
| Temps d’activation | Quality heuristic | WARN | Préparation 56,8–140,2 ms sur quatre photos, médiane 67,6 ms ; l’activation peut produire une courte latence. |
| Pipette sur calque masqué | Quality heuristic | WARN | Délibérément indisponible jusqu’à une lecture fidèle de l’entrée locale des courbes. |
| Couverture des microgestes | Quality heuristic | WARN | Tap réel, drag long et scroll testés ; la série distincte 2/5/10 pt et 100 scrolls n’a pas été automatisée. |
| Mémoire et cycles rapides | Quality heuristic | WARN | Un tampon 512 × 512 × 4 canaux float vaut au maximum 4 MiB et est libéré à la désactivation ; pas de série RSS longue ni de mesure de fuite sur appareil. |
| Validation physique et EXIF complet | Quality heuristic | WARN | Les captures et tests viennent de simulateurs ; la manipulation directe sur iPhone et toutes les orientations EXIF restent à inspecter. |

**Total : 11 PASS, 5 WARN, 0 FAIL.** Aucun WARN ne résulte d’un ajustement automatique du renderer ou des réglages Curves. Les cinq WARN demandent une inspection ou une campagne ciblée ultérieure ; aucune modification esthétique n’a été faite pour les effacer.

## Artefacts et inspection prioritaire

1. [View Mode](../TestArtifacts/CurvesInteraction/view_mode.png) : premier écran à inspecter ; commencer un scroll sur le graphe.
2. [Edit Mode](../TestArtifacts/CurvesInteraction/edit_mode.png) et [point sélectionné](../TestArtifacts/CurvesInteraction/edit_selected_point.png).
3. [Pipette active](../TestArtifacts/CurvesInteraction/eyedropper_active.png) et [échantillon affiché](../TestArtifacts/CurvesInteraction/eyedropper_sample.png).
4. [Échantillons photographiques](../TestArtifacts/CurvesInteraction/eyedropper_samples.png) : portrait clair, paysage, nuit et sujet blanc ; [mesures brutes](../TestArtifacts/CurvesInteraction/eyedropper_samples.json).
5. Les [cinq captures du grand iPhone](../TestArtifacts/CurvesInteraction/large_iPhone/view_mode.png) suivent les mêmes noms dans `large_iPhone/`.

Sur iPhone physique : vérifier un scroll commencé à plusieurs endroits du graphe en consultation ; entrer en édition et déplacer un point ; défiler depuis une zone vide ; vérifier qu’aucun point n’apparaît ; parcourir la photo avec la pipette, ajouter volontairement un point depuis l’échantillon, puis quitter l’édition et reprendre le scroll. Le zoom, le crop et l’orientation méritent une observation directe en plus des tests automatiques.
