# Réorganisation de la validation — 26 septembre 2026

Les corpus, campagnes, rapports, outils R&D, tests SwiftPM et tests UI sont regroupés dans `Validation/`. Les sources de production restent dans `Lumora/`, les configurations de build à la racine et la documentation fonctionnelle dans `Docs/` et `Documentation/`.

Voir [l’index](../README.md) et [la correspondance des anciens chemins](../relocation-map.json).

## Contrôles

| Contrôle | Résultat |
|---|---|
| Déplacement de 47 emplacements | PASS |
| Présence des 56 112 fichiers inventoriés après déplacement | PASS — aucune perte |
| Conservation des 3 595 liens Markdown auparavant résolus | PASS |
| Sources Swift de production comparées à l’état de départ | PASS — inchangées |
| Tests du cœur | PASS — 156 tests |
| Visual Test Lab : campagne Creative rapide, coordonnées, FFT | PASS — 3 tests |
| Recompilation après les derniers chemins corrigés | PASS — test de coordonnées |
| Application iOS et cible de tests UI | PASS — build-for-testing, simulateur arm64 |
| Syntaxe Python et shell | PASS |
| Contrôle de structure | PASS — `python3 Validation/Scripts/check_layout.py` |

Les [journaux](../LayoutSmoke/Logs/) et le [rapport du contrôle Creative](../LayoutSmoke/CreativeFXValidationReport.md) sont conservés. Ce contrôle vérifie le banc après déplacement ; il ne constitue pas une nouvelle approbation esthétique de toutes les campagnes.

## Documentation et compatibilité

README, index, liens Markdown, chemins SwiftPM/Xcode, scripts et accès aux corpus ont été actualisés. Les noms des cibles restent identiques. Les fichiers déjà suivis par Git restent suivis, y compris les artefacts situés dans des dossiers ignorés. Les modifications présentes avant cette tâche sont conservées.

Les journaux historiques, sauvegardes et résultats Xcode gardent leurs chemins enregistrés à l’époque : ce sont des traces historiques. Les corpus locaux et certains artefacts ignorés ne sont pas disponibles dans un clone sans leur copie ou régénération. Les liens déjà manquants avant cette réorganisation ne sont pas présentés comme réparés.

Les tests UI ont été compilés, pas rejoués sur appareil. Les campagnes photographiques exhaustives n’ont pas été relancées pour ce changement de structure. Aucun algorithme photographique ni preset n’a été modifié. Aucun commit créé pendant cette tâche.
