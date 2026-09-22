# Auto Color — correction du mapping WB

## Portée

Correction autorisée après la première campagne : seule la traduction de l’intention WB vers les curseurs existants change. Le renderer Color, la détection des candidats neutres, la confiance, les seuils, les protections de scènes intentionnelles, Saturation/Vibrance, Light et Curves restent inchangés. La calibration utilise uniquement une rampe neutre ; les huit photos servent à la validation.

## Mesure du renderer

# Production Color axes — pre-fix empirical measurement

Linear gray ramp .03… .63, unchanged production graph. Log ratios are signed chromatic coordinates, not UI units.

| Control | Value | log(R/B), warm+ | log(G/sqrt(RB)), green+ | Mean chroma |
|---|---:|---:|---:|---:|
| temperature | -16.0 | 0.14187753140583584 | 0.017482368466718676 | 0.045836621065973304 |
| temperature | -8.0 | 0.06744469106924335 | 0.007718992476827948 | 0.022041291020286735 |
| temperature | -4.0 | 0.03292318263714205 | 0.003631240905120229 | 0.010814083791046869 |
| temperature | 4.0 | -0.03144239776392883 | -0.0032346882384658624 | 0.01042081189370947 |
| temperature | 8.0 | -0.06147253892975571 | -0.007620323696063266 | 0.020475628240092192 |
| temperature | 16.0 | -0.11765559971439911 | -0.015960128782062755 | 0.03956226129230345 |
| tint | -12.0 | 0.004996793346123546 | -0.04311188800883366 | 0.015173222323937807 |
| tint | -6.0 | 0.002529378859492432 | -0.021582072525285254 | 0.007570204128569458 |
| tint | -3.0 | 0.0012735439942486485 | -0.010799418531144002 | 0.00378167782764649 |
| tint | 3.0 | -0.0012835548142144878 | 0.010805053169988596 | 0.003769650291360449 |
| tint | 6.0 | -0.0025854658462383753 | 0.02162807608410804 | 0.007532481802627444 |
| tint | 12.0 | -0.005237294860531189 | 0.043319072494803414 | 0.01503259752644226 |

## Interpretation and mapping

Temperature positive cools / negative warms. Tint positive greens / negative shifts magenta. Central differences at ±4 / ±3 give J = [[−0.008045697550, −0.000426183135], [−0.000858241143, +0.003600745284]] per UI unit. The axes are separated by 89.3387°, sufficiently independent for a stable 2×2 inverse, with measurable coordinate cross-coupling. Symmetric Temperature slopes at ±4/±8/±16 are −.00804570 / −.00805733 / −.00811041 (0.80% span); Tint slopes at ±3/±6/±12 are .003600745 / .003600846 / .003601290 (0.015% span). Response is approximately linear near zero, not globally symmetric or exact.

M = −inverse(J) × diag(J) = [[−.987531890276, +.052309875438], [−.235379187216, −.987531890276]]. Applying M to the existing confidence-weighted, rounded intent corrects polarity and first-order cross-coupling while retaining existing diagonal amplitudes. It does not recalibrate exposure, detection, confidence, saturation or vibrance, and does not aim at complete neutralization. Final controls retain ±16/±12 bounds and integer rounding. No corpus fitting.

## Résultats avant/après

# WB mapping results

| Synthetic cast | Estimated T / tint intent (unchanged) | UI Temperature | UI Tint | Confidence | Before chroma | Previous after | Fixed after |
|---|---|---:|---:|---:|---:|---:|---:|
| Auto color true_warm_cast | -14.0 / -0.0 | 14.0 | 3.0 | 0.999999706552197 | 0.07260000886162743 | 0.11238222290558042 | 0.03979243819776457 |
| Auto color true_cool_cast | 14.0 / -0.0 | -14.0 | -3.0 | 0.9999996225761727 | 0.07260000886162743 | 0.11437864659819752 | 0.03228728330577724 |
| Auto color true_green_cast | -0.0 / 10.0 | 1.0 | -10.0 | 0.9999997633734021 | 0.0396000011896831 | 0.05556844572129194 | 0.028596139134606346 |
| Auto color true_magenta_cast | -0.0 / -12.0 | -1.0 | 12.0 | 0.9999996382876359 | 0.04620001521107042 | 0.06378081846196437 | 0.033897668137797154 |

