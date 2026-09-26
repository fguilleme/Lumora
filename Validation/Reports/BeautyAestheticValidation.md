# Beauty V1 — validation esthétique initiale

Douze portraits BeautyValidation, mêmes pixels et mêmes paramètres pour les quatre colonnes **Original | Natural | Portrait | Beauty**. [Planche globale](../BeautyValidation/aesthetic_contact_sheet.png) et [dix crops à 100 %](../BeautyValidation/aesthetic_crops_100pct.png). Les appréciations ci-dessous sont visuelles et provisoires ; « good » signifie un rendu cohérent sur cette image, pas une validation définitive des presets.

| Cas | Natural | Portrait | Beauty | Observation / zone à inspecter |
|---|---|---|---|---|
| 01 Peau claire, pores | good | good | good | Pores visibles, pas d’aspect plastique ; vérifier joue et aile du nez sur appareil. |
| 02 Peau sombre, texture | good | good | good | Gamme et microtexture conservées ; vérifier front et joue dans les ombres. |
| 03 Acné, rougeurs | good | too weak | too weak | Les rougeurs et petites lésions restent proches de l’original ; inspecter la joue et le bord des lèvres. |
| 04 Taches de rousseur | good | good | good | Taches conservées, sourcil et cils nets ; inspecter le front à 100 %. |
| 05 Rides | good | good | good | Rides structurantes encore nettes, sans plage lisse évidente ; inspecter front et contour de l’œil. |
| 06 Barbe, moustache | good | good | good | Poils distincts, pas de lissage manifeste ; inspecter joue–barbe et moustache. |
| 07 Lunettes | good | good | good | Monture et reflet cyan d’origine restent nets ; pas de halo évident dans le crop, vérifier le pourtour des verres. |
| 08 Dents | good | good | good | Dents légèrement réchauffées par la source, jamais blanc pur ; lèvres et gencives paraissent naturelles. |
| 09 Cernes | too weak | too weak | too weak | Réduction peu perceptible ; l’éclairage de cette source rend le jugement incertain. Inspecter sous les deux yeux sur appareil. |
| 10 Yeux | good | good | good | Sclère naturelle, cils et coin de l’œil conservés ; pas de halo évident. |
| 11 Trois-quarts | good | good | good | Transition joue/œil régulière ; vérifier la joue éloignée et les lèvres. |
| 12 Profil | good | good | good | Œil visible et contour du nez stables ; vérifier la transition peau–fond. |

**Points transversaux :** les pores, rides, taches de rousseur, poils et détails des yeux restent visibles dans les crops. Aucun halo franc autour des lunettes, yeux ou lèvres, aucune dent blanc pur ni peau manifestement plastifiée dans ces planches. Le cas 03 et surtout le cas 09 méritent une inspection humaine avant tout jugement sur une intensité cible ; le corpus 09 est peu démonstratif pour les cernes. Les rendus Natural sont globalement très discrets, ce qui est cohérent avec leur rôle.

**Statut :** 12/12 rendus et 10/10 comparaisons natives générés ; test photographique réussi. WARN esthétiques : effet acné/rougeurs discret en 03 et cernes peu réduites en 09. Aucun preset, réglage, masque, renderer ou pipeline n’a été modifié. Aucune décision de retouche ne découle automatiquement de ce rapport ; inspection humaine requise.
