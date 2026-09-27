# Éclairage expérimental — intégration Lumora

Date : 2026-09-27.

## Fonctionnalité

Onglet Éclairage, configurable dans Réglages comme les autres onglets. Activation explicite, désactivée par défaut sur les nouveaux documents et les anciens documents sans clé `depthLighting`. Réinitialiser désactive aussi l’effet. Masquer l’onglet ne modifie pas un réglage déjà actif.

Contrôles du prototype conservés : intensité, distance relative, douceur, chaleur, relief, cible de profondeur et position indépendante de la lampe. Tap avec choix du repère, déplacement direct des repères, annuler/rétablir et sauvegarde avec la photo. Effet global, avant Depth Lens et Cinematic Glow. Aucun modèle Google, DPR ou LBM.

Aide française et anglaise : caractère expérimental, désactivation par défaut, portée de chaque réglage, distance non métrique, erreurs de profondeur/ciel/cheveux, conservation des ombres existantes, absence de régénération des visages, comparaison et export.

## Rendu

Même formule que `Validation/DepthLighting/Sources/Lighting.metal`, exécutée comme noyau Core Image pour conserver l’évaluation à la demande à l’export, sans trois textures float pleine résolution supplémentaires. Carte DA2 partagée avec Depth Lens, lissée à deux pixels du modèle. Dérivées exprimées dans le repère 960 px du prototype pour éviter de changer le relief selon preview/HQ/export.

Valeurs HDR originales >1 conservées, compression douce de la seule contribution ajoutée, aucune inférence de profondeur quand les deux effets sont désactivés. La profondeur est réutilisée pendant les ajustements.

## Vérifications automatisées Mac

Quatre tests ciblés réussis :
- migration, activation par défaut, bornes, sauvegarde et historique ;
- bypass exact désactivé/zéro, éclairage effectif du sujet, fond distant synthétique inchangé, alpha et HDR ;
- cohérence de résolution et d’origine du rectangle ;
- comparaison GPU avec le shader Metal du prototype à 640 × 960 : écart RGB linéaire moyen 3,41e-8, maximum 4,92e-7 sur une profondeur synthétique variable.

Compilation Release iOS réussie. Fichiers de localisation vérifiés par `plutil`.

Ces contrôles ne constituent pas une garantie de segmentation du ciel ni une validation esthétique universelle. Les erreurs du modèle de profondeur restent visibles sur certaines scènes.

## iPhone 15 Pro

Test UI sur appareil réel réussi (`iPhoneUIFinal.xcresult`) : état initial désactivé, avertissement expérimental en français, activation, placement de la cible, changements d’intensité, historique disponible, désactivation et consultation de l’aide française. Aucune alerte applicative observée. La première tentative a expiré lors de l’activation de l’automatisation Xcode ; la suivante a révélé un identifiant de défilement périmé dans le test, corrigé sans changement fonctionnel.

Cette passe vérifie l’intégration et l’interaction. Elle ne mesure pas un export natif sur iPhone, la pression mémoire maximale ou la stabilité thermique prolongée. Le jugement esthétique reste humain.

Version Release finale compilée puis installée sur l’iPhone 15 Pro. Une répétition de texte français relevée à la lecture de la capture a été corrigée avant cette installation ; aucune modification du moteur après les tests.

## Correction du déplacement des repères

Le geste utilisait le repère local de l’icône mobile, ce qui réinjectait son déplacement dans les événements suivants. Les deux repères utilisent maintenant les coordonnées fixes du canevas photo ; la dernière position du geste est aussi appliquée avant de terminer l’interaction. Aucun changement au moteur de rendu.

Test iPhone `iPhoneDrag.xcresult` réussi : déplacements du soleil et de la cible dans les deux sens, positions finales à moins de 6 points de la position du doigt, contrôles et aide toujours fonctionnels. Ce test vérifie la trajectoire finale, pas une mesure de cadence des animations.