## Photographs — fresh analysis

| Photo | Previous T / tint | Fixed T / tint | Confidence | Changed |
|---|---|---|---:|---|
| 01_portrait_light_skin | -0.0 / -0.0 | 0.0 / 0.0 | 0.0 | false |
| 02_portrait_dark_skin | -0.0 / -0.0 | 0.0 / 0.0 | 0.0 | false |
| 03_landscape_clouds | 0.0 / 0.0 | 0.0 / -0.0 | 0.0 | false |
| 04_backlight | 0.0 / -0.0 | -0.0 / 0.0 | 0.0 | false |
| 05_night | 0.0 / -0.0 | -0.0 / 0.0 | 0.0 | false |
| 06_indoor_high_contrast | -0.0 / 0.0 | 0.0 / 0.0 | 0.0 | false |
| 07_white_subject | -2.0 / -0.0 | 2.0 / 0.0 | 0.26837553858887553 | true |
| 08_fine_texture | -0.0 / -0.0 | 0.0 / 0.0 | 0.0 | false |

Les quatre réductions de dominante connue sont désormais des exigences fonctionnelles **hard**. Le neutre reste neutre. Les scènes orange, verte et bleue gardent une confiance WB nulle et des curseurs WB nuls. L’éclairage mixte reste traité prudemment sans neutralisation forcée.

## Validation

- Campagne ciblée : **128 PASS, 0 WARN, 0 FAIL**.
- Bilan consolidé : **782 PASS, 3 WARN, 0 FAIL**. Les trois WARN restants sont antérieurs et sans rapport avec le mapping WB : mire sous-exposée riche en HDR et deux approximations Curve → Light.
- 105 tests du cœur et scénario UI Auto réussis, notamment Undo/Redo Couleur.
- Build Lumora, tests iOS et Visual Test Lab réussis.
- 110 configurations manuelles/Creative FX bit-identiques à `89c7e73`.
- Idempotence, bornes, cache, persistence des paramètres et des pixels validés. Les analyses/intents des huit photos restent exactement identiques ; seule `07_white_subject` change de WB.

Les observations scalaires antérieures nécessaires au test sont versionnées sous `Tests/LumoraVisualTestLab/Fixtures/AutoWB/` ; ce ne sont pas des Golden Masters d’images. Les images et le rapport initial restent dans `TestArtifacts/Auto/ValidationHistory/pre_wb_mapping_fix/`.

```sh
swift test --filter autoWBRendererCharacterization
swift test --filter autoWBMappingValidation
swift test --filter LumoraCoreTests
```

Les photos existantes de `VisualTestAssets` et un GPU Core Image/Metal sont requis. `LUMORA_WB_FINALIZE=1 swift test --filter autoWBFinalizeReport` consolide le rapport lorsqu’on dispose également des artefacts archivés de la campagne initiale et de la comparaison des renderers.

## Artefacts

- [Axes mesurés](../TestArtifacts/Auto/WB/renderer_axis_characterization.png) et [tableau](../TestArtifacts/Auto/WB/renderer_axis_characterization.md).
- [Paramètres et chroma](../TestArtifacts/Auto/WB/wb_mapping_results.md).
- [Photo modifiée avant/après](../TestArtifacts/Auto/WB/real_photo_before_after.png).
- [Mires WB](../TestArtifacts/Auto/wb_intent_validation.png).
- [Comparaison Gray World](../TestArtifacts/Auto/gray_world_vs_auto_color.png).
- [Corpus actualisé](../TestArtifacts/Auto/real_photos_contact_sheet.png).
- [Rapport consolidé](../TestArtifacts/AutoCorrectionValidationReport.md).

Les autres planches n’ont pas été régénérées : elles restent des diagnostics de la campagne initiale. Inspection humaine attendue ; aucun autre tuning effectué.
