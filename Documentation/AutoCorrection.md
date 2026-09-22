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

## Représentations tonales et limites

`AutoCorrectionIntent` définit une intention indépendante du panneau. Sa fonction tonale de référence utilise les primitives Lumière existantes sur l’axe neutre. Le fitting ajoute des points seulement quand ils réduisent une erreur significative, avec l’interpolation PCHIP existante. L’API inverse Courbe → Lumière utilise un ajustement numérique déterministe borné ; elle ne promet pas une conversion exacte et n’est pas exposée comme bouton utilisateur.

Le renderer Lumière applique une variation de luminance, tandis que la courbe RVB transforme les canaux séparément. De plus, les courbes/LUT existantes ont un domaine SDR. Une conversion peut donc diverger sur les couleurs et les hautes lumières HDR. Le rapport mesure séparément les erreurs SDR, HDR et photographiques ; Auto ne modifie aucun renderer pour dissimuler ces limites.

## Cache et validation

Un seul cache d’analyse/proposition est détenu par l’acteur RenderEngine. Sa clé inclut l’identité/version de source, les réglages amont, le crop et la matte cible pertinente. Changer de panneau ne l’invalide pas ; changer de cadrage, de source ou de pixels amont l’invalide. Les buffers d’analyse ne sont pas conservés.

Le Visual Test Lab produit [AutoCorrectionValidationReport.md](../TestArtifacts/AutoCorrectionValidationReport.md), les métriques et les planches sous `TestArtifacts/Auto/`. Commencer l’inspection par [la planche des huit photos](../TestArtifacts/Auto/real_photos_contact_sheet.png), puis les planches nuit, high-key, contre-jour, WB et équivalence Lumière/Courbe. Les WARN photographiques restent soumis à validation humaine. Aucun Golden Master Auto n’est créé.

## État de la première validation

**669 PASS, 7 WARN, aucun FAIL technique.** La première proposition reste à valider photographiquement. En particulier, sur les quatre mires à dominante connue, la balance des blancs automatique **accentue actuellement la dominante** au lieu de la réduire. Ce défaut reste documenté et non retouché après les mesures, conformément au gel des heuristiques. Auto Couleur ne doit donc pas être considéré comme une balance des blancs validée.

Les autres WARN concernent une mire sous-exposée riche en patches HDR et deux conversions approximatives Courbe → Lumière. Voir [le bilan versionné](AutoCorrectionValidation.md) pour les résultats et les commandes de validation.
