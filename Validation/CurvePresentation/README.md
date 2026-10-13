# Courbes — présentation et déplacement

Cible principale : `/Volumes/XTRA/Dev/Lumora/Lumora.xcodeproj`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`.

- Fond du panneau : noir à 16 %, sans transparence globale sur son contenu.
- Histogramme : tracé à 55 % au repos et 100 % pendant le déplacement d’un point ; aucun remplissage sous son profil.
- Courbe et points : couleurs et opacité conservées.
- Canaux RVB/Rouge/Vert/Bleu dans les contrôles : tap sur le canal actif replie/rouvre le graphe ; changer de canal l’ouvre.
- Histogramme général masqué dans Courbes.
- Déplacement du bandeau calculé dans les coordonnées fixes de la zone photo.

## Validation

Test `CurvePresentationUITests` réussi sur le simulateur iPhone principal, avec captures de la même photo : position des canaux, zones tactiles de 44 pt, repli sans changement de géométrie du canvas ni rendu, changement de canal sans modification photographique, déplacement aller/retour de 70 pt du panneau, déplacement d’un point et Undo, paysage et inversion des contrôles.

Résultat : `/tmp/lumora-crop-sync-and-histogram.xcresult`.

Pas de test sur appareil physique. Le test mesure la position finale du panneau, pas la fréquence d’affichage ni la fluidité image par image. L’opacité pendant le geste est contrôlée par l’état de drag ; les captures sont prises après relâchement. Aucun renderer ni calcul des courbes modifié.
