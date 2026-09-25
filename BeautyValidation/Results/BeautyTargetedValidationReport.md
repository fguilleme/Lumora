# Beauty V1 — validation ciblée des masques et du coût d’analyse

Campagne du 25 septembre 2026, sur les douze cadrages fixes de `BeautyValidation/corpus.json`. Mac mini M2 Pro, 16 Go, Swift/Swift Testing et Vision macOS. Les crops `Skin/*_100pct.png` sont des fenêtres de 320 × 320 pixels natifs, inspectées sans agrandissement. Aucun renderer, preset ni intensité Beauty n’a été modifié. Aucun Golden Master n’a été créé.

## Résultat ciblé

| Contrôle | Statut | Constat |
|---|---|---|
| 08 — couverture dentaire | PASS technique ; inspection esthétique requise | Vision encadrait les lèvres internes sur 42 % de la largeur des lèvres externes : la région dentaire était trop étroite. Une extension bornée par l’ouverture des lèvres externes couvre maintenant les incisives visibles. La condition d’ouverture et la confiance Vision restent obligatoires ; le critère de couleur clair/peu saturé est inchangé. Sur le crop 100 %, les lèvres ne sont pas sélectionnées ; fraction de pixels très saturés dans le masque dentaire : 0,0 %. Une ouverture très faible continue à produire un masque vide. |
| 12 — profil | PASS technique | Vision fournit deux landmarks d’yeux malgré un seul œil visible. À fort yaw Vision (≥ 1,05 rad) et avec nez localisé, l’œil le plus proche de la projection du nez et son sourcil sont supprimés. Le masque yeux comporte une seule composante ; le masque cernes suit cet œil. La décision dépend de la géométrie observée, pas d’une hypothèse systématique de deux yeux visibles. |
| Alignement des masques et échantillons | PASS technique après correction | Les coordonnées Vision/Core Image ont une origine inférieure, alors que les octets `MaskBitmapSource` sont rangés depuis le haut. Avant correction, les masques étaient verticalement inversés par rapport à la photo et les tests de couleur lisaient la mauvaise rangée. Les tableaux de masques et tous les échantillons Beauty utilisent maintenant la même transformation de coordonnées. Énergie du masque dans le crop source contre crop miroir : 08 dents 852 049 contre 0 ; 12 œil 2 226 944 contre 0. |
| Peau, douze cas à 100 % | WARN qualité | Des zones de front et de bas du menton sont manquées ; des cheveux, poils de barbe ou monture de lunettes entrent dans le masque dans certains cas. Détail ci-dessous. Le modèle du masque de peau n’a pas été retouché pendant cette campagne. |

Les planches avant/après sont `08_teeth_mask_before.png`, `08_teeth_mask_after.png`, `12_profile_mask_before.png`, `12_profile_mask_after.png`. Les deux overlays 100 % `08_teeth_overlay_100pct.png` et `12_profile_eye_overlay_100pct.png` sont les artefacts les plus utiles pour valider l’alignement et les exclusions. La planche `all_masks_contact_sheet.png` montre les cinq masques sur les douze visages.

## Inspection du masque de peau à 100 %

La colonne « zones manquées » décrit l’absence visible de masque sur de la peau ; la colonne « fuite » décrit une sélection visible d’une zone non cutanée. Une exclusion partielle des sourcils, lèvres et cheveux est attendue, mais leur sélection franche reste un WARN. La coupe `forehead_100pct.png` est centrée près des yeux : elle rend la frontière basse du front visible ; le haut du front est vérifié aussi sur la planche globale. Les observations restent photographiques et demandent confirmation sur appareil.

