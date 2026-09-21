# Banc de validation Creative FX

Le module SwiftPM `LumoraVisualTestLab` se trouve exclusivement dans `Tests/`. Il appelle directement `CreativeStackRenderer`, `MaskRenderer` via le compositor, et le véritable `RenderEngine` pour preview/HQ/export. Aucun renderer alternatif et aucune modification des algorithmes de production.

## Lancer

Depuis la racine du projet, sur un Mac avec Metal et prise en charge des bibliothèques dynamiques :

```sh
./Scripts/run_visual_validation.sh
```

La commande compile les tests en mode optimisé, génère les mires 4096² et exécute les scénarios 1024²/2048²/4096². Le mode optimisé des tests ne les inclut pas dans l’app Release. Sortie principale : `TestArtifacts/CreativeFXValidationReport.md`, avec données JSON dans `TestArtifacts/Reports/` et PNG dans les dossiers thématiques. Le dossier entier est ignoré par Git.

```sh
# Campagne rapide : master 512², résolutions 256²/512²/1024²
LUMORA_VISUAL_FULL=0 ./Scripts/run_visual_validation.sh

# Tous les tests du projet, avec la campagne complète
LUMORA_VISUAL_FULL=1 swift test -c release
```

Sans variable, `swift test` lance le banc rapide. Les autotests du banc contrôlent les coordonnées des patches, une différence analytique constante, une fréquence sinusoïdale connue, ainsi que les règles d’enregistrement/comparaison des Golden Masters.

Variables facultatives :

- `LUMORA_VISUAL_OUTPUT` : dossier de résultats absolu ; par défaut `TestArtifacts` en complet et `TestArtifacts/Quick` en rapide.
- `LUMORA_VISUAL_ASSETS` : dossier de photos facultatives, sinon `VisualTestAssets` à la racine du projet.
- `LUMORA_GOLDEN_DIR` : dossier de références déjà approuvées. Ne pas utiliser le même dossier pour les campagnes rapide et complète.
- `LUMORA_RECORD_GOLDENS=YES_I_REVIEWED_THE_OUTPUTS` : enregistrement explicite, seulement après inspection humaine. Désactivé par défaut. Cette commande peut remplacer des références existantes dans le dossier choisi.

## Sources et références

La mire maître contient quatre rampes linéaires, 15 patches de gris, 10 couleurs à trois saturations et une scène HDR avec textures et raccords progressifs. Mire grain dédiée : sept grands patches uniformes, rampe, textures et teinte peau. Mires de transitions et textures séparées ; quatre compositions procédurales (portrait, paysage, nuit, nature morte), sans génération par IA. Les coordonnées des régions et la configuration exacte de chaque effet sont exportées en JSON.

Les valeurs représentent du **RGB sRGB linéaire étendu**, et les pourcentages de gris des luminances linéaires. `0.5` n’est donc pas un gris sRGB encodé à 50 %. Le TIFF flottant de la source préserve les valeurs HDR supérieures à 1. Les PNG sRGB 16 bits et les planches 8 bits servent à la visualisation SDR, pas au calcul des métriques.

Les seules images attendues mathématiquement sont ici les transformations identité à Amount=0. Les endpoints noirs/blancs et zones hors masque ont également des attentes analytiques. Les effets non neutres sont jugés par propriétés ; aucune « image parfaite » n’est inventée. Le test de répétabilité du grain compare deux exécutions, explicitement comme test de déterminisme, pas comme oracle de qualité.

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

Les photos utilisateur sont facultatives, non embarquées et ignorées par Git ; les planches sont des fichiers locaux contenant ces photos. Les fichiers illisibles produisent WARN. Une campagne sur Mac ne valide ni la mémoire d’un RAW 48 MP sur iPhone, ni les conditions thermiques de cet appareil. Les mesures de halos et de caractère photographique nécessitent une lecture des planches ; le banc ne transforme pas « agréable visuellement » en assertion artificielle.

Les courbes de continuité de réponse tonale utilisent un champ uniforme 512² et une région centrale 64² à luminance variable, afin d’isoler l’enveloppe de réponse du motif aléatoire. Les analyses de spectre et d’autocorrélation utilisent un champ uniforme à la résolution de la campagne et une région centrale 256². Les images d’edges/textures sont exportées séparément de la mire maître pour permettre leur inspection sans réduire leur finesse.
