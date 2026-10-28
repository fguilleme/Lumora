# Nettoyage lors de la suppression d’un masque

Application principale : `/Volumes/XTRA/Dev/Lumora`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`.

- La suppression retire le masque et détache ses effets Créatif dans une seule transaction. Les effets détachés sont désactivés pour ne pas devenir globaux ; leurs identités et paramètres sont conservés.
- Sélection du masque et de son composant, échantillonneur de similarité, états du pinceau, focus de réglage et sélection de point de courbe sont nettoyés. Le calque actif revient à Photo entière.
- Les résultats de détection/similarité en vol sont invalidés à la suppression, y compris si le même masque est ensuite restauré par Annuler. L’ajout d’une détection ne se reporte pas sur un autre masque après changement de cible.
- L’aperçu est recalculé à la suppression et lors d’Annuler/Rétablir modifiant les masques, même dans le panneau Masques, qui diffère habituellement le développement pendant les tracés.

Tests ciblés : 3 tests Swift réussis (nettoyage sélectif, persistance, transaction Annuler/Rétablir, absence d’application globale d’un effet détaché). Journal : `core-tests.log`.

Test UI sur simulateur : `TransientMaskGuidesUITests/testDeletingMaskClearsSelectionAndUndoRestoresLocalSettings` réussi. Vérifie retour à Photo entière, absence du masque dans le menu, disparition des poignées/résumé/indicateur Lumière, restauration des réglages locaux par une seule action Annuler puis suppression par Rétablir. Résultat : `/tmp/lumora-mask-deletion-ui.xcresult`.

Les courses de détection ont été contrôlées par lecture des gardes d’identité/version ; aucune course Vision n’a été forcée sur l’appareil physique. Aucun algorithme photographique changé. Changements locaux préexistants conservés ; aucun commit effectué.

Compilation iPhone réussie, installation sans effacement puis lancement normal sur l’iPhone connecté. Vérification du processus après 20 secondes. Validation des gestes effectuée sur simulateur ; pas de parcours tactile automatisé sur l’appareil physique.
