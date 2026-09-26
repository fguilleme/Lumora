# Presets Color Grading

Les presets remplissent les réglages du Grading existant. Ils ne changent aucun renderer, n’appliquent aucune correction Auto et ne contiennent pas de LUT supplémentaire.

## Utilisation

Dans **Colorimétrie → Grading**, sélectionner une capsule de preset. **Neutral** ouvre la même bande compacte que les autres capsules, qui défilent horizontalement par famille. Une coche et l’état sélectionné VoiceOver identifient le preset actif. La largeur des boutons dépend de leur libellé, même sur grand écran.

La sélection remplace les trois roues, Balance et Mélange en une seule opération Annuler/Rétablir. Les roues et les curseurs restent modifiables. Un changement affiche **Personnalisé** ; revenir exactement aux valeurs d’un preset le reconnaît à nouveau. Neutral rétablit tous les réglages Grading par défaut sans toucher aux autres modules.

Il n’y a pas de thumbnails dans cette interface : aucun rendu ni cache de vignettes n’est nécessaire pour afficher les capsules. La prévisualisation principale utilise le pipeline et les mécanismes de génération/annulation habituels.

Captures de validation : [iPhone](ColorGradingPresets-iPhone.png) · [iPad](ColorGradingPresets-iPad.png). Lumora impose actuellement une interface sombre ; aucun second thème de l’éditeur n’a été ajouté.

## Collection

| Famille | Presets |
|---|---|
| Référence | Neutral |
| Portrait | Soft Portrait, Warm Portrait, Cool Portrait |
| Cinematic | Cinematic, Teal & Warm, Cool Cinema, Warm Cinema, Muted Cinema |
| Atmosphere | Golden Hour, Blue Hour, Moody, Pastel, Autumn |
| Special | Bleach Grade, Split Warm/Cool |

Les intentions sont des directions artistiques fixes, pas des détecteurs de contenu. Les mêmes paramètres s’appliquent à toute photo. Les portraits utilisent une coloration modérée ; Teal & Warm et Split Warm/Cool séparent davantage les ombres et les hautes lumières.

## Contrôles réels et limites

Chaque roue Ombres / Tons moyens / Hautes lumières possède Teinte, Saturation et Luminance. Balance et Mélange règlent la répartition et le recouvrement. Aucun contrôle Global, Amount ou désaturation globale n’existe dans ce module. Aucun n’a été ajouté. Les luminances des 16 presets restent à zéro.

**Muted Cinema** ajoute une coloration discrète : il ne peut pas garantir une baisse de saturation de l’image d’entrée. **Bleach Grade** désigne uniquement une finition froide discrète ; il ne reproduit ni le contraste, ni la désaturation, ni la rétention argentique du Creative FX Bleach Bypass.

Le Grading reste dans la LUT SDR perceptuelle existante. Sa conservation de luminance pondérée sRGB n’est pas une conservation exacte de luminance linéaire. Les valeurs HDR peuvent être ramenées au domaine SDR lorsque cette LUT devient active. Ces limites sont mesurées et signalées, sans modification du renderer.

## Documents, masques et Auto

Un document sauvegarde les valeurs complètes `ColorGrading`, jamais seulement un ID de preset. Une future modification de la bibliothèque ne modifiera donc pas le rendu d’un ancien document. L’ID stable sert au choix et à la reconnaissance dans l’interface. Les copies de documents sont indépendantes.

Le preset s’applique au développement global ou au calque masqué sélectionné, par le mécanisme existant. Les réglages Light, Color, Curves et Creative FX restent intacts. Auto Light/Color peut précéder le Grading ; relancer Auto préserve les roues. Le Grading intervient avant les Creative FX selon l’ordre habituel.

## Validation photographique

Les valeurs de la première collection sont figées avant le banc. Aucun WARN, rapprochement numérique ni appréciation visuelle automatique n’autorise à retoucher les presets.

Commencer par [la planche des 16 presets sur huit photos](../Validation/TestArtifacts/ColorGradingPresets/all_presets_contact_sheet.png), puis [les portraits](../Validation/TestArtifacts/ColorGradingPresets/portrait_presets.png). Les [paramètres exacts](../Validation/TestArtifacts/ColorGradingPresets/preset_parameters.md), [distances](../Validation/TestArtifacts/ColorGradingPresets/preset_distances.md) et [rapport](../Validation/TestArtifacts/ColorGradingPresetsValidationReport.md) expliquent les mesures sans classer les looks.

```sh
swift test --filter LumoraCoreTests
swift test --filter colorGradingPresetsValidation
```

La campagne nécessite le corpus `Validation/VisualTestAssets/`, Core Image/Metal et génère les artefacts dans `Validation/TestArtifacts/`, non versionné comme pour les autres campagnes. Les résultats initiaux restent dans `ColorGradingPresets/ValidationHistory/initial_results.json`. Aucun Golden Master n’est créé avant inspection humaine.

Bilan final : **876 PASS / 29 WARN / 0 FAIL**, incluant le suivi mémoire prolongé. Voir [le résumé versionné](../Validation/Reports/ColorGradingPresetsValidation.md) et [les paramètres figés](ColorGradingPresetParameters.md).

Présentation compacte : voir [Densité des panneaux](UIDensity.md).
