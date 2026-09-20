# Presets — onzième étape

## Format partiel et application

Un `Preset` contient un UUID, un nom, une date de création, un `formatVersion`, les valeurs capturées et l’ensemble explicite des groupes sélectionnés. Les groupes disponibles sont Lumière, Couleur, Courbes, Mélangeur, Grading, Effets, Détail, Optique, Géométrie et Masques.

Appliquer un preset remplace uniquement les groupes sélectionnés. Par exemple, un preset Lumière + Effets conserve la température, le recadrage et tous les masques déjà présents sur la photographie. L’application produit une seule commande d’historique, reste annulable/rétablissable et déclenche le même rendu haute qualité que les autres changements.

Lors de la création, Lumora sélectionne par défaut les groupes photographiques Lumière, Couleur, Courbes, Mélangeur, Grading, Effets et Détail. Optique, Géométrie et Masques restent décochés car ils dépendent souvent du fichier ou de la composition. L’utilisateur peut néanmoins les inclure explicitement.

## Bibliothèque et échange

La bibliothèque est enregistrée dans Application Support, dans un fichier atomique par preset. L’interface permet de créer, renommer, supprimer et appliquer les presets. Elle utilise les sélecteurs système pour importer ou exporter un JSON nommé `Nom.lumorapreset.json`.

Un import valide la taille maximale de 5 Mo, le JSON, la version, le nom et la présence d’au moins un groupe. Il attribue ensuite un nouvel UUID et une nouvelle date afin de ne jamais écraser silencieusement un preset local portant le même identifiant. Les valeurs importées passent par la validation complète d’`EditState`, y compris les limites de masques et de géométrie.

## Validation et limites

Quatre tests vérifient l’application partielle, l’inclusion volontaire de la géométrie et des masques, la sérialisation/version, ainsi qu’un cycle réel création → lecture → renommage → export JSON → import → suppression sur disque. La suite du cœur compte désormais **82 tests réussis**.

Le parcours XCTest dédié crée un preset depuis une exposition modifiée, réinitialise la photo, applique le preset, vérifie Undo/Redo, le renomme, relance l’application pour vérifier sa persistance puis le supprime.

![Bibliothèque de presets validée dans le simulateur](Presets-Simulator.png)

Les presets sont actuellement privés à l’installation de l’app, hors import/export manuel. Il n’existe pas encore de presets intégrés, de synchronisation iCloud, de dossiers ou d’aperçu miniature avant application.
