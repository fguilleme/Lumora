# Correctif Auto low-key / contre-jour — validation ciblée

## Résultat

Les 8 photographies du stress corpus et 5 témoins de l’ancien corpus ont été rendus avec les paramètres **avant** et **après** sur le même original, dans le renderer existant. La grille synthétique comporte **47 distributions**. Contrôles automatisés : **84 PASS / 0 WARN / 0 FAIL** ; inspection diagnostique : **1 WARN qualité** pour l’ancien `04_backlight`, soit **84 PASS / 1 WARN / 0 FAIL** au total. Aucune seconde optimisation esthétique n’a été faite.

## Cause et règle

Avant, `AutoCorrectionIntent.init(analysis:)` appliquait `P50 < 0,06 && P95 > 8×P50` avant le test contre-jour (`P50 < 0,12 && P95 > 0,65`). 01 satisfaisait les deux ; le premier `if` gagnait, mettait EV à 0 et Ombres à +3. 08 satisfaisait low-key mais n’avait pas de P95 lumineux étendu. Un simple échange des branches aurait risqué de relever les silhouettes.

Le signal retenu est continu dans l’espace linéaire : `S = log2((max(P95,0)+0.01)/(max(P50,0)+0.01))` stops ; `E = [1−smoothstep(0.045,0.10,P50)] × smoothstep(0.68,0.90,P95) × smoothstep(3.0,4.5,S)`. Le plancher linéaire 0,01 stabilise les quasi-noirs. P95 représente une **fraction étendue** de l’image claire, contrairement à P99 ou à quelques pixels spéculaires ; ces derniers et l’occupation noire ont été examinés mais ne commandent pas la nouvelle règle, car ils sont sensibles aux lampes isolées et aux noirs bruités. Lorsque la distribution low-key coexiste avec `E ≥ 0,5`, la classe existante `backlit` est choisie. L’exposition reçoit jusqu’à +0,5 EV pondérée par E. Les ombres passent progressivement du comportement low-key vers le comportement contre-jour, y compris près de la frontière P50=0,06. Les hautes lumières suivent la règle existante. Aucun renderer, WB, modèle spatial ou algorithme Curves n’a changé.

Cette règle détecte un **indice tonal**, pas la présence d’un visage. Avec les seules statistiques globales, une silhouette devant un fond occupant une grande partie de l’image peut encore être ambiguë.

## Avant/après — corpus de stress

| Image | classe | EV avant→après | ombres avant→après | HL avant→après | MAE corrigé−ancien |
|---|---|---|---|---|---|
| 01 | lowKey → backlit | 0 → 0.5 | 3 → 16 | -12 → -12 | 0.02032 |
| 02 | highKey → highKey | 0 → 0 | 0 → 0 | -12 → -12 | 0 |
| 03 | lowKey → lowKey | 0 → 0 | 3 → 3 | 0 → 0 | 0 |
| 04 | normal → normal | 1.39 → 1.39 | 0 → 0 | 0 → 0 | 0 |
| 05 | lowKey → lowKey | 0 → 0 | 3 → 3 | 0 → 0 | 0 |
| 06 | normal → normal | 1.19 → 1.19 | 0 → 0 | 0 → 0 | 0 |
| 07 | normal → normal | 0 → 0 | 8 → 8 | 0 → 0 | 0 |
| 08 | lowKey → lowKey | 0 → 0 | 3 → 3 | 0 → 0 | 0 |


**01** : `lowKey → backlit`, EV `0 → 0.5`, Ombres `3 → 16`, Highlights `−12 → -12` ; différence linéaire moyenne ancien→nouveau **0.02032**. Le visage et le vêtement gagnent une séparation visible dans la planche, mais le portrait reste sombre et la fenêtre très claire : contrôle photographique humain nécessaire.

**05** : lowKey inchangé, EV 0, Ombres 3, Highlights 0; rendu bit-identique à l’ancien dans les métriques. La silhouette reste plausible.

**08** : lowKey inchangé, EV 0, Ombres 3, Highlights 0; rendu bit-identique à l’ancien. La rue reste nocturne.

Color intent/Temperature/Tint restent strictement identiques sur les 13 images. Les analyses, paramètres hors domaine, idempotence et cache passent les invariants. Les réglages des autres images du stress corpus sont inchangés.

## Ancien corpus et non-régression

