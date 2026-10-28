# Poignées temporaires des masques — 28 octobre 2026

Application principale : `/Volumes/XTRA/Dev/Lumora`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`. Les modifications locales précédentes sont conservées.

Les poignées du composant radial ou linéaire sélectionné apparaissent pendant 3,5 secondes dans Lumière, Couleur, Courbes, Colorimétrie, Effets et Détail. La photo est affichée sans masque rouge ni overlay de contour. Un toucher sur la photo les réaffiche et relance ce délai, sans déplacer le masque, ouvrir le plein écran, modifier les instructions ou créer d'Undo. Une manipulation de poignée les maintient visibles ; le délai repart au relâchement. En VoiceOver, les poignées restent visibles pour laisser le temps de les atteindre.

Le réglage des poignées réutilise les transformations et les coordonnées existantes, y compris après zoom/pan ou géométrie. Seules les poignées interceptent le geste ; les traits des guides n'interceptent pas la photo. L'onglet Masques garde ses contrôles et son affichage de masque actuels. Pinceau, sélection par similarité et masques détectés ne reçoivent pas de nouvelles poignées pendant les réglages locaux. Les autres outils photographiques gardent leurs gestes. Aucun renderer, masque raster, calcul d'effet ou code d'export n'est modifié dans cette passe.

La durée de vie est locale à PhotoCanvas et annulée par SwiftUI au changement de contexte ou à la disparition de la vue. Les rendus successifs ne relancent pas le délai : aucune mise à jour d'image ne doit provoquer un clignotement ou un déplacement du guide. L'aide contextuelle française et anglaise explique le comportement.

## Validation

Deux tests `TransientMaskGuidesUITests` réussis sur simulateur iPhone 18 Pro Max / iOS 27.0 :

- Radial dans Lumière : apparition à l'entrée, absence d'overlay, disparition, toucher au centre sans déplacement et sans nouvel Undo, appui de 4,2 secondes suivi d'un déplacement, guide toujours présent après l'appui, un Undo pour le déplacement, puis zoom/pan sans modification du masque ni ajout d'Undo et réapparition au bon emplacement.
- Linéaire dans Effets : mêmes contrôles de visibilité et de toucher sans saut, poignées d'angle et de contour progressif, rotation directe, puis absence des guides avec un pinceau ou une sélection par similarité.

Résultat : `/tmp/lumora-transient-mask-guides-ui.xcresult`. Les six captures et la planche `Preview.png` montrent la photo utilisée pendant ces tests. Aucun état de masque n'est ajouté pour produire ces guides ; ils ne peuvent pas être inclus dans l'export, qui ne traverse pas PhotoCanvas.

Les gestes tactiles sont automatisés sur simulateur, pas sur l'iPhone physique. VoiceOver n'a pas été testé manuellement. La compilation iPhone et l'installation sont contrôlées séparément avant livraison.

Compilation iPhone réussie, mise à jour installée sur l’iPhone 15 Pro ZAPHODICUS et lancement normal sans argument de démonstration. Le processus Lumora est encore présent au contrôle après 20 secondes. Les documents et réglages existants sont conservés.
