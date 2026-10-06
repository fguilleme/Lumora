# Captures App Store

Exécuter `./AppStore/generate_screenshots.sh` pour produire les captures localisées dans `AppStore/Screenshots`.

Le script génère neuf PNG sans transparence pour chaque combinaison :

- iPhone 6,5 pouces, français et anglais : 1284 × 2778 px ;
- iPad 13 pouces, français et anglais : 2064 × 2752 px.

Ces deux formats de référence couvrent les tailles obligatoires actuelles d’App Store Connect. Les captures montrent successivement le développement, la couleur, les effets créatifs, la beauté, les métadonnées EXIF, Depth Lens, un second portrait Beauté, l’Éclairage et les Masques. La démonstration Éclairage utilise un portrait préparé à −3 EV avec une lumière latérale.

Les vues d’édition utilisent des portraits différents du corpus `Validation/BeautyValidation/Sources`. La vue EXIF utilise par défaut `/Volumes/XTRA/Pictures/IMG_9908.CR2` afin d’afficher les métadonnées réelles du boîtier et de l’objectif. Un autre RAW peut être fourni avec `LUMORA_EXIF_RAW=/chemin/photo.CR2`.
