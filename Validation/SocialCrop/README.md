# Formats sociaux et cadrage tactile — 13 octobre 2026

Cible principale : `/Volumes/XTRA/Dev/Lumora`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`.

Formats : Original ; Instagram carré (1:1) ; Instagram portrait (4:5) ; TikTok (9:16) ; Classique (4:3) ; Photo (3:2) ; Paysage large (16:9). Les identifiants enregistrés des formats préexistants sont conservés. Référence du format vertical TikTok : https://ads.tiktok.com/resources/help/article/tiktok-reservation-in-feed-ads-reach-frequency?lang=en-0

En Cadrage, le cadre et la grille restent fixes. Pincement et glissement pilotent les paramètres cropZoom/cropX/cropY existants, avec les mêmes bornes. L’extérieur est révélé par une image de contexte temporaire et un voile noir à 55 %. Au repos, l’intérieur du cadre utilise l’aperçu photographique de production. Le contexte est calculé avec une copie des réglages sans cadrage, jamais enregistrée ni exportée. Aucun changement du renderer photographique ou de l’export.

Ajustements conserve ses contrôles, dont la perspective directe. Aide française/anglaise mise à jour.

Validation : compilation de la cible principale réussie ; 3 tests ciblés des gestes, limites, dimensions du renderer et compatibilité des données réussis ; 1 test d’interface iPhone réussi (sélection des formats, pinch, pan, une étape Undo par geste, restauration des valeurs, retour en Ajustements, paysage et inversion du côté des contrôles). Résultat : `/tmp/lumora-crop-sync-and-histogram.xcresult`.

Captures sur le simulateur « Lumora App Store iPhone », même document restauré. Pas de validation sur appareil physique ; pas de test manuel VoiceOver, ni de test du pinch et du pan simultanés. Les tests de coordonnées comparent les dimensions produites au renderer existant ; aucune comparaison de fichier exporté n’a été effectuée dans cette passe.

## Synchronisation de l’aperçu pendant le cadrage

Pendant le pinch/pan et tant que le rendu final est en cours, toute la photo utilise le même contexte non recadré transformé : intérieur et extérieur suivent donc le même geste. Dès que le dernier rendu est prêt et le geste terminé, l’intérieur reprend l’aperçu photographique exact. Cela corrige le retard visuel de l’ancienne image recadrée sans modifier le renderer, les réglages enregistrés, les gestes ou Undo.
