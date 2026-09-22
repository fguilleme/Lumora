# Color Grading Presets — validation initiale

**876 PASS / 29 WARN / 0 FAIL** après consolidation du suivi mémoire. La première campagne photographique seule comptait 28 WARN. Les 16 définitions sont restées identiques après la première campagne. Aucun Golden Master, aucun changement de renderer ou de réglages Auto.

## Vérifications techniques

- Neutral bit-identique au Grading neutre.
- Les 16 presets sont bit-identiques à la saisie individuelle de leurs onze réglages visibles.
- 106 tests du cœur réussis : tous les couples de presets, Custom, Undo/Redo, persistence, duplication et conservation des autres modules.
- Parcours UI iPhone réussi : les 16 choix, défilement, cibles >=44 pt, Custom, historique, 36 sélections répétées et réouverture du document. Test iPad réussi ; captures dans le guide.
- Lumora, ses tests iOS et LumoraVisualTestLab compilent.
- 16 configurations manuelles Grading et 110 configurations manuelles Light/Color/Curves/Creative FX restent bit-identiques au checkout antérieur `89c7e73`.
- Auto + Grading, masques simples/inversés/empilés/soustractifs et les quatre stacks demandées passent.

## WARN conservés

| Catégorie | Nombre | Cas / observation |
|---|---:|---|
| HDR existant | 15 | Tous les presets non neutres activent la LUT SDR existante. Les valeurs extended >1 ne sont pas conservées comme avec le bypass Neutral. Aucun NaN/Inf ni rupture importante mesurée. |
| Blancs | 6 | Warm Cinema, Golden Hour et Split Warm/Cool dépassent +0,025 de chroma moyenne sur les crops robe et mur de `07_white_subject`. |
| Proximité | 6 | Neutral/Bleach Grade ; Soft Portrait/Cinematic ; Soft Portrait/Muted Cinema ; Soft Portrait/Pastel ; Cool Portrait/Bleach Grade ; Muted Cinema/Pastel. |
| Mémoire | 1 | Sur 512 sélections, RSS 169,5 → 223,6 → 230,0 → 271,7 Mo. Pas de plateau démontré ; rétention CI/Metal/allocateur possible mais non diagnostiquée. Aucun nouveau cache dans le sélecteur. |
| Capacité du module | 1 | Muted Cinema ne peut pas désaturer globalement l’entrée : le Grading existant ne possède pas ce contrôle. |

La proximité est signalée seulement lorsque les trois distances sont faibles : paramètres <0,035, rampe RGB MAE <0,002, corpus RGB MAE <0,0015. Ce n’est pas un classement esthétique. Les deux plus petites distances photo sont Muted Cinema/Bleach Grade (0,000914) et Soft Portrait/Pastel (0,000923) ; la première ne déclenche pas le test composite car les paramètres sont davantage séparés.

## Photographies

Aucun seuil de contrôle des crops de peau n’est dépassé sur les portraits clair/sombre. Cela ne garantit pas une carnation esthétiquement parfaite : inspection simultanée des deux portraits requise. La planche Portrait montre des écarts modérés ; Warm Portrait est plus chaud, Cool Portrait refroidit discrètement.

Sur le sujet blanc, les six avertissements concernent surtout les looks aux highlights plus chaudes. Les augmentations de chroma moyennes des crops sont : Warm Cinema 0,0281…0,0310 ; Golden Hour 0,0346…0,0389 ; Split Warm/Cool 0,0278…0,0294. Soft Portrait, Warm Portrait et Pastel restent sous ces seuils de revue.

Les contrôles de nuit et de contre-jour, dont lampes, ombres, soleil et reflets, ne déclenchent pas de WARN supplémentaires. Golden Hour sur les images déjà chaudes reste néanmoins à juger visuellement. Aucune optimisation par photographie n’a été faite.

## Performance / sortie

Apple M2 Pro, macOS 26.6.2, Debug. La sélection suivie d’un rendu interactif existant mesure **134,80 ms de médiane**, **137,80 ms P95**, **139,46 ms max** sur 64 sélections. Les capsules ne génèrent aucune thumbnail ; temps cold/warm de thumbnails et cache de thumbnails : non applicables.

Sur six presets, MAE preview/HQ ≤0,004446 et HQ/export ≤0,005880 après normalisation à 256 px, sous le seuil standard de revue de 0,015. Aucune branche de rendu spécifique aux presets. Les temps preset/réglages manuels sont dans `manual_reproduction.md` ; les différences reflètent surtout la chauffe et le cache du même graphe.

Le suivi mémoire prolongé est un **WARN**, pas une validation de stabilité : croissance d’environ 97,5 MiB après le premier cycle chauffé, supérieure au seuil de revue existant de 64 MiB. Aucune optimisation de renderer/cache n’a été tentée dans cette tâche.

Pour reproduire le suivi puis sa consolidation :

```sh
swift test --filter gradingPresetMemoryFollowup
LUMORA_GRADING_FINALIZE=1 swift test --filter gradingFinalizeMemoryReport
```

## Historique et artefacts

La première campagne dure environ 1054 s en Debug, dominée par les statistiques des crops. Les résultats initiaux et le rapport sont archivés dans `TestArtifacts/ColorGradingPresets/ValidationHistory/`. Les seules corrections avant validation concernaient la complexité d’une expression de test Swift et des requêtes/gestes XCTest ; aucun paramètre ou seuil n’a été retouché.

Les [valeurs exactes versionnées](ColorGradingPresetParameters.md) et le [guide](ColorGradingPresets.md) accompagnent le [rapport détaillé](../TestArtifacts/ColorGradingPresetsValidationReport.md). Commencer par [tous les presets](../TestArtifacts/ColorGradingPresets/all_presets_contact_sheet.png), puis [les portraits](../TestArtifacts/ColorGradingPresets/portrait_presets.png), [le sujet blanc](../TestArtifacts/ColorGradingPresets/white_subject_crops.png) et [les distances](../TestArtifacts/ColorGradingPresets/preset_distance_matrix.png).
