# Contours de Sélection magique — 9 octobre 2026

Le masque était seuillé à 256 pixels puis agrandi. Le rasteriseur interpole
maintenant les scores signés de MobileSAM avant le seuil, à la résolution de
l'image de travail. Le passage entre noir et blanc couvre environ un pixel
de sortie. L'aperçu rouge utilise les mêmes valeurs que le masque enregistré.

Les prompts inutilisés et le masque antérieur sont initialisés explicitement
à zéro. Une sonde a reproduit des sorties non finies sans cette initialisation.

## Validation

- Trois tests ciblés passent : frontière oblique avec position fractionnaire,
  indépendance vis-à-vis de l'amplitude des scores, orientation/crop du padding,
  conservation des zones uniformes et rejet des scores invalides.
- La suite Swift globale est bloquée par une erreur de disponibilité macOS
  préexistante (`MTLCompileOptions.mathMode`, dans Depth Lens). Les trois tests
  ont été exécutés dans un package isolé lié aux fichiers réels du projet.
- Comparaison de l'ancien et du nouveau code avec les modèles MobileSAM de
  production compilés sur Mac, sur `02_hair_bright.png`, point positif
  `(0.7, 0.4)`, proposition 1. Les deux chemins reçoivent des entrées initialisées
  de façon identique. `before.png` et `after.png` ont les mêmes dimensions.
- La silhouette interpolée est visuellement plus régulière. La segmentation
  sémantique et les détails absents de la sortie du modèle restent une limite.
- Les masques déjà enregistrés ne sont pas recalculés. Créer une nouvelle
  Sélection magique pour bénéficier de l'interpolation des scores.

Les gestes et le résultat visuel sur appareil nécessitent un essai manuel ;
la comparaison de masques a été réalisée sur Mac.

La build Debug de la cible principale `Lumora` (`com.guilleme.Lumora`) compile
et a été installée sur l'iPhone 15 Pro connecté. Le lancement final a été
refusé par iOS parce que l'appareil était verrouillé.
