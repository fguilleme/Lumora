# Banc de validation Creative FX

Le module SwiftPM `LumoraVisualTestLab` se trouve exclusivement dans `Tests/`. Il appelle directement `CreativeStackRenderer`, `MaskRenderer` via le compositor, et le véritable `RenderEngine` pour preview/HQ/export. Aucun renderer alternatif et aucune modification des algorithmes de production.

## Lancer une validation ciblée

Depuis la racine, sur un Mac avec Metal et prise en charge des bibliothèques dynamiques. Les tests utilisent le GPU réel et ne basculent pas silencieusement sur un substitut CPU.

```sh
# Cœur partagé : ne lance pas les campagnes photographiques
swift test --filter LumoraCoreTests

# Protocole commun, rapide par défaut
swift test --filter 'visualCreativeValidation|chartCoordinatesAndMeasurementsAreIndependent|fftAndCorrelationRecoverKnownSine'

# Une campagne dédiée, choisie explicitement
swift test --filter filmEmulationValidation
swift test --filter silverBWValidation
swift test --filter silverToningValidation

# Après silverToningValidation : tableaux descriptifs supplémentaires du rapport
swift test --filter silverToningDescriptiveTables
```

Les campagnes Silver B&W et Silver Toning lisent les **huit PNG nommés du corpus local** dans `VisualTestAssets`. Elles échouent si ce corpus est absent ou incomplet. Les noms attendus vont de `01_portrait_light_skin.png` à `08_fine_texture.png` ; voir [le contrat du corpus](../VisualTestAssets/README.md). Ces photos ne sont pas embarquées dans l’app ni livrées dans un clone Git.

`silverToningDescriptiveTables` nécessite le `checks.json` et le rapport du premier banc ; il ajoute ses tableaux à ce rapport. Pour régénérer proprement l’ensemble, exécuter d’abord le banc principal, puis une fois les tableaux. Une régénération remplace le rapport automatique ; l’inspection visuelle et les conclusions de campagne ajoutées manuellement doivent être conservées séparément et réintégrées explicitement, jamais considérées comme recalculées.

Les autres filtres dédiés sont `tonalContrastValidation`, `detailExtractorValidation`, `glamourGlowValidation`, `bleachBypassValidation`, `proContrastValidation` et `crossProcessingValidation`.

### Campagne étendue

```sh
# Tous les tests de LumoraVisualTestLab en release, FULL=1 par défaut
./Scripts/run_visual_validation.sh

# FULL=0 réduit les dimensions des bancs qui consultent cette variable
LUMORA_VISUAL_FULL=0 ./Scripts/run_visual_validation.sh
```

Le script filtre **toute la cible LumoraVisualTestLab** : il ne se limite plus au banc High/Low Key/Grain initial. De même, `swift test` sans filtre lance tous les tests, y compris les validations photographiques et leurs prérequis. FULL=0 n’est pas un mode rapide universel : les bancs Silver restent complets. Pour une vérification courte sans corpus, utiliser les filtres ciblés ci-dessus.

### Sorties et variables

- `LUMORA_VISUAL_FULL` : taille/mode pour les bancs qui le lisent, notamment le protocole commun.
- `LUMORA_VISUAL_OUTPUT` : sortie des bancs communs et des effets qui la prennent en charge, dont Silver B&W. **Silver Toning utilise actuellement `TestArtifacts` dans le dépôt**.
- `LUMORA_VISUAL_ASSETS` : dossier de photos optionnelles du banc générique ; ne remplace pas le corpus fixe des campagnes Silver.
- `LUMORA_GOLDEN_DIR` : références déjà approuvées ; séparer campagnes rapide et complète.
- `LUMORA_RECORD_GOLDENS=YES_I_REVIEWED_THE_OUTPUTS` : enregistrement explicite après revue humaine seulement. Peut remplacer des références. Ne pas définir cette variable pendant une validation initiale.

`TestArtifacts/` est ignoré par défaut. Des rapports, métriques et mires synthétiques ont néanmoins été ajoutés explicitement à Git lors des commits d’effets. Les photos sources, leurs rendus et plusieurs planches restent locaux : tous les liens de rapport ne sont donc pas disponibles dans un clone sans régénération.

