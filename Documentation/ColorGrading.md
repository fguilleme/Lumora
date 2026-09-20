# Color grading — quatrième étape

## Utilisation

Faire défiler la barre inférieure jusqu’à **Grading**. Les trois roues correspondent aux **Ombres**, **Tons moyens** et **Hautes lumières**. Glisser dans une roue choisit la teinte par l’angle et l’intensité par la distance au centre. Le centre retire la coloration en conservant la teinte choisie pour le prochain geste.

Le nom situé sous une roue la sélectionne sans changer ses réglages. Le curseur **Luminance** et le reset concernent uniquement cette zone. Déplier **Teinte et saturation précises** pour accéder aux deux curseurs numériques. Les roues disposent aussi d’actions VoiceOver ; le composant `ColorWheel` est indépendant de l’éditeur.

Faire défiler le panneau pour accéder aux paramètres globaux :

- **Mélange**, 0…100, défaut 50 : augmente le recouvrement progressif des zones tonales.
- **Balance**, −100…100, défaut 0 : une valeur positive favorise les hautes lumières, une valeur négative les ombres.

Un geste continu produit une seule commande Undo/Redo. Le reset de la roue préserve les autres roues, la balance, le mélange et tous les autres outils. Les paramètres sont sauvegardés avec le développement.

## Traitement

Le grading intervient **après le mélangeur HSL**, dans la LUT perceptuelle sRGB existante. La luminance pondérée détermine trois poids smoothstep dont la somme vaut un. Les changements de balance déplacent cette répartition et le mélange élargit les transitions.

Chaque roue définit un vecteur de teinte auquel on soustrait sa luminance pondérée. Sans correction de luminance, la coloration préserve donc cette luminance pondérée. Une enveloppe `4y(1−y)` protège les extrémités noire et blanche. Les corrections de luminance sont pondérées séparément. Si une coloration sort du gamut, son amplitude est réduite uniformément pour préserver sa direction, plutôt que d’écrêter séparément ses canaux.

Ces choix constituent un algorithme propre à Lumora. Le ciblage reste perceptuel SDR, pas une séparation physique de l’exposition RAW. La « luminance » décrite ici est la somme pondérée des composantes sRGB perceptuelles, pas la luminance photométrique linéaire. La compression peut atténuer fortement une teinte sur une couleur déjà en limite de gamut.

Les vecteurs des trois roues sont précalculés une fois par LUT. L’interpolation Core Image, les niveaux d’aperçu 960/2048 px, les générations et l’annulation restent ceux du moteur existant. Les limites de la LUT 32³ et l’absence d’export HDR demeurent. L’[export pleine résolution](Export.md) utilise le même pipeline.

## Modèle et migration

`ColorGrading` et `GradingWheel` sont Codable/Sendable. La teinte est circulaire (0…360°), la saturation bornée à 0…100, la luminance et la balance à −100…100. Mélange et balance seuls ne produisent aucun effet si les roues sont neutres.

Les documents précédents, sans `colorGrading`, reçoivent un grading neutre avec mélange 50 et balance 0. Les paramètres existants sont conservés. Les groupes absents d’un JSON partiel prennent leurs valeurs par défaut.

## Fichiers

Créés :

- `Lumora/Adjustments/ColorGrading.swift` : paramètres, validation, conversion des coordonnées et transformée précalculée.
- `Lumora/UI/ColorWheel.swift` : composant de roue réutilisable et accessible.
- `Lumora/UI/ColorGradingView.swift` : panneau et contrôles.
- `Tests/LumoraCoreTests/ColorGradingTests.swift` : tests du modèle et de la transformée.
- `Documentation/ColorGrading.md` : ce document.

Modifiés : `EditState`, `EditorSession`, `RenderEngine`, `EditorView`, `AdjustmentSlider`, tests de rendu, parcours UI et documentation. Le repère central du curseur n’est plus affiché sur les plages unipolaires : leur zéro se trouve au début de la piste.

## Vérifications

**33 tests du cœur réussis**, dont partition des poids, ciblage tonal, balance, identité, conservation de la luminance, protection des extrémités, compression du gamut, aller-retour des coordonnées de roue, migration/sérialisation et historique. Un test Core Image colore réellement une rampe neutre en bleu puis vérifie le retour exact à l’histogramme initial après reset.

Validation finale : **build iOS réussi, 33 tests du cœur et 1 parcours UI étendu réussis**. Le parcours vérifie le déplacement tactile dans une roue, Undo/Redo, la luminance par zone, mélange/balance, reset, restauration après relancement et les fonctions des itérations précédentes. Aucun warning Swift ; avertissement Xcode App Intents non bloquant inchangé.

Résultats de cette session : `/tmp/lumora-grading-tests.log`, `/tmp/lumora-grading-build.log`, `/tmp/lumora-grading-ui.log`, `/tmp/LumoraGradingUITests.xcresult`. Les performances sur appareil physique et le traitement HDR restent à valider ultérieurement.