| Image | classe avant→après | EV avant→après | ombres avant→après | MAE corrigé−ancien |
|---|---|---|---|---|
| 02_portrait_dark_skin | lowKey → lowKey | 0 → 0 | 3 → 3 | 3.661e-08 |
| 04_backlight | lowKey → backlit | 0 → 0.44 | 3 → 14.54 | 0.0574 |
| 05_night | lowKey → lowKey | 0 → 0 | 3 → 3 | 0 |
| 06_indoor_high_contrast | lowKey → lowKey | 0 → 0 | 3 → 3 | 0 |
| 07_white_subject | highKey → highKey | 0 → 0 | 0 → 0 | 0 |


Seul **04_backlight** change de classe dans l’ancien corpus : `lowKey → backlit`, EV 0→0.44, Ombres 3→14.54. Sa différence moyenne 0.0574 rend le sujet plus lisible mais intensifie les hautes lumières du soleil ; **WARN photographique à inspecter**, sans retouche automatique. 05_night et 07_white_subject conservent exactement leurs paramètres. 02_portrait_dark_skin garde sa classe et son EV ; l’écart d’Ombres est seulement 0.000434 unité.

## Grille synthétique et stabilité

| Distribution | P50 mesuré | P95 mesuré | P99 mesuré | noirs | classe | EV | ombres |
|---|---|---|---|---|---|---|---|
| pure low-key | 0.02005 | 0.4001 | 0.55 | 0.1011 | lowKey | 0 | 3 |
| night with small lights | 0.01603 | 0.2708 | 0.9498 | 0.04077 | lowKey | 0 | 3 |
| dark foreground + bright background | 0.005129 | 0.9599 | 0.99 | 0.188 | backlit | 0.5 | 16 |
| silhouette + sunset | 0.00906 | 0.4603 | 0.7799 | 0.1001 | lowKey | 0 | 3 |
| normal high contrast | 0.2001 | 0.96 | 0.99 | 0.01245 | normal | 0 | 0 |
| high-key | 0.6 | 0.97 | 0.99 | 0.0009766 | highKey | 0 | 0 |
| dark without highlights | 0.01501 | 0.08004 | 0.12 | 0.1082 | normal | 1.5 | 0 |
| dark with moderate highlights | 0.01008 | 0.6002 | 0.8499 | 0.09521 | lowKey | 0 | 3 |


Les 24 combinaisons P50/P95 et 15 perturbations figurent dans `synthetic_grid.json` et `synthetic_classification_grid.md`. Après la correction technique de continuité déclenchée par la première grille, la variation maximale entre deux perturbations adjacentes (pas 0,001 sur P50/P95) est :

| Centre | max ΔEV adjacent | max Δombres adjacent |
|---|---|---|
| perturb P50=0.04 P95=0.79 | 0.01 | 0.09827 |
| perturb P50=0.06 P95=0.82 | 0.01 | 0.1793 |
| perturb P50=0.045 P95=0.9 | 0.01 | 0.3029 |


La première passe avait montré une frontière abrupte près de P50=0,06 : l’exposition repassait de +0,10 EV à 0 et les ombres sautaient d’environ +5,5 à +16. La correction technique a prolongé le signal continu à travers cette frontière ; aucune cible esthétique n’a été réajustée en réponse aux photos.

## WARN, FAIL et limites

- **PASS technique** : analyses inchangées, Color inchangé, 01 sort du blocage low-key, 05/08 inchangés, high-key conservé, sorties finies, contrôles bornés, idempotence et cache valides.
- **WARN qualité** : `04_backlight` dans l’ancien corpus devient sensiblement plus lumineux autour du soleil. Le rendu de 01 mérite aussi une inspection humaine, mais sa correction n’est plus quasi nulle et ne déclenche pas de WARN selon le critère défini.
- **FAIL actuel** : 0 dans les contrôles ciblés. Le problème **déjà connu** Light→Curve HDR sur 04_blue_hour_noisy_portrait et 06_green_noisy_kitchen reste **hors périmètre et inchangé**. Leurs Light settings et classes sont identiques avant/après ; aucun résultat de ce banc ne doit être interprété comme sa correction.

Le build iOS Lumora et le build du Visual Test Lab passent ; la campagne ciblée passe après la correction technique de continuité. **111 tests du cœur passent**, y compris le nouveau test de distinction portrait/nuit/silhouette et les contrôles Auto, Curves, cache et export existants. Aucun Golden Master n’a été créé.

## Première inspection humaine

1. [contact_sheet.png](contact_sheet.png)
2. [dark_scene_comparison.png](dark_scene_comparison.png)
3. [01_fix_diagnostic.png](01_fix_diagnostic.png)
4. [old_corpus_contact_sheet.png](old_corpus_contact_sheet.png)
5. [classification_before_after.md](classification_before_after.md)