### Références temporaires de non-régression

`silverToningExistingEffectsRegression` est inactif sans `LUMORA_TONING_REGRESSION`. Le mode `record` doit être exécuté dans une copie du **commit antérieur validé `8e2ad94`**, avec ce seul fichier de test ajouté ; `compare` doit ensuite être exécuté sur la nouvelle implémentation. Il compare 66 presets avec une seed fixe et écrit `existing_effects_regression.json`. Les buffers attendus sont dans `/private/tmp/lumora-toning-reference-8e2ad94` et peuvent disparaître après nettoyage système. Ne jamais enregistrer la version candidate comme sa propre référence. Ces buffers ne sont pas des Golden Masters photographiques.

## État documenté au 22 septembre 2026

| Campagne | Résultat archivé | Rapport |
|---|---|---|
| Film Emulation initial | 97 PASS / 6 WARN / 0 FAIL ; antérieur au raffinement Dense Slide | [Rapport](../TestArtifacts/FilmEmulationValidationReport.md) |
| Dense Slide | 88 PASS / 0 WARN / 0 FAIL ; raffinement visuellement approuvé | `TestArtifacts/DenseSlideRefinementReport.md` (local) |
| Silver B&W | 47 PASS / 0 WARN / 0 FAIL | [Rapport](../TestArtifacts/SilverBWValidationReport.md) |
| Silver Toning | 33 cas automatiques PASS ; 1 quality WARN visuel ; 0 FAIL | [Rapport](../TestArtifacts/SilverToningValidationReport.md) |
| Commun, lors de Silver Toning | 58 PASS / 9 WARN / 0 FAIL | [Rapport commun](../TestArtifacts/SilverToning/Common/CreativeFXValidationReport.md) |

Silver Toning : 1 201 contrôles automatiques passent, dont 1 129 hard invariants. Le WARN visuel concerne Deep Selenium mauve sur les carnations ; il n’est pas effacé par la préservation technique de luminance. Les neuf cas WARN communs portent sur High Key, Low Key et Film Grain. Le build iOS Simulator, 97 tests Core et la comparaison bit à bit des 66 presets antérieurs passent. Ce bilan décrit les campagnes déjà exécutées, pas un nouveau passage à chaque modification de documentation.

## Règle d’arrêt et interprétation

Un **hard invariant** en échec produit FAIL et interdit de déclarer la validation réussie. Une **quality heuristic** en alerte produit WARN et exige une inspection des artefacts. Après une première campagne, conserver renderer, paramètres et seuils : ne pas optimiser automatiquement les presets pour leurs distances ou résidus. Toute retouche photographique attend une validation explicite et un commit distinct. Aucun Golden Master Silver n’est approuvé à ce stade.

## Sources et références

La mire maître contient quatre rampes linéaires, 15 patches de gris, 10 couleurs à trois saturations et une scène HDR avec textures et raccords progressifs. Mire grain dédiée : sept grands patches uniformes, rampe, textures et teinte peau. Mires de transitions et textures séparées ; quatre compositions procédurales (portrait, paysage, nuit, nature morte), sans génération par IA. Les coordonnées des régions et la configuration exacte de chaque effet sont exportées en JSON.

Les valeurs représentent du **RGB sRGB linéaire étendu**, et les pourcentages de gris des luminances linéaires. `0.5` n’est donc pas un gris sRGB encodé à 50 %. Le TIFF flottant de la source préserve les valeurs HDR supérieures à 1. Les PNG sRGB 16 bits et les planches 8 bits servent à la visualisation SDR, pas au calcul des métriques.

Les références analytiques comprennent les identités à Amount=0 et, selon le moteur, Strength=0 ou Neutral. Les endpoints noirs/blancs et zones hors masque ont également des attentes analytiques. Les effets non neutres sont jugés par propriétés ; aucune « image parfaite » n’est inventée. Le test de répétabilité du grain compare deux exécutions, explicitement comme test de déterminisme, pas comme oracle de qualité.

## Mesures et seuils

