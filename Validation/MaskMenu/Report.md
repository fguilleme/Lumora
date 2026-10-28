# Zone tactile du sélecteur de masque — 28 octobre 2026

Application principale : `/Volumes/XTRA/Dev/Lumora`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`.

Le menu de calque actif dans la ligne d’informations avait une hauteur de seulement 24 pt. Le nom, l’icône, la flèche et leur padding forment maintenant une cible rectangulaire d’au moins 44 × 44 pt. Le fond discret identifie le bouton. Le nom du fichier cède la place au sélecteur en cas de manque de largeur. VoiceOver conserve le menu comme commande indépendante.

Aucune modification des masques, du rendu, de la persistance ou de l’historique. Changements locaux préexistants conservés ; aucun commit effectué.

Validation : compilation simulateur et iPhone réussies. Le test UI `TransientMaskGuidesUITests/testActiveLayerMenuHitArea` passe : ouverture par le padding supérieur et inférieur, sélection Photo entière / masque, portrait, paysage confirmé et inversion du côté des contrôles. Résultat : `/tmp/lumora-mask-menu-ui-confirmed.xcresult`. Capture portrait dans `Screenshots/`. La capture XCTest du paysage est tronquée par le simulateur et n’est pas retenue comme validation visuelle ; les ouvertures/sélections y ont néanmoins été testées avec succès.

Version installée et lancée normalement sur l’iPhone connecté. Processus encore présent après plus de 20 secondes. Les touches ont été automatisées sur simulateur ; pas de validation tactile automatisée sur l’appareil physique ni de session VoiceOver manuelle.
