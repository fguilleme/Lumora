# Sélection par couleur — première version

Intégrée au checkout principal `/Volumes/XTRA/Dev/Lumora`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`.

Dans **Masques → Nouveau → Sélection par couleur**, toucher la photo prélève une couleur et place une ellipse d’influence. Les poignées règlent la position, la largeur, la hauteur et le contour progressif. La molette règle notamment la tolérance. L’outil est également disponible dans Ajouter et Soustraire.

- **Région reliée**, par défaut : propagation depuis le point prélevé, sans traverser une couleur exclue ni sortir de l’ellipse.
- **Tous les pixels similaires** : inclut aussi les zones séparées de couleur proche à l’intérieur de l’ellipse.
- Déplacer l’ellipse conserve la couleur et le point de référence. Si l’ellipse ne contient plus ce point, le mode Région reliée donne une sélection vide ; la pipette permet de choisir un nouveau point.
- Le champ de différence de couleur est figé au prélèvement : les corrections locales ne modifient pas leur propre sélection. Il est sauvegardé avec le masque et utilisé par l’aperçu comme par l’export.

## Validation

Compilation iPhone et simulateur réussie, sans nouvel avertissement Swift. 26 tests ciblés passent, dont 7 nouveaux : propagation, confinement dans l’ellipse, tolérance, contour progressif, orientation, relecture PNG, sérialisation, soustraction et Undo.

Le test UI français passe sur le simulateur « Lumora App Store iPhone » : création, accès direct à Tolérance, prélèvement, déplacement de l’ellipse et Undo, saisie numérique, changement de propagation, reset, molette continue et Undo.

Un ancien test non modifié, `generatedMaskSerializesScalesAndAppliesLocally`, attend une liste `SmartMaskKind.allCases` qui omet déjà `.magic`. Il échoue indépendamment de ce nouvel outil. Les anciens tests de relighting comportent aussi des appels devenus incompatibles ; le harness temporaire ne compile que les tests de masques concernés.

Limites : pas encore de test sur iPhone physique ni de validation dédiée paysage/zoom/pan pour ce nouvel outil. Le champ est calculé sur la photo affichée, plafonnée à 1 536 pixels sur le grand côté, puis interpolé à la résolution de rendu ; ce n’est pas un détourage sémantique des cheveux. Aucun changement du moteur de sélection magique.

## Captures du même état photographique

Région reliée :

![Région reliée](/Volumes/XTRA/Dev/Lumora/Validation/SimilarityMask/01-region-reliee.png)

Tous les pixels similaires :

![Tous les pixels similaires](/Volumes/XTRA/Dev/Lumora/Validation/SimilarityMask/02-tous-les-pixels.png)
