# Mélangeur HSL — troisième étape

Le mélangeur se trouve désormais dans **Colorimétrie**, sous-onglet **Mélangeur**. Il partage ce panneau avec le Grading afin de regrouper les outils chromatiques sans réduire la hauteur de l’aperçu.

## Utilisation

Faire défiler la barre d’outils inférieure jusqu’à **Mélangeur**. Les huit plages sont Rouge, Orange, Jaune, Vert, Turquoise, Bleu, Violet et Magenta ; faire défiler leurs pastilles horizontalement pour accéder aux dernières.

Chaque plage propose **Teinte, Saturation et Luminance** de −100 à +100. Toucher la valeur numérique active le réglage fin. Double-toucher le curseur, ou utiliser sa flèche, remet le paramètre à zéro. La flèche dans l’en-tête remet les trois paramètres de la plage active à zéro. Les autres plages, réglages globaux et courbes sont conservés.

Les noms et la coche de sélection complètent les pastilles colorées ; VoiceOver peut identifier les plages et régler les curseurs. Chaque geste produit une commande Undo/Redo. Les réglages sont persistés et restaurés avec le document.

## Traitement

Le mélangeur intervient après les courbes et les réglages globaux de saturation/vibrance. Il détermine les poids sur la teinte **avant** modification, puis applique les trois corrections ensemble : l’ordre des plages n’influence pas le résultat.

Les centres des plages sont 0°, 30°, 60°, 120°, 180°, 240°, 270° et 300°. Entre deux centres, un smoothstep mélange les réglages voisins avec une somme des poids égale à un. Les dérivées s’annulent aux centres. Le dernier intervalle relie Magenta à Rouge à 360°, identique à 0°, sans couture.

- **Teinte** : déplacement maximal de ±30° à l’intensité maximale.
- **Saturation** : multiplication de la saturation HSL par un facteur compris entre 0 et 2, bornée à [0,1]. À −100 au centre d’une plage, cette couleur devient neutre.
- **Luminance** : réglage de la clarté HSL, jusqu’à la moitié de la distance vers blanc ou noir. Ce n’est ni une exposition physique ni une mesure de luminance linéaire.
- Les changements de teinte et de clarté s’atténuent entre 0,015 et 0,12 de chroma sRGB. Les gris exacts, le noir et le blanc sont préservés.

Les opérations sont effectuées dans l’espace perceptuel sRGB de la LUT existante, puis interpolées par Core Image. Aucun décodage pleine résolution n’est ajouté pendant les gestes. Le cache et le mécanisme de génération du renderer restent utilisés. La LUT 32³ et les limites SDR/gamut déjà documentées demeurent : absence de discontinuité mathématique ne signifie pas absence garantie de toute quantification sur toutes les images. Aucun objectif de 60 fps sur appareil réel n’est déclaré atteint.

## Modèle et compatibilité

`ColorMixer` est Codable/Sendable et conserve huit groupes nommés `MixerAdjustment`. La validation borne chaque valeur et neutralise les valeurs non finies lors des mutations. Les bandes ou composantes absentes au décodage reprennent leur valeur neutre. Les JSON des étapes précédentes, dépourvus de `colorMixer`, conservent leurs réglages et reçoivent un mélangeur neutre.

Le composant `AdjustmentSlider` accepte maintenant une définition configurable ; les panneaux Lumière/Couleur gardent leur API précédente et le mélangeur partage la même interaction, précision et haptique.

## Fichiers

Créés :

- `Lumora/Adjustments/ColorMixer.swift`
- `Lumora/UI/ColorMixerView.swift`
- `Validation/Tests/LumoraCoreTests/ColorMixerTests.swift`
- `Documentation/ColorMixer.md`

Modifiés : `EditState`, `EditorSession`, `TonalResponse`, `AdjustmentSlider`, `EditorView`, tests du renderer, parcours UI et documentation.

## Validation

26 tests du cœur réussis, dont conversion RGB/HSL aller-retour, protection des gris, sélection des huit centres, transitions circulaires, effets numériques indépendants H/S/L, bornes aux extrêmes, sérialisation/migration, historique et mire réellement rendue par Core Image.

La mire sRGB exige qu’un rouge désaturé devienne gris à 128 ± 2 niveaux et que le bleu distant reste bleu pur à l’arrondi près. Les primaires de la mire sont déclarées explicitement dans leur espace couleur : des CGColor créées dans l’espace RGB générique ne représentent pas les mêmes valeurs sRGB après conversion.

Validation finale : **build iOS réussi, 26 tests du cœur et 1 parcours UI étendu réussis**. Le parcours du simulateur couvre les fonctions des étapes précédentes, les trois curseurs HSL, Undo/Redo, l’indépendance Rouge/Vert, la restauration après relancement, le reset de la plage et son annulation. Aucun warning Swift ; avertissement Xcode App Intents non bloquant inchangé.

Résultats de la session : `/tmp/lumora-mixer-tests.log`, `/tmp/lumora-mixer-build.log`, `/tmp/lumora-mixer-ui.log`, `/tmp/LumoraMixerUITests.xcresult`.
