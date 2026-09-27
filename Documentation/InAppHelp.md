# In-app editor help

The **Help** tab follows **Presets** in the full-width bottom editor toolbar, in portrait and landscape. Landscape controls occupy a side column above that toolbar. **Common gestures** appears first, followed by the eleven editing tabs. Selecting a topic opens a scrollable reading sheet; **Close** returns to the topic list. The guide is bundled with the app and works offline.

Common gestures explains the photo’s short tap (full-screen view), double-tap (reset zoom), long press (compare with original), pinch and pan, plus the histogram’s short tap (expand/collapse), long press (temporary clipping overlay), and drag (move). It also notes that a mask brush or curve eyedropper can take over photo gestures while active.

The tab-specific topics are **Creative**, **Light**, **Color**, **Curves**, **Color Tools**, **Effects**, **Detail**, **Optics**, **Geometry**, **Masks**, and **Presets**. Their content lives in `Lumora/UI/EditorHelpView.swift`, alongside the interface labels. Update the relevant topic when a control is renamed, added, or removed.

Help is read-only: opening and closing a topic does not create an Undo operation, change the active layer, or alter development settings. The photo information row is hidden in this tab to leave room for the topics. The topic buttons (`help-topic-*`), reading sheets (`help-detail-*`), and close button (`help-close`) have accessibility identifiers for simulator tests.


### Depth Lens

Rubrique dédiée après Détail : activation, point et plan de netteté, recentrage, ouverture, focales, exemple modéré, comparaison, réinitialisation/historique, limites des contours, calcul local, aperçu et export. Les gestes communs précisent que le toucher règle la mise au point dans cet onglet. Contenus français et anglais.

### Réglages

Préférences persistantes d’interface : histogramme flottant, visibilité des onglets et ordre par poignées. Réglages reste visible. Masquer un onglet ne désactive pas ses retouches. Rétablir les valeurs par défaut ne modifie aucune photo. Aide française et anglaise ajoutée.

Les onglets Aide et Réglages occupent toute la zone centrale de l’éditeur, sans aperçu photo ni histogramme. La barre d’onglets reste accessible pour revenir aux retouches.

## Éclairage expérimental

Nouvel onglet Éclairage : effet désactivé par défaut, y compris lors de la migration des anciens documents. L’aide décrit la cible de profondeur, la lampe indépendante, la distance relative, les cinq curseurs, la comparaison, les réglages sauvegardés et les limites (ciel non segmenté, ombres existantes, géométrie approximative). Masquer l’onglet ne désactive pas un effet déjà activé. Aucun modèle de rééclairage génératif.