| Cas | Joues / front / menton manqués | Fuite visible ou exclusion à vérifier |
|---|---|---|
| 01 peau claire, pores | Bord externe de la joue et haut du front hors de l’ellipse ; pointe du menton atténuée. | Sourcils, yeux et lèvres majoritairement exclus ; pas de fuite forte dans les cheveux sur les crops. |
| 02 peau sombre | **Front presque entièrement omis**, malgré une joue bien couverte ; couverture du bas du visage incomplète. | Pas de fuite évidente dans les cheveux ; les zones sombres et l’orientation oblique rendent l’exclusion trop conservatrice. |
| 03 acné / rougeurs | Haut du front et bas du menton manqués. | **Cheveux latéraux sélectionnés** sur le crop joue ; lèvres principalement exclues. |
| 04 taches de rousseur | Haut du front et pointe du menton manqués ; joue centrale couverte. | Sourcils et lèvres surtout exclus ; pas de fuite forte de cheveux dans ces crops. |
| 05 rides | Partie haute du front ridé et menton inférieur manqués. | Sélection partielle dans la moustache / zone de poils fins près de la joue et du menton. |
| 06 barbe / moustache | Haut du front incomplet ; vraie peau sous la barbe impossible à isoler avec le masque actuel. | **Fuite importante dans les poils de barbe**, visible sur les crops joue et menton ; moustache à inspecter également. |
| 07 lunettes | Haut du front manqué ; joue et menton centraux couverts. | **Monture/lentille sélectionnée** avec la peau autour de l’œil ; les lunettes ne sont pas segmentées. |
| 08 sourire | Haut du front et pointe du menton manqués ; joues couvertes. | Lèvres exclues du masque peau ; le masque dents séparé reste sur les incisives visibles. |
| 09 cernes | Front latéral/supérieur largement manqué ; bord externe de joue et bas du menton partiels. | Sourcils et lèvres globalement exclus ; petites inclusions autour du contour de l’œil à confirmer. |
| 10 yeux détaillés | Haut du front, bas du menton et contour externe de joue partiels. | Quelques mèches claires au bord de la joue semblent sélectionnées. |
| 11 visage à 45° | Front du côté éloigné et menton inférieur manqués ; joue proche couverte. | Paupière/contour proche de l’œil partiellement dans la transition ; pas de fuite majeure dans les lèvres. |
| 12 profil | Front haut et bord du menton partiels ; joue visible couverte. | Bord de la paupière/cils dans la transition douce ; **plus de second œil fantôme**. |

Le manque récurrent de haut du front et de pointe du menton découle visiblement de l’ellipse faciale et de la réduction près de la ligne des cheveux. Les fuites sur 03/06/07/10 montrent la limite d’un masque fondé sur géométrie faciale et chromaticité de joue, sans segmentation dédiée des cheveux, de la barbe ou des lunettes. Ce sont des diagnostics, **pas des demandes d’augmenter l’intensité**.

## Performance : où passent les 1,9–3,3 secondes ?

Le [tableau par étape du banc](per_stage_timings.md) sépare préparation CI→CG, bitmap, requête Vision combinée, sondes isolées face/landmarks, géométrie et échantillon de joue, raster commun, imperfections et conversion des cinq masques en CGImage. Les sondes face et landmarks sont des requêtes chaudes indépendantes pour le diagnostic ; elles ne s’ajoutent pas au temps de la requête de production. Les sous-étapes peau/yeux/cernes/dents/couleur sont extrapolées sur une ligne sur 32 et incluent le coût de la sonde : ce sont des indications, **pas des durées additives**.

| Étape, 12 images | Médiane après correction | Plage après correction | Lecture |
|---|---:|---:|---|
| Préparation CI→CG + bitmap | 23,7 ms | 10,7–43,2 ms | Faible contribution. |
| Vision face + landmarks | 20,4 ms | 14,3–84,9 ms | Pas le goulot principal ; face et landmarks isolés sont détaillés dans le banc. |
| Raster commun peau/yeux/cernes/dents | **1 488,5 ms** | 1 239,1–1 930,4 ms | Goulot principal, parcours CPU de chaque pixel et évaluations géométriques répétées. |
| Imperfections | 219,9 ms | 152,7–300,6 ms | Deuxième coût ; voisinage local dans les pixels peau. |
| Conversion CGImage des masques | < 1 ms | < 1 ms | Négligeable. |
| Analyse totale | **1 728,6 ms** | 1 471,9–2 184,5 ms | Était 2 468,6 ms de médiane, 1 879,2–3 154,2 ms. |

La [comparaison avant/après par image](timing_comparison.md) conserve les deux passages et leurs limites de mesure. Le rejet par boîte englobante avant le test de point dans le polygone dentaire supprime une recherche coûteuse pour des pixels mathématiquement hors zone. C’est une correction de coût ciblée, non une optimisation générale. Le coût du masque de peau demeure élevé ; aucune réécriture ou accélération à l’aveugle n’a été entreprise.

## Appareil et vérifications

Deux iPhone apparaissent dans les destinations Xcode, mais `devicectl` échoue sur cette machine avec « Timed out waiting for CoreDeviceService to fully initialize » ; `xctrace` ne fournit pas d’appareil enregistrable. Il n’a donc pas été possible de mesurer de façon fiable l’analyse froide, l’analyse chaude/cache, l’ouverture de l’onglet ni les premier et suivants déplacements de curseur **sur un vrai iPhone**. Aucune valeur Mac n’est présentée comme mesure iPhone.

`swift test --disable-sandbox --filter beauty` : **10 tests PASS**, dont corpus des 12 photos, alignement 08/12, cache/invalidation, recadrage/miroir, rendu neutre/HDR, persistance, Undo/Redo, annulation Vision et rendu masqué. `xcodebuild` Lumora Debug pour iOS Simulator : **PASS**. Aucun échec technique restant. Les WARN qualité du masque de peau et l’absence de mesure sur appareil restent ouverts pour inspection humaine. Aucun preset, renderer ou seuil de qualité n’a été ajusté après cette inspection.
