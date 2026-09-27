# Vintage Classic one — comparaison Photoshop Camera Raw / Lumora

## Références

- XMP : `/Volumes/XTRA/Downloads/Vintage Classic one.xmp`.
- Référence Photoshop : `/Volumes/XTRA/Downloads/01_portrait_simple copy.tif`, 768 × 1152, RGB, profil sRGB incorporé.
- Source locale de comparaison : `Validation/DepthLensDA2Mobile/Payload/01_portrait_simple.png`, 768 × 1152 ; l’utilisateur confirme qu’il s’agit de la même image.
- Parcours utilisateur : photo ouverte dans Photoshop, filtre Camera Raw, Charger les paramètres, validation et copie TIFF.
- Le premier diagnostic utilisait un autre portrait du corpus ; les sorties actuelles utilisent le portrait correspondant à la référence.

## Résultat observé

Le défaut majeur apparaît avant les courbes et le virage : exposition +1,64 EV suivie du traitement tonal. La mire grise révèle un plateau dès environ 0,60215 sRGB (154/255) : les 408 derniers échantillons sur 1024 ont exactement la même sortie après le bloc tonal. L’exposition seule garde ces différences dans les valeurs flottantes. Le plateau existe déjà sans courbe verte et sans grading.

Le graphe applique l’exposition avant une LUT CIColorCubeWithColorSpace de domaine 0–1. La récupération tonale contenue dans cette LUT ne peut pas différencier les valeurs déjà hors de son domaine d’entrée. Le rendu de portrait reproduit les grandes plages claires, les transitions jaune/olive et les zones orange visibles sur la capture Lumora. Le seul réglage de teinte ne résoudrait pas cette perte d’information.

La courbe verte et le virage modifient ensuite les teintes, mais ne sont pas la cause initiale du plateau. L’écart au grain ACR reste distinct et ne doit pas servir à masquer la disparition des nuances.

## Livrables

- `comparison.jpg` : source / référence ACR / Lumora.
- `face_stages.jpg` : crops à 100 %, ACR / tonal / courbes / grading / Lumora complet.
- `ramps.csv`, `summary.csv` : diagnostic de mire.
- `00_original.png` à `07_complete.png` : étapes Lumora ; le dernier rendu ajoute le grain.

## Suite technique

Corriger en premier le domaine de calcul du bloc exposition/tons pour préserver les valeurs intermédiaires >1 jusqu’à leur récupération/compression. Une correction globale de balance des couleurs ou le déplacement arbitraire des curseurs XMP ne convient pas. Vérifier ensuite courbes, virage, mélangeur et grain séparément contre le TIFF. Ne pas annoncer une équivalence ACR sans ces comparaisons. Aucun changement au moteur de production dans cette passe de diagnostic.

## Correction du moteur — 27 septembre 2026

Après accord utilisateur, ajout de `HighlightRecoveryRenderer` au chemin partagé de développement (retouches, masques et XMP). Pour Hautes lumières < 0, une épaule rationnelle continue agit en float avant la LUT. Elle commence à 0,8 sRGB, conserve une pente unité à la jonction et applique un même gain aux trois composantes RGB linéaires. La force zéro est une identité ; à force maximale, la courbe tend progressivement vers le blanc. Alpha conservé. Pas de compensation verte/magenta et pas de modification des valeurs importées.

Les excursions HDR restantes sont normalisées par le maximum RGB avant la LUT puis rétablies après, pour conserver leurs différences plutôt que les écrêter à son entrée. Les entrées déjà dans [0,1] ne sont pas normalisées. Les états Éclairage sont exclus de la détection des réglages nécessitant une LUT, comme Depth Lens.

Cela modifie la réponse du curseur Hautes lumières négatif, y compris dans les photos et préréglages existants. C’est une correction du moteur Lumora, pas une implémentation du moteur propriétaire Adobe. Les hautes lumières positives gardent leur réponse existante.

### Mesures

- Mire : les 224 échantillons supérieurs restent distincts après tons, courbes et virage, contre une seule sortie avant correction.
- Erreur absolue moyenne RGB sRGB face au TIFF, après flou de 2 px sur les deux images pour atténuer le grain : image entière 0,06289 → 0,04347 (−30,9 %) ; crop visage x170…470 / y380…710 : 0,07658 → 0,06848 (−10,6 %).
- Il s’agit d’une mesure d’écart sur cette photo, pas d’une équivalence perceptuelle universelle. ACR reste plus granuleux et différent en contraste/couleur.
- Une première épaule à 0,7 assombrissait trop le visage (erreur visage 0,08331) ; elle a été écartée. La version retenue concentre l’action au-dessus de 0,8, avec les mêmes constantes pour toutes les images.
- 27 tests de régression ciblés réussis : récupération HDR, identité à zéro, couleur/alpha, nuances de mire, XMP, courbes, mixer, grading, rendu réel, Depth Lens et éclairage.
- Sur les échantillons flottants voisins, la conversion GPU introduit de très petites irrégularités (minimum mesuré −2,50e-5 linéaire sur la première variante). Le test tolère 5e-5 et exige que les échantillons espacés de quatre pas restent distincts et ordonnés.

Comparaison visuelle finale : `correction_comparison.jpg` (ACR / avant / corrigé).

### Vérification iPhone et livraison

- Test d’import XMP et d’export réussi sur l’iPhone 15 Pro (`iPhoneCorrectionRetry.xcresult`). Le premier test avait échoué à détecter le résultat hors écran ; son fichier exporté existait également. Le test a été corrigé pour faire défiler le formulaire.
- Une attente de fin du rendu a ensuite été ajoutée avant la capture d’aperçu dans le test ; cet ajout de synchronisation n’a pas été réexécuté. La vérification visuelle finale s’appuie sur le fichier exporté récupéré de l’appareil, pas sur la capture initiale prise pendant le calcul.
- Export appareil récupéré : `iphone_export.jpg`, 768 × 1152. Écart RGB moyen après flou de 2 px par rapport au PNG Mac corrigé : 0,001573 (valeurs normalisées 0–1). Le JPEG ne contient pas de bloc ICC selon Pillow ; cette mesure compare les valeurs décodées sous l’hypothèse sRGB.
- Planche finale : `iphone_comparison.jpg` — référence ACR / Lumora avant / export Lumora corrigé sur iPhone. Les aplats et transitions olive sont nettement réduits ; grain, contraste et luminosité restent différents d’ACR.
- Compilation Release réussie. Version Release installée sur l’iPhone 15 Pro, sans arguments de validation. Aucune modification des valeurs du XMP.