Mesures RGBA Float32 en espace linéaire, par bandes de 128 lignes pour limiter la mémoire temporaire. Chaque patch possède les moments d’entrée, de sortie, du résiduel et de sa composante chromatique R−G : moyenne, variance, écart-type, minimum, maximum. Le rapport contient également MAE, RMSE, erreur max, clipping noir/blanc, hors-gamut SDR, NaN/Inf, inversions et plateaux des rampes, dérive de chromaticité RGB normalisé.

- Invariants obligatoires : aucun NaN/Inf ; identité/endpoints/hors masque à 2e-6 près ; répétabilité à 1e-6 ; changement non nul dans le masque et selon l’ordre des effets.
- Heuristiques : direction tonale, réponse Dynamic, comparaison des protections, monotonie, biais lumineux du grain, fréquence/corrélation, sélectivité tonale, cohérence d’échelle et preview/export. Les seuils sont écrits dans chaque résultat. Un échec produit WARN et reste visible ; il ne doit pas être corrigé en assouplissant arbitrairement le seuil.
- Performance : temps observé, dimensions et chemin GPU ; pas de limite de temps dépendant de la machine. Le test direct inclut allocation et transfert GPU→CPU ; le test preview/export utilise le vrai pipeline avec conversion/encodage.
- Clipping : les sources contiennent volontairement du noir, du blanc et des valeurs HDR ; interpréter les différences de comptage avec l’entrée et les comparaisons protégé/non protégé. Une égalité à zéro indique parfois un test non discriminant, pas une protection démontrée.

SSIM : moyenne de fenêtres de luminance 8×8 non chevauchantes, L=1, C1=.0001, C2=.0009. Ce n’est pas du MS-SSIM. FFT 2D Accelerate : retrait de moyenne, fenêtre de Hann, énergie totale par anneau puis normalisation. Les pics/centroïdes sont exprimés en cycles/pixel ; le spectre ignore le DC. Corrélations : (1,0), (0,1), (1,1), (2,0), (0,2), (4,0), ainsi que les couples de canaux RGB du résiduel.

La comparaison de résolution utilise le même champ photographique normalisé, redimensionné par Lanczos. Les crops natifs et les crops à champ égal sont produits séparément : des crops de même nombre de pixels dans des images de tailles différentes ne représentent pas le même champ. Le pipeline réel travaille en 960px interactif, 2048px HQ et pleine résolution pour l’export ; ses PNG de sortie restent actuellement en 8 bits, contrairement à la mesure directe du kernel.

## Golden Masters

Aucun Golden Master d’effet actuel n’est livré ou approuvé automatiquement. Après revue seulement, choisir un dossier explicite et enregistrer avec la variable ci-dessus. Une exécution d’enregistrement ne compare jamais ses propres résultats. Les TIFF Float32 sont accompagnés d’un manifeste comprenant dimensions, espace, hash du générateur source et configuration exacte. Une discordance du manifeste est une erreur, sans mise à jour silencieuse. La comparaison ultérieure calcule MAE/RMSE/max/SSIM ; seuils GPU documentés : RMSE < .0002, max < .002, SSIM > .995. Ces seuils doivent être revus selon les appareils et une évolution intentionnelle des algorithmes.

## Limites

Les photos du banc générique sont facultatives ; les huit photos des campagnes Silver sont obligatoires. Elles restent non embarquées et ignorées par Git. Un fichier générique illisible produit WARN ; une entrée requise manquante interrompt la campagne spécialisée. Une campagne sur Mac ne valide ni la mémoire d’un RAW 48 MP sur iPhone, ni les conditions thermiques de cet appareil. Les mesures de halos et de caractère photographique nécessitent une lecture des planches ; le banc ne transforme pas « agréable visuellement » en assertion artificielle.

Les courbes de continuité de réponse tonale utilisent un champ uniforme 512² et une région centrale 64² à luminance variable, afin d’isoler l’enveloppe de réponse du motif aléatoire. Les analyses de spectre et d’autocorrélation utilisent un champ uniforme à la résolution de la campagne et une région centrale 256². Les images d’edges/textures sont exportées séparément de la mire maître pour permettre leur inspection sans réduire leur finesse.
