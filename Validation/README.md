# Validation Lumora

Ce dossier regroupe les tests, les corpus, les rapports, les scripts et les artefacts de validation. Il est séparé du code de production (`../Lumora/`). Les images de campagne restent des diagnostics : ce déplacement ne crée ni n’approuve de Golden Masters.

## Où chercher

| Contenu | Emplacement |
|---|---|
| Tests unitaires et intégration du cœur | [Tests/LumoraCoreTests](Tests/LumoraCoreTests) |
| Banc photographique Core Image / Metal | [Tests/LumoraVisualTestLab](Tests/LumoraVisualTestLab) |
| Tests UI iPhone / iPad | [LumoraUITests](LumoraUITests) |
| Scripts de lancement | [Scripts](Scripts) |
| Protocole du Visual Test Lab | [Documentation/VISUAL_VALIDATION.md](Documentation/VISUAL_VALIDATION.md) |
| Rapports transversaux auparavant à la racine | [Reports](Reports) |
| Corpus photographique commun | [VisualTestAssets](VisualTestAssets) |
| Corpus et campagnes Beauty | [BeautyValidation](BeautyValidation) |
| Intégration de l’UI Beauty et captures | [BeautyIntegration](BeautyIntegration), [ProductionBeautyAudit](ProductionBeautyAudit) |
| Corpus Auto Stress | [AutoStressCorpus](AutoStressCorpus) |
| Artefacts du Visual Test Lab | [TestArtifacts](TestArtifacts) |
| Validation Core Image Auto | [CoreImageAutoValidation](CoreImageAutoValidation) |
| Histogramme et clipping | [HistogramValidation](HistogramValidation), [HistogramClippingOverlay](HistogramClippingOverlay) |
| Disposition paysage | [LandscapeValidation](LandscapeValidation) |
| Comparateur indépendant Lumora Bench | [LumoraBench](LumoraBench) |
| Recherche Adaptive Tone et diagnostics | [Research](Research), [DebugLab](DebugLab), [AdaptiveTone](AdaptiveTone), [AdaptiveTonePhase2](AdaptiveTonePhase2), [AdaptiveToneMetal](AdaptiveToneMetal), [AdaptiveToneIntegration](AdaptiveToneIntegration), [SpatialImportance](SpatialImportance), [ShadowBudget](ShadowBudget) |

La documentation d’utilisation et d’architecture générale reste dans [Documentation](../Documentation) et [Docs](../Docs). Les campagnes gardent leur organisation interne et leurs noms pour préserver les comparaisons historiques.

## Commandes depuis la racine du dépôt

```sh
# Cœur : comprend les tests Beauty utilisant les corpus locaux.
swift test --filter LumoraCoreTests

# Un test précis du banc, sans lancer toutes les campagnes.
swift test --filter chartCoordinatesAndMeasurementsAreIndependent

# Campagne visuelle complète, à lancer explicitement.
bash Validation/Scripts/run_visual_validation.sh

# Compilation app + tests UI (adapter la destination si nécessaire).
xcodebuild -project Lumora.xcodeproj -scheme Lumora \
  -destination 'generic/platform=iOS Simulator' build-for-testing

# Contrôle des emplacements et des entrées de build.
python3 Validation/Scripts/check_layout.py
```

Les cibles gardent leurs noms : `LumoraCoreTests`, `LumoraVisualTestLab` et `LumoraUITests`. Le manifeste SwiftPM et le projet Xcode déclarent leurs nouveaux chemins.

Par défaut, le banc écrit dans `Validation/TestArtifacts/` (ou `Quick/`). `LUMORA_VISUAL_OUTPUT` et `LUMORA_VISUAL_ASSETS` acceptent toujours un emplacement explicite. Pour une campagne isolée, choisir un sous-dossier de `Validation/` afin de ne pas recréer des artefacts à la racine.

## Corpus, archives et versionnement

Les fichiers locaux ignorés ont également été déplacés, pas supprimés. Un clone ne contient pas nécessairement tous les originaux ou résultats photographiques : voir [le corpus commun](VisualTestAssets/README.md). Les rapports et fichiers déjà versionnés restent suivis ; les règles d’exclusion ont été adaptées aux nouveaux chemins.

Les sauvegardes `Backup/`, les journaux de build, résultats Xcode et métadonnées historiques peuvent contenir les chemins de leur exécution originale. Ils sont conservés comme preuves, sans réécriture. Les liens des Markdown actifs et les chemins des scripts/tests sont mis à jour.

[Table des déplacements](relocation-map.json) · [Vérification de la réorganisation](Reports/ValidationLayoutReport.md)
