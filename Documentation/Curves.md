# Courbes — deuxième étape

## Utilisation

Le nouvel outil **Courbes** propose RVB, Rouge, Vert et Bleu. L’histogramme du canal sélectionné apparaît derrière la courbe.

- Le graphique démarre en **consultation** : un défilement commencé sur la courbe ne change aucun point. **Modifier** active le mode édition ; **Terminé** revient à la consultation et désactive la pipette.
- En édition, un vrai toucher sur le graphique ajoute un point. Glisser depuis une zone vide fait défiler le panneau ; glisser un point existant le déplace. Les points visibles gardent une cible tactile de 44 pt.
- Les points restent ordonnés horizontalement. Les deux extrémités gardent leur abscisse 0 et 1, mais leur valeur de sortie est modifiable.
- Le bouton **+** ajoute un point au milieu du plus grand intervalle, sur la courbe existante.
- Les flèches sélectionnent le point précédent/suivant. **Entrée / Sortie** permettent aussi un réglage précis et accessible sans manipulation du graphique.
- La corbeille supprime le point sélectionné, sauf les extrémités.
- La flèche de réinitialisation remet uniquement le canal actif à l’identité.
- La **pipette** échantillonne la photo par zone de 3 × 3 pixels dans une preview de 512 px au maximum. Elle affiche une position et une valeur temporaires sur la courbe sans créer de point ni d’entrée Undo. **+** crée volontairement un point à cette tonalité. Le canal RVB utilise la tonalité pondérée du moteur ; Rouge, Vert et Bleu lisent chacun leur canal. La pipette est indisponible sur un calque masqué pour éviter une mesure incohérente avec l’entrée locale de la courbe.
- Chaque geste constitue une commande Undo/Redo. Les courbes sont sauvegardées avec le développement et restaurées au lancement.

La consultation, l’édition et la pipette sont des états d’interface temporaires ; les courbes restent les seules données persistées. Voir le [rapport de validation des interactions](../Validation/Reports/CurvesInteractionValidationReport.md) et les captures dans `Validation/TestArtifacts/CurvesInteraction/`.

## Modèle et interpolation

`ToneCurve` conserve de 2 à 16 points normalisés, espacés d’au moins 0,02 sur l’axe d’entrée. Le décodage normalise les bornes, ordonne les points et écarte les doublons trop proches. Les valeurs non finies sont rejetées.

L’interpolation cubique Hermite utilise des tangentes PCHIP : moyenne harmonique pondérée lorsque les pentes voisines ont le même signe, tangente nulle aux extrema, limitation des tangentes aux extrémités. Elle conserve la monotonie des segments et n’introduit pas de dépassement entre les points. Les courbes non monotones restent autorisées pour les usages créatifs.

La courbe maîtresse RVB s’applique d’abord à chaque canal, suivie de sa courbe Rouge/Vert/Bleu respective. Les opérations ont lieu après les réglages tonals et avant saturation/vibrance. La luminance utilisée pour ces derniers est recalculée après les courbes.

## Rendu

Chaque canal est précalculé dans une table de 1024 valeurs ; ces tables sont utilisées pour générer la LUT 3D commune de 32³ échantillons. L’interpolation des tables est linéaire, puis Core Image interpole la LUT sur GPU. Le moteur ne recalcule pas les splines par pixel. Il conserve les niveaux d’aperçu interactif 960 px et HQ 2048 px, l’annulation coopérative et le contrôle des générations.

La LUT 3D 32³ reste une approximation : les variations très étroites ne sont pas reproduites avec la même précision que l’interpolation mathématique. Les limites SDR/gamut de la première étape restent applicables. L’[export pleine résolution](Export.md) utilise désormais ces mêmes réglages.

## Compatibilité et fichiers

La lecture d’`EditState` accepte l’absence de `curves` dans les anciens JSON et restaure alors quatre courbes identité. Les anciens réglages sont conservés. Le schéma documentaire reste à 1 car cette évolution est additive à la lecture ; une ancienne version de l’app ne sait évidemment pas appliquer les nouvelles courbes.

Créés :

- `Lumora/Adjustments/ToneCurve.swift`
- `Lumora/UI/ToneCurveEditor.swift`
- `Validation/Tests/LumoraCoreTests/ToneCurveTests.swift`
- `Documentation/Curves.md`

Modifiés : `EditState`, `EditorSession`, `TonalResponse`, `RenderEngine`, `EditorView`, les tests du moteur et le parcours UI, ainsi que la documentation.

## Vérifications

18 tests Swift Testing du cœur : régressions de l’étape 1, identité et passage par les points, monotonie, continuité des tangentes, absence de dépassement, bornes et édition des points, migration/sérialisation, précision des tables, ordre maître/canaux, historique groupé et rendu Core Image sur mire. Le test du renderer vérifie qu’une courbe rouge modifie bien le rouge tout en conservant les canaux vert et bleu à la tolérance d’arrondi près.

Validation finale : build iOS réussi ; **18 tests du cœur et 1 parcours UI étendu réussis**. Le parcours UI vérifie le déplacement tactile d’un point, Undo/Redo, sa suppression, l’indépendance des canaux, leur persistance au redémarrage et la réinitialisation d’un seul canal. Aucun warning Swift ; avertissement Xcode App Intents non bloquant inchangé.

Résultats de cette session : `/tmp/lumora-curves-tests.log`, `/tmp/lumora-curves-build.log`, `/tmp/lumora-curves-ui.log` et `/tmp/LumoraCurvesUITests.xcresult`.

## Auto

Le panneau propose Auto et les variantes Naturel / Équilibré / Soutenu. Elles partagent l’analyse de Lumière et Couleur et génèrent des points éditables. Auto Courbes remplace explicitement les réglages Lumière et la courbe RVB ; les courbes de canaux restent indépendantes. La conversion est mesurée comme une approximation, notamment en HDR. Voir [Auto — architecture et limites](AutoCorrection.md).
