# Diagnostic Creative FX — 21 septembre 2026

Campagne synthétique 4096², Mac Apple M2 Pro, mesures en RGB linéaire avant conversion d’affichage. Les références actuelles n’ont **pas** été approuvées comme Golden Masters. Les algorithmes High Key, Low Key et Grain sont restés inchangés pendant la construction et l’analyse du banc.

Validation finale : **95 tests réussis** (91 tests du cœur et 4 tests du banc), compilation iOS Simulator Release réussie. **55 scénarios : 48 PASS, 7 WARN, aucun FAIL**. Les WARN sont des alertes de qualité ; ils ne sont pas masqués par les tests des invariants.

Le rapport généré se trouve dans [TestArtifacts/CreativeFXValidationReport.md](../TestArtifacts/CreativeFXValidationReport.md). Les valeurs ci-dessous décrivent les scènes et paramètres documentés par le banc ; elles ne constituent pas des garanties sur toutes les photos.

## 1. High Key : pression sur le gamut SDR

Les configurations testées ajoutent environ **5,00 à 8,76 points de pourcentage** de pixels dont au moins un canal atteint ou dépasse 1, par rapport à la mire d’entrée. La configuration Strong Dynamic est la plus exposée. Le phénomène se concentre sur des patches très saturés ; les gris proches du blanc restent protégés.

Ce n’est pas principalement une dérive de teinte dans le calcul linéaire : les chromaticités RGB normalisées des patches sans glow restent presque identiques. Le renderer multiplie RGB pour relever la luminance tout en préservant leurs proportions ; un canal déjà fort peut donc dépasser le gamut SDR. L’encodage final perd alors de l’information dans ce canal. Une protection basée sur la luminance ne suffit pas à borner chaque canal.

À examiner : [planche High Key](../TestArtifacts/HighKey/contact_sheet.png), [Strong Dynamic](../TestArtifacts/HighKey/03_strong_dynamic.png), [carte de différence](../TestArtifacts/HighKey/03_strong_dynamic_difference_x4.png). Une éventuelle solution devra arbitrer entre protection de gamut, saturation et remontée lumineuse ; aucune n’a été appliquée.

## 2. Low Key Dynamic : réponse relative contraire au critère demandé

Sur les plages linéaires 0–10 % et 90–100 % :

| Configuration | Assombrissement relatif des ombres | Assombrissement relatif des hautes lumières |
| --- | ---: | ---: |
| Dynamic modéré | 16,29 % | 2,00 % |
| Strong Dynamic | 9,13 % | 5,30 % |

Le critère « assombrissement relatif des hautes lumières supérieur à celui des ombres » n’est donc pas respecté pour ces configurations. La protection des hautes lumières et le mélange avec la composante standard contribuent vraisemblablement à ce résultat. Cela mérite une décision de conception : distinguer les hautes lumières utiles des quasi-blancs volontairement préservés, et préciser l’effet attendu de Dynamic.

Les courbes restent monotones dans les scénarios mesurés. La protection réduit bien le déplacement du gris 2 % : environ −0,000600 avec protection contre −0,008098 sans protection ; le comptage des noirs seuls aurait été moins discriminant. La courbe forte possède une inflexion marquée, sans inversion détectée. [Courbe Low Key forte](../TestArtifacts/LowKey/03_strong_dynamic_transfer_curve.png).

## 3. Grain : bonne cohérence spatiale, intensité variable selon la résolution

À champ photographique égal après normalisation vers 1024², les rendus 2048² et 4096² sont fortement corrélés au rendu 1024² : environ **0,982 et 0,980**. La taille du motif ne devient donc pas quatre fois plus petite.

En revanche, l’écart-type du grain normalisé augmente d’environ **17 % et 24 %**. L’aperçu de plus faible résolution atténue davantage la texture. Cela reste sous le seuil d’alerte large du banc, mais constitue un écart perceptuel réel à considérer.

Dans le pipeline complet, l’aperçu interactif et l’export restent corrélés à environ **0,957** (SSIM **0,983**), contre **0,999** pour HQ/export (SSIM **0,999**). La planche montre un grain plus discret côté preview. La normalisation de coordonnées fonctionne ; l’approximation de filtrage et l’intensité méritent une calibration ultérieure.

À examiner : [résolutions comparées](../TestArtifacts/Grain/resolution_comparison.png), [preview/HQ/export à champ égal](../TestArtifacts/Pipeline/comparison.png), [crops natifs](../TestArtifacts/Pipeline/native_crops.png).

## 4. Grain : structure et biais

La fréquence moyenne pondérée passe approximativement de **0,183** à **0,089**, puis **0,048 cycle/pixel** entre Fine, Medium et Large. L’autocorrélation horizontale à un pixel vaut environ **0,90** en Medium : ce n’est pas du bruit blanc indépendant. Clumping déplace aussi clairement l’énergie vers les basses fréquences.

Softness agit plus modestement sur le spectre : centroïde d’environ **0,0986 à 0,0951**, avec une baisse d’écart-type d’environ **17 %** sur le patch linéaire 0,3. Son effet semble donc surtout atténuer le grain dans cet essai ; la distinction perceptuelle avec Amount est un point à revoir.

Le plus grand biais moyen absolu relevé parmi les patches/configurations est de l’ordre de **0,00030 en luminance linéaire**. Pas de forte dérive d’exposition dans ces essais. La répétabilité à seed identique, la variation spatiale avec un autre seed et les réponses tonales continues passent les vérifications.

La planche native révèle une texture très grossière, presque nuageuse, à fort Clumping. C’est un constat visuel sur un réglage extrême, pas un échec numérique ni une preuve d’émulation photographique. [Grain à 100 %](../TestArtifacts/ContactSheets/Grain_100percent.png), [spectre](../TestArtifacts/Grain/spectrum.png), [autocorrélation](../TestArtifacts/Grain/autocorrelation.png).

## 5. Halos, masques et ordre des effets

L’inspection des transitions montre une diffusion lumineuse autour de l’arête blanc/noir lorsque Glow est actif. Elle est attendue par le modèle. Aucune oscillation de type ringing ni dépassement neutre hors [0,1] n’a été détecté dans les profils testés. La conclusion ne couvre pas tous les rayons, seuils et contenus photographiques. [Planche des arêtes](../TestArtifacts/ContactSheets/Edges.png).

Les zones hors masque restent inchangées, avec une erreur maximale mesurée nulle pour High Key et Grain. Les zones intérieures changent. Inverser High Key → Grain en Grain → High Key donne une RMSE d’environ **0,00249**, ce qui confirme l’ordre réel de la pile. [Masque High Key](../TestArtifacts/Masks/highKey.png), [masque Grain](../TestArtifacts/Masks/grain.png), [ordre de la pile](../TestArtifacts/EffectStack/comparison.png).

## Limites et décision

Aucune photo réelle n’était fournie dans `VisualTestAssets`. Les compositions procédurales restent des instruments reproductibles, pas une validation sur une collection de portraits/RAW réels. La campagne Mac n’évalue pas la mémoire et la chauffe d’un iPhone avec RAW 48 MP.

Priorités proposées pour une prochaine décision : gamut High Key ; définition/calibration de Low Key Dynamic ; intensité du grain entre aperçu et export ; distinction de Softness avec Amount. **Arrêt après analyse : aucune correction du renderer et aucun Golden Master approuvé.**
