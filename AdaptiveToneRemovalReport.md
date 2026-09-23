# Retrait d’Adaptive Tone de la production

Décision : retirer le contrôle manuel Phase 6 après l’essai sur iPhone (gain visuel faible, indicateur Working persistant et interface bloquée). Aucun changement d’heuristique Auto ni tentative d’optimisation de Phase 6 n’a été effectué.

## Fichiers de production retirés ou restaurés

- `Lumora/Rendering/AdaptiveToneRenderer.swift` et `Lumora/Rendering/AdaptiveToneShaders.metal.txt` : supprimés ; aucun chargement ni compilation de ces kernels par l’app.
- `Lumora/Editor/EditState.swift` : champ, clé de sérialisation et validation `adaptiveTone` supprimés.
- `Lumora/Editor/EditorSession.swift`, `Lumora/UI/EditorView.swift`, `Lumora/Presets/Preset.swift` : setter, reset, curseur et propagation dans les presets retirés.
- `Lumora/Rendering/RenderEngine.swift` : stage Metal et champs device/renderer du stage retirés.
- `Lumora/fr.lproj/Localizable.strings` : clé « Adaptatif » retirée ; la région `fr` ajoutée pour cette seule clé a été retirée du projet.
- `Package.swift` : plus de source ni ressource Adaptive Tone dans `LumoraCore` ; les exclusions nécessaires aux prototypes expérimentaux du Visual Test Lab sont conservées.
- `Tests/LumoraCoreTests/AdaptiveToneIntegrationTests.swift` et `Tests/LumoraVisualTestLab/AdaptiveToneProductionIntegration.swift` : tests de la fonctionnalité Phase 6 supprimés. Un test de compatibilité des documents anciens et des tests de régression du retrait les remplacent.
- `README.md` : Adaptive Tone est de nouveau décrit comme recherche hors production. Le rapport et les planches Phase 6 demeurent archivés comme diagnostics.

Les fichiers Swift de production concernés sont revenus **octet pour octet à `HEAD`** avant Phase 6 ; `git diff` ne montre plus de changement dans ces fichiers. Les autres modifications préexistantes du projet, notamment les options Mac Catalyst du `.pbxproj`, n’ont pas été incorporées au retrait.

## Pipeline et compatibilité

Le pipeline est rétabli à **Optics → WB → Exposure → TonalResponse/Light existant → géométrie → calques masqués → détail/grain → Creative FX**. La preview, HQ et l’export utilisent à nouveau exclusivement ce graphe. `rg` dans `Lumora` et `strings` sur le binaire iOS n’ont trouvé ni `adaptiveTone`, ni `AdaptiveToneRenderer`, ni `AdaptiveToneShaders`, ni « Adaptatif ». Le bundle iOS ne contient aucune ressource Adaptive Tone.

Le décodeur `EditState` ignore les clés JSON inconnues. Le test `obsoleteAdaptiveToneDocumentLoadsAndSavesWithoutField` importe une photo, insère `"adaptiveTone":100` dans son vrai sidecar `edits.json`, charge le document via `DocumentStore`, vérifie le même état et les mêmes pixels que sans ce champ, puis sauvegarde : la nouvelle version ne contient plus `adaptiveTone`. Aucun renderer Adaptive Tone ne peut être invoqué par ce document.

Le runner Phase 3 sous `Tests/LumoraVisualTestLab/AdaptiveToneMetalPrototype` pointe à nouveau vers son propre `Shaders.metal`. Il a été compilé et exécuté indépendamment après retrait (1024×1536, sortie finie). Les prototypes Phase 1–5, leurs shaders, rapports et artefacts de recherche ont été conservés.

## Working, Light, Auto et rendu

Le nouveau test UI `AdaptiveToneRemovalUITests` sur simulateur iPhone 18 Pro Max a réussi : aucun curseur Adaptatif, plusieurs déplacements d’Exposition, passage à Couleur, retour à Lumière, nouvelle manipulation, disparition de l’indicateur de rendu et interface encore réactive. Le test UI Auto existant a également réussi pour Auto Light, Auto Color, Auto Curves, Undo/Redo et persistance. Les 112 tests du cœur ont réussi, couvrant les réglages Light, Auto, courbes, Color, Grading, masques, Creative FX, preview, HQ, export, historique et documents. Les heuristiques Auto n’ont pas été modifiées.

Une mesure diagnostique sur les mêmes sources Phase 6 conservées a relevé, sur Apple M2 Pro/macOS, **21,9 ms médian** pour cinq rendus HQ neutres 1365×2048 après chauffe ; douze manipulations Light en qualité interactive se terminent et réutilisent le cache photo après le premier changement de qualité. L’export JPEG neutre 2048×3072 s’est terminé en **169,3 ms**. Les relevés historiques Phase 6 donnaient 128,1 ms pour HQ 2048 avec Adaptatif 100 et 536,5 ms pour l’export 3072 avec Adaptatif 100 ; ces runs ne sont pas un benchmark contrôlé sur appareil, mais confirment la disparition du coût Adaptive Tone. Voir `AdaptiveToneIntegration/removal_performance.json` et `pipeline.json`.

Deux **anciens** tests UI supplémentaires ont échoué sur des attentes sans lien avec le retrait :

1. `EditorUITests.testExportOptionsAndShare` arrive bien à « Export terminé », puis exige que le résultat contienne exactement `2048`, alors que l’export conserve la taille d’un original plus petit (pas d’upsampling).
2. `EditorUITests.testPhotosImportEditUndoAndRestore` réussit les étapes Lumière, Undo/Redo et navigation initiales, puis cherche « Ajouter un point » sans activer le mode Édition des courbes introduit antérieurement.

Ces tests ont été laissés inchangés pour ne pas affaiblir leur contrat dans cette tâche. Leur échec empêche de déclarer **toutes** les régressions réussies. Après ce premier bilan, l’utilisateur a explicitement demandé le commit du retrait ; les deux échecs restent documentés. Le test de retrait et le test UI Auto, eux, passent. Le workflow doit encore être répété sur l’iPhone physique pour confirmer que l’incident Working observé par l’utilisateur a disparu sur cet appareil.

## Builds et résultats

| Vérification | Résultat |
|---|---|
| Build Lumora iOS Debug | PASS |
| LumoraCoreTests | PASS — 112 tests |
| Ancien document Phase 6, rendu, resauvegarde | PASS |
| Test UI retrait/Working | PASS — 1 test |
| Test UI Auto Light/Color/Curves | PASS — 1 test |
| Régression Light/preview/HQ/export diagnostic | PASS |
| Prototype Metal de recherche indépendant | PASS |
| Deux anciens tests UI éditeur/export | FAIL — attentes obsolètes décrites ci-dessus |
| Validation sur l’iPhone physique après retrait | À refaire |

L’arbre de travail contient toujours les prototypes et artefacts R&D non suivis déjà présents avant ce retrait. Ils n’ont pas été supprimés. Aucun algorithme de remplacement n’a été ajouté.
