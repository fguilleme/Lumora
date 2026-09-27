# Réglages de l’éditeur

Préférences enregistrées localement dans UserDefaults, indépendantes de l’état et de l’historique des photos.

- Affichage de l’histogramme flottant, visible par défaut. Le masquer annule aussi son indication temporaire d’écrêtage ; l’histogramme du panneau Courbes reste disponible.
- Liste de tous les onglets avec un bouton œil de visibilité et une poignée de réorganisation.
- Réglages reste toujours visible, même si tous les autres onglets sont masqués ; il peut être déplacé.
- Accès supplémentaire par le menu d’options et sur l’écran sans photo.
- Masquer un onglet ne modifie pas les retouches qu’il contient. Si une sélection devient invisible, l’éditeur choisit un onglet visible.
- Restauration de l’histogramme et de tous les onglets dans l’ordre initial, sans réinitialiser les photos.
- Ordre stocké avec des identifiants indépendants de la langue ; doublons/identifiants inconnus filtrés et nouveaux onglets ajoutés.
- Rubrique Réglages ajoutée à l’aide ; français et anglais vérifiés.

Contrôles de préférences : valeurs par défaut, données invalides, doublons, éléments inconnus, visibilité sûre et aller-retour de l’ordre réussis (`PreferencesChecks.swift`).

Test UI final réussi sur l’iPhone 15 Pro (`UITestsVerified.xcresult`) : masquage effectif de l’histogramme et de Créatif, conservation après relancement, restauration, déplacement de Lumière devant Créatif avec la poignée, conservation du nouvel ordre après relancement, puis retour aux préférences par défaut. Les premiers scripts visaient une poignée partiellement masquée par la barre inférieure ; le test final la fait défiler entièrement dans la zone visible avant le geste.

Les commandes de visibilité utilisent des boutons œil distincts des poignées. Les bindings de préférences sont partagés avec l’éditeur ; les retouches et leur historique restent indépendants.

Compilation Release réussie ; version installée et lancée normalement sur l’iPhone après le test. Les préférences de test ont été réinitialisées : histogramme visible et ordre initial des onglets.

## Aide et Réglages sans aperçu

Ces deux onglets occupent maintenant toute la zone centrale, en portrait comme en paysage. Photo et histogramme ne sont pas affichés ; la barre d’onglets reste disponible. Compilation Release réussie et version installée sur l’iPhone. Le test UI existant a été adapté à cette présentation ; il n’a pas été réexécuté pour cette seule modification de disposition.
