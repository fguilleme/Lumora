# Densité des panneaux d’édition

Les capsules Grading et les actions Auto utilisent `CompactEditorButtonStyle` : surface visuelle de 36 pt, typographie caption, marges horizontales de 12 pt, zone interactive minimale de 44 pt. La zone tactile est ajoutée après le fond et le contour : elle n’agrandit pas la capsule visible. Les grandes tailles de texte peuvent augmenter la hauteur minimale pour préserver la lisibilité.

Le style définit les états normal, pressé, sélectionné et désactivé. La sélection combine turquoise, contour et coche ; les traits d’accessibilité sélectionnés et les identifiants existants restent présents. Les groupes Auto ont des segments de même largeur avec un fond commun.

Grading place Neutral au début de la même bande défilante que les familles Portrait, Cinéma, Atmosphère et Spécial. Les titres de famille utilisent caption2. Le nom actif/Personnalisé est une ligne secondaire ; aucune rangée de grand bouton Reset n’est réservée à Neutral.

Auto conserve une ligne d’action et d’état compacte. Dans Courbes, Naturel/Équilibré/Soutenu forment un seul groupe visuel. Le même bouton compact s’applique aussi à Lumière et Couleur. Les actions, paramètres, transactions d’historique et fonctions d’analyse sont inchangés.

## Audit de cohérence

- Creative : le style existant sépare déjà la surface de la cible de 44 pt ; conservé.
- Géométrie et Masques : pas de cumul de hauteur minimale du label et de marges de bouton pour les choix ordinaires ; conservés.
- Navigation basse, safe areas, hauteur du panneau et renderers : inchangés.
- Aucun placement absolu ni branche par appareil.

## Validation visuelle

Les captures montrent les sélecteurs et une partie exploitable de la roue/courbe, sans défilement vertical préalable. La hauteur globale du panneau reste celle de Lumora ; le défilement donne accès au reste des contrôles.

| Format | Grading | Courbes |
|---|---|---|
| iPhone 13 mini, compact | [Capture](UIDensity/iPhone-compact-Grading.png) | [Capture](UIDensity/iPhone-compact-Curves.png) |
| iPhone 18 Pro Max | [Capture](UIDensity/iPhone-large-Grading.png) | [Capture](UIDensity/iPhone-large-Curves.png) |
| iPad Pro 13 pouces | [Capture](UIDensity/iPad-Grading.png) | [Capture](UIDensity/iPad-Curves.png) |

Le nouveau test UI contrôle des boutons de 44 à 46 pt, les états sélectionnés et l’accès à la roue/courbe. Les contrôles sont exposés par leur libellé et leur trait sélectionné dans l’arbre d’accessibilité ; une session VoiceOver audio n’a pas été exécutée.

La première préparation des simulateurs a rencontré une saturation du disque système (installation et collecte XCTest impossibles). Les caches de builds temporaires ont été déplacés sur le disque de développement, et le simulateur iPad dédié a été supprimé après conservation de ses résultats. Les essais affectés ont été relancés. Le geste de défilement du test Grading utilise désormais la marge du panneau, afin de ne pas éditer la roue située sous son ancien trajet central. Les balayages horizontaux complets dépassaient une capsule intermédiaire ; le test utilise des glissements courts avec arrêt, sans changer le défilement natif de l’application.

Le build final et les tests UI utilisent `SYMROOT`/`OBJROOT` dans `TestArtifacts/UIDensityBuild`, afin de ne pas dépendre du dossier de produits Xcode partagé devenu indisponible pendant la validation. Ces fichiers sont locaux et non versionnés.

## Résultats finaux

- Build Lumora + tests UI : PASS.
- Tests du cœur : 106 PASS.
- Layout Grading/Courbes : PASS sur iPhone 13 mini, iPhone 18 Pro Max et iPad Pro 13 pouces ; six captures inspectées.
- Auto Lumière/Couleur/Courbes, Naturel/Équilibré/Soutenu, Custom, Undo/Redo et persistance : PASS.
- Les 16 presets, défilement horizontal, Custom, Undo/Redo, 36 sélections répétées et réouverture du document : PASS.
- `git diff --check` : PASS. Les seuls fichiers applicatifs modifiés sont les deux sélecteurs UI et le nouveau style partagé. Aucun changement des valeurs de presets, des réglages, des algorithmes, des transactions d’historique ou du renderer ; navigation basse conservée.

Logs locaux : `/private/tmp/lumora-density-isolated-build.log`, `lumora-density-core.log`, `lumora-density-compact-2.log`, `lumora-density-ipad-2.log`, `lumora-density-large-final.log`, `lumora-density-regression.log` (parcours Auto réussi), `lumora-density-grading-verified.log` (parcours Grading final réussi).
