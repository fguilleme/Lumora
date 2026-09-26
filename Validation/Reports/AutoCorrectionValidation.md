# Auto — première campagne de validation

## Mise à jour WB

Le bilan ci-dessous décrit la **première campagne, avant correction WB**. Une correction localisée et explicitement autorisée a depuis résolu les quatre WARN WB : [mesures, mapping et régression](AutoWBMapping.md). Bilan courant consolidé : **782 PASS, 3 WARN, 0 FAIL**. Les valeurs initiales ci-dessous sont conservées comme historique ; l’analyse et les autres heuristiques n’ont pas changé.

## Résultat initial

669 PASS, 7 quality WARN, 0 FAIL. Les contrôles ne remplacent pas l’inspection photographique. Les premières heuristiques sont gelées ; aucun Golden Master Auto n’a été créé.

- 105 tests du cœur passent.
- Lumora, les tests iOS et LumoraVisualTestLab compilent.
- Le scénario UI complet passe sur iPhone 18 Pro / iOS 27 Simulator : boutons, édition, Auto/Custom, Undo/Redo, styles de courbes, absence de double correction et réouverture des points persistés.
- 110 configurations manuelles et presets Creative FX sont bit-identiques au commit antérieur `89c7e73`.
- 157 contrôles supplémentaires vérifient notamment le déterminisme, les réapplications, les bornes, les ordres d’action, les primitives réelles, les outliers et la direction de correction d’une photographie exposée à −2 EV / +1 EV.

Le rapport final regroupe la campagne initiale, ces contrôles supplémentaires et la revalidation technique. Les huit intentions et courbes photographiques restent identiques à la première campagne.

## WARN conservés

| Cas | Résultat | Inspection |
|---|---|---|
| Dominantes connues chaude, froide, verte, magenta | Quatre WARN : l’adaptation Temperature/Tint accentue la dominante malgré une confiance élevée | `Auto/wb_intent_validation.png` |
| Mire sous-exposée contenant de grandes zones HDR | Pas de correction EV positive ; la photographie normalement distribuée sous-exposée est, elle, corrigée dans le bon sens | `Auto/Synthetic/underexposed.png`, `Auto/known_photo_exposure_comparison.png` |
| Courbe aux highlights comprimées | Approximation inverse médiocre, erreur maximale 0,07232 | `Auto/curve_light_curve_roundtrip.png` |
| Courbe à plusieurs changements locaux | Approximation inverse médiocre, erreur maximale 0,10888 | Même planche |

La faiblesse WB est une limitation fonctionnelle réelle, pas un succès technique. Aucune inversion d’axe, modification de force ni adaptation esthétique n’a été effectuée après les résultats. Les scènes volontairement orange, verte et bleue sans candidats neutres conservent leur dominante ; cela ne valide pas la correction des vraies dominantes.

## Lumière et courbes

Sur les huit photographies : MAE moyenne de l’axe neutre SDR **0,0011601**, erreur maximale **0,0038051**. Pour les pixels photographiques, MAE moyenne **0,0017711**, erreur maximale **0,051726**. La courbe RVB agit par canal alors que Lumière agit par delta de luminance ; les modèles ne sont pas parfaitement équivalents. Les LUT existantes restent SDR : l’analyse HDR ne transforme pas les renderers manuels en nouveaux renderers HDR. Les erreurs 1…8 sont détaillées séparément dans le rapport.

La nuit reste sombre, le sujet blanc reste clair et le contre-jour conserve sa dominante chaude selon les contrôles conservateurs. L’inspection humaine des planches reste nécessaire.

## Performances

Apple M2 Pro, macOS 26.6.2, build Debug. Mesures en millisecondes, pas de promesse de latence sur appareil iOS physique.

| Opération | Médiane | P95 | Maximum |
|---|---:|---:|---:|
| Analyse initiale + proposition | 2210,49 | 2366,41 | 2502,44 |
| Analyse depuis le cache | 0,0648 | 0,0710 | 0,0841 |
| Intention | 0,00246 | 0,00508 | 0,384 |
| Mapping Lumière | 0,0177 | 0,0243 | 0,048 |
| Mapping Couleur | 0,00883 | 0,00896 | 0,0126 |
| Lumière → Courbe | 103,56 | 106,22 | 107,96 |
| Courbe → Lumière | 65,04 | 67,98 | 86,92 |

L’analyse est asynchrone avec un retour visuel léger. Le cache contient une seule proposition sans preview retenue. Sur 48 cycles, les échantillons RSS passent de 153,3 à 117,2, 93,4 puis 105,7 Mo : aucune croissance permanente observée.

## Corrections techniques après les premiers tests

1. Une erreur d’arrondi dans une courbe identité activait inutilement la LUT SDR et ramenait 8 à 1. Reconnaissance de l’identité à 1e-12 avec sondes SDR **et** HDR, puis stockage de la courbe identité native.
2. Undo entre styles restaurait les points mais conservait la préférence locale du bouton : l’état pouvait afficher Personnalisé. Le style affiché est maintenant reconnu à partir des points effectivement restaurés.
3. Un premier geste de test ne changeait pas réellement le curseur : le scénario vérifie désormais le changement effectif avant d’attendre Personnalisé. Il s’agissait d’un défaut de test.

L’historique détaillé reste dans `Validation/TestArtifacts/Auto/ValidationHistory/initial_failures.json`, avec les mesures et le rapport initial. Aucun seuil ni réglage photographique n’a changé.

## Reproduction

```sh
swift test --filter LumoraCoreTests
swift test --filter autoCorrectionValidation
swift test --filter autoSupplementaryInvariants
```

La campagne complète nécessite le corpus existant sous `Validation/VisualTestAssets/` et un GPU Core Image/Metal. Elle génère des diagnostics sous `Validation/TestArtifacts/`, répertoire volontairement non versionné comme pour les autres campagnes. Le test iOS est `AutoCorrectionUITests` dans le scheme Lumora.

`autoManualAndCreativeNonRegression` utilise `LUMORA_AUTO_REGRESSION=record` dans le checkout pré-Auto et `compare` dans le checkout courant ; les buffers temporaires de comparaison sont sous `/private/tmp/lumora-auto-reference-89c7e73`. Le test reste inactif sans cette variable. `LUMORA_AUTO_FINALIZE=1` active la consolidation de la campagne initiale archivée avec les contrôles supplémentaires ; cette consolidation nécessite les JSON de la campagne et la comparaison de non-régression.

## Inspection

Ouvrir d’abord [la planche du corpus](../TestArtifacts/Auto/real_photos_contact_sheet.png), puis [WB](../TestArtifacts/Auto/wb_intent_validation.png), [nuit](../TestArtifacts/Auto/night_intent_validation.png), [high-key](../TestArtifacts/Auto/high_key_intent_validation.png), [contre-jour](../TestArtifacts/Auto/backlight_intent_validation.png) et [équivalence Lumière/Courbe](../TestArtifacts/Auto/light_curve_equivalence_priority.png).

Le [rapport complet](../TestArtifacts/AutoCorrectionValidationReport.md) contient les tableaux par photographie, erreurs SDR/HDR, métriques, contrôles hard/quality et tous les artefacts prioritaires. Aucune retouche des heuristiques ne doit précéder la validation humaine.
