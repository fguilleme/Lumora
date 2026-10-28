# Masques et géométrie — validation du 14 octobre 2026

Projet principal : `/Volumes/XTRA/Dev/Lumora/Lumora.xcodeproj`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`.

Les composants de masque mémorisent désormais leur géométrie de création. Le rendu projette leur couverture vers le cadre courant, au lieu de les étirer sur les dimensions de sortie. Les données du masque restent intactes : aucune succession de rééchantillonnages des PNG sauvegardés. Le même repère est utilisé par les corrections locales, le grain local, les effets créatifs masqués, l'analyse Auto locale, l'overlay rouge, les poignées et les nouveaux traits du pinceau.

Les masques de fichiers anciens restent compatibles. Leur repère est fixé à la géométrie actuelle avant la prochaine interaction ou transformation. La géométrie historique de création n'existait pas dans leurs fichiers : un décalage déjà sauvegardé par une ancienne version ne peut pas être reconstruit automatiquement avec certitude. Il faut revenir à la géométrie où le masque était aligné avant une nouvelle transformation, ou recréer le masque.

## Vérifications

- `MaskGeometryTests` : cinq tests réussis. Rotation, miroirs, recadrage avec translation, redressement, perspective et transformations combinées sont comparés aux pixels obtenus en transformant le masque avec la photo, pour pinceau, radial, linéaire, masque PNG et sélection par similarité. Vérification de composants créés dans des cadres différents, soustraction, sauvegarde, Undo/Redo, compatibilité des fichiers anciens, concordance aperçu/export PNG.
- `GeometryCropUITests` : pinch, pan, formats et Undo réussis sur simulateur.
- `MaskGeometryUITests` : miroir, retour au masque, déplacement de poignée, Undo et Redo réussis sur simulateur.
- `SimilarityMaskUITests` : échantillonnage, déplacement de zone d'influence, saisie numérique, tolérance et Undo réussis sur simulateur.
- Compilation simulateur réussie. Compilation iPhone (`generic/platform=iOS`) réussie. Test tactile sur appareil et installation non effectués : l'iPhone ZAPHODICUS était verrouillé lors de la tentative avec sa destination.

Captures du même document avant/après miroir : [avant](01-before-mirror.png), [après](02-after-mirror.png). La photographie et son masque changent de côté ensemble. Le document de démonstration du simulateur contient des réglages préexistants ; il ne s'agit pas d'une reproduction de la photo jointe par l'utilisateur.

Résultats locaux : `/tmp/lumora-mask-geometry-targeted.log`, `/tmp/lumora-mask-geometry-ui.xcresult`, `/tmp/lumora-mask-mirror-ui-final.xcresult`, `/tmp/lumora-mask-color-geometry-confirmed.xcresult`.

## Limites de la suite historique

Le Package.swift principal cible macOS 14 alors que deux renderers utilisent déjà `MTLCompileOptions.mathMode` (macOS 15). Certains tests historiques d'Éclairage/Highlight Recovery utilisent également des initialiseurs supprimés. La validation Core a donc utilisé un manifeste temporaire ciblant macOS 15 et les fichiers de tests pertinents, sans modifier le manifeste principal. Sur la passe élargie de 39 tests des masques/géométrie/similarité, 38 réussissent ; l'unique échec est une assertion historique sur la liste `SmartMaskKind.allCases` qui omet le type `.magic`, déjà présent avant cette correction. Les tests ciblés de cette correction passent tous.
