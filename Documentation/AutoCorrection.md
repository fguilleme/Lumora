# Auto — Lumière, Couleur et Courbes

Auto propose une base de développement locale, déterministe et éditable. Les trois panneaux partagent une analyse ; Auto n’est ni un Creative FX ni un mode permanent.

## Utilisation

Dans **Lumière** et **Couleur**, le bouton **Auto** remplit les curseurs existants. Dans **Courbes**, **Naturel**, **Équilibré** et **Soutenu** sont des boutons qui calculent et appliquent une courbe RVB avec au plus dix points. Équilibré représente l’intention Lumière ; Naturel la rapproche de l’identité ; Soutenu renforce modérément la séparation tonale. Les points restent manipulables avec l’éditeur habituel.

**Auto Lumière et Auto Courbes remplacent le couple de réglages Lumière + courbe RVB.** Cette indication figure sous leurs boutons. Le passage d’une représentation à l’autre ne cumule donc pas deux corrections équivalentes. Les courbes Rouge/Vert/Bleu et les autres modules sont conservés. Après Auto, on peut volontairement combiner des ajustements manuels Lumière et Courbes.

Auto Couleur ne modifie que Température, Teinte, Saturation et Vibrance. Il peut s’ajouter à l’une ou l’autre représentation tonale. Une seule opération Annuler restaure l’état précédent ; Rétablir restitue la proposition. La modification des paramètres concernés fait passer l’indication à **Personnalisé** ; leur retour exact reconnaît la proposition de la session. Les curseurs ne sont jamais verrouillés.

Le document enregistre uniquement les paramètres définitifs. Une réouverture restitue le rendu sans analyse. L’étiquette de provenance Auto n’est pas conservée après fermeture ; une nouvelle pression sur Auto recrée une proposition. Une analyse devenue obsolète après un changement de document, de calque ou de réglage ne peut pas appliquer son résultat.

## Source et statistiques

Pour Photo entière, l’analyse lit la source orientée, les corrections optiques et le cadrage actuel, **avant le développement et les Creative FX**. Les corrections déjà appliquées par Auto sont exclues. Pour un calque masqué, elle lit l’entrée de ce calque (développement global et calques précédents), dans la zone où sa matte couvre au moins 5 %. L’opacité et les réglages du calque cible n’influencent pas sa propre analyse.

La représentation réduite a un grand côté de 512 pixels, en flottant extended linear sRGB. Les valeurs HDR ne sont pas tronquées avant mesure. Les observations incluent percentiles de luminance et RVB, dynamique occupée, noirs, frontière du blanc SDR, fraction HDR, saturation, chroma et candidats neutres. Quelques pixels extrêmes ne déterminent pas les percentiles robustes.

Les décisions conservatrices préservent les scènes sombres ou claires plutôt que de fixer toute médiane au gris moyen. La balance des blancs s’appuie sur un sous-ensemble peu saturé cohérent, exclut les noirs et hautes lumières, et limite son amplitude selon la confiance. Une image sans candidats neutres fiables peut recevoir une correction nulle. Il n’y a pas de segmentation ni de modèle ML.

Pour départager une scène low-key d’un premier plan sombre devant un fond largement lumineux, Auto combine P50 et P95 avec leur séparation en stops : `log2((max(P95,0)+0,01)/(max(P50,0)+0,01))`. Trois transitions douces sur l’obscurité du premier plan, la présence de hautes valeurs étendues et cette séparation donnent un indice continu de contre-jour. P95 évite de prendre quelques lampes isolées pour un grand fond clair ; l’indice module au plus un demi-stop d’exposition et une ouverture modérée des ombres. Les statistiques globales ne révèlent toujours pas si le premier plan contient le sujet important. La [validation ciblée low-key/contre-jour](../Validation/AutoStressCorpus/Results/LowKeyBacklitFix/LowKeyBacklitClassificationFixReport.md) compare notamment un portrait sombre, une silhouette au coucher du soleil et une rue nocturne.

## Représentations tonales et limites

`AutoCorrectionIntent` définit une intention indépendante du panneau. Sa fonction tonale de référence utilise les primitives Lumière existantes sur l’axe neutre. Le fitting ajoute des points seulement quand ils réduisent une erreur significative, avec l’interpolation PCHIP existante. L’API inverse Courbe → Lumière utilise un ajustement numérique déterministe borné ; elle ne promet pas une conversion exacte et n’est pas exposée comme bouton utilisateur.

Le renderer Lumière applique une variation de luminance, tandis que la courbe RVB transforme les canaux séparément. De plus, les courbes/LUT existantes ont un domaine SDR. Une conversion peut donc diverger sur les couleurs et les hautes lumières HDR. Le rapport mesure séparément les erreurs SDR, HDR et photographiques ; Auto ne modifie aucun renderer pour dissimuler ces limites.

Le corpus de stress a révélé un écart Light→Curve HDR important sur ses images 04 et 06. Le correctif de classification low-key/contre-jour ne touche pas ce problème ; il reste documenté comme limite connue distincte.

## Cache et validation

Un seul cache d’analyse/proposition est détenu par l’acteur RenderEngine. Sa clé inclut l’identité/version de source, les réglages amont, le crop et la matte cible pertinente. Changer de panneau ne l’invalide pas ; changer de cadrage, de source ou de pixels amont l’invalide. Les buffers d’analyse ne sont pas conservés.

Le Visual Test Lab produit [AutoCorrectionValidationReport.md](../Validation/TestArtifacts/AutoCorrectionValidationReport.md), les métriques et les planches sous `TestArtifacts/Auto/`. Commencer l’inspection par [la planche des huit photos](../Validation/TestArtifacts/Auto/real_photos_contact_sheet.png), puis les planches nuit, high-key, contre-jour, WB et équivalence Lumière/Courbe. Les WARN photographiques restent soumis à validation humaine. Aucun Golden Master Auto n’est créé.

## État de validation

La première campagne comportait **669 PASS, 7 WARN, aucun FAIL technique**. Les quatre WARN de balance des blancs sur les dominantes connues ont ensuite été corrigés, sur demande explicite, par une adaptation localisée entre intention et curseurs Temperature/Tint. L’analyse, la confiance et les heuristiques photographiques sont inchangées.

Le bilan consolidé est **782 PASS, 3 WARN, 0 FAIL** ; la campagne ciblée WB compte **128 PASS**. Les WARN restants concernent une mire sous-exposée riche en patches HDR et deux conversions approximatives Courbe → Lumière. L’historique initial est conservé. Voir [la correction WB et ses mesures](../Validation/Reports/AutoWBMapping.md) et [le bilan initial versionné](../Validation/Reports/AutoCorrectionValidation.md).
