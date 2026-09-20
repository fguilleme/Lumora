# Masques intelligents Sujet, Arrière-plan, Personne, Visage, Yeux, Ciel et Peau

## Détection

Les actions **Sujet** et **Arrière-plan** utilisent `GenerateForegroundInstanceMaskRequest`, l’API Swift asynchrone de Vision disponible à partir d’iOS 18. Vision détecte les instances situées au premier plan. Lumora réunit toutes les instances pour créer Sujet et inverse le résultat pour créer Arrière-plan.

L’action **Personne** utilise `GeneratePersonInstanceMaskRequest`. Toutes les silhouettes humaines détectées sont réunies dans une seule matte, tandis que les objets de premier plan non humains restent exclus. Lorsque Vision ne trouve personne, Lumora affiche une erreur explicite et ne crée aucun calque vide.

L’action **Visage** utilise `DetectFaceRectanglesRequest`. Vision fournit des rectangles et non une segmentation sémantique : Lumora les agrandit légèrement puis construit une ellipse progressive autour de chaque visage. Les ellipses de tous les visages sont réunies. Ce masque convient aux corrections locales de portrait, mais ne prétend pas isoler précisément la peau, les cheveux ou le contour du visage. Si aucun visage n’est détecté, aucun calque vide n’est créé.

L’action **Yeux** utilise `DetectFaceLandmarksRequest`. Pour chaque visage, les points des yeux gauche et droit sont convertis dans les coordonnées de l’image, puis entourés d’ellipses douces légèrement élargies. Tous les yeux détectés sont réunis dans la même matte. Si les contours sont absents ou trop incertains, Lumora n’ajoute pas de calque vide et affiche une erreur. Les lunettes, les yeux fermés, le profil marqué ou un visage trop petit peuvent réduire la précision ; une composante Pinceau permet de corriger la matte.

L’action **Ciel** n’utilise pas de modèle appris. Une analyse locale à 1024 px mesure la dominante bleue, la luminosité, la saturation et les transitions, puis conserve uniquement les régions plausibles reliées au bord supérieur. Elle accepte aussi une partie des nuages clairs et produit une matte progressive. Cette approche reste volontairement conservatrice : un ciel de coucher de soleil, un ciel visible uniquement entre des bâtiments ou une surface bleue touchant le haut du cadre peuvent demander une correction manuelle au pinceau.

L’action **Peau** commence par détecter les visages avec Vision. Elle échantillonne ensuite leur chrominance YCbCr dans l’image courante et recherche localement les pixels compatibles à 1024 px. Le modèle chromatique est donc recalibré pour chaque photographie au lieu d’utiliser une teinte de référence unique. Un léger flou adoucit la matte finale. Au moins un visage visible est nécessaire. Des objets de couleur proche, un éclairage coloré ou des zones surexposées peuvent être inclus ou omis ; le pinceau Peindre/Effacer sert à les corriger.

`MaskGenerator` est un actor distinct de l’interface. La segmentation et l’encodage se déroulent donc hors du MainActor. La session vérifie encore l’identité du document avant d’insérer le résultat : une détection terminée après l’ouverture d’une autre photographie est ignorée.

## Stockage et rendu

La matte est convertie en PNG huit bits en niveaux de gris, bornée à 4096 × 4096 et 8 Mo, puis enregistrée directement dans le sidecar d’édition. Le moteur la redimensionne à l’étendue courante et la traite comme les formes manuelles. Elle fonctionne ainsi avec **Ajouter**, **Soustraire**, **Inverser**, Undo/Redo, les presets qui incluent les masques et l’export pleine résolution, sans relancer Vision.

La détection part de l’aperçu haute qualité déjà rendu, après géométrie. Une modification ultérieure importante du recadrage ou de la perspective étire la matte normalisée ; il vaut mieux régénérer le masque après ces changements.

## Validation et limite du simulateur

Le test du cœur encode une vraie matte PNG, la sérialise, la remet à l’échelle et vérifie numériquement que l’exposition locale ne touche que sa zone. La compilation iOS valide aussi l’intégration de Vision et Core ML.

Sur le runtime iOS Simulator 27 installé sur la machine de validation, Apple renvoie `Could not create inference context` avant la segmentation par instances, avec l’ancienne comme avec la nouvelle API Vision et même en sélectionnant le CPU. Le test UI reconnaît précisément cette erreur d’environnement et se marque ignoré. Sur un appareil, Lumora utilise les périphériques de calcul choisis par Vision. Tous les masques intelligents, dont Yeux, Ciel et Peau, restent entièrement locaux et n’envoient aucune photographie à un service distant.
