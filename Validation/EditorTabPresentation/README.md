# Onglets et panneau repliable — 13 octobre 2026

Application principale : `/Volumes/XTRA/Dev/Lumora`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`.

Une seule rangée défilante : icône au-dessus du texte, libellés caption2 adaptés à la taille de texte système, cibles tactiles de 52 pt minimum. Le panneau est fermé au démarrage, un appui sur un onglet l’ouvre ; un nouvel appui sur l’onglet actif le replie. La photo récupère la surface du panneau et les gestes des outils sont désactivés pendant son repli.

Validation : compilation et `EditorTabPresentationUITests/testTabsToggleControlsAndExpandPhoto` réussis sur le simulateur iPhone « Lumora App Store iPhone ». Vérification du panneau fermé au démarrage, ouverture/repli/réouverture, conservation de la valeur Exposition et de la génération du rendu, fermeture de Courbes, expansion en paysage, inversion du côté des contrôles, navigation vers Réglages puis fermeture sans perte de position des onglets.

Captures : même document restauré, mêmes réglages photographiques, interface française. Pas de validation sur iPhone physique dans cette passe ; zoom/pan et VoiceOver non testés manuellement.

Résultat XCTest : `/tmp/lumora-tab-presentation-verified.xcresult` (1 test réussi, 0 échec).
