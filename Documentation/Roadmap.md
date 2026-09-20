# Feuille de route différée

Ce document conserve les évolutions volontairement repoussées après la mise en place de l’éditeur, des masques, de la géométrie, de l’export et de la bibliothèque avec opérations groupées. L’ordre ci-dessous privilégie d’abord les flux de travail quotidiens, puis les fonctions qui demandent une évolution du stockage ou du pipeline couleur.

## 1. Import et traitement en lot

### Import en lot

- Autoriser une sélection multiple dans les sélecteurs Photos et Fichiers.
- Copier chaque original dans un document indépendant sans bloquer l’interface.
- Afficher la progression globale et l’état de chaque fichier.
- Continuer les autres imports lorsqu’un fichier est illisible et présenter un récapitulatif exploitable.
- Permettre l’annulation sans laisser de document incomplet.
- Ouvrir la bibliothèque sur les nouveaux documents afin de les classer avec les opérations groupées existantes.

### Traitement et export par lots

- Appliquer un preset ou un groupe de réglages à plusieurs documents sélectionnés.
- Exporter plusieurs documents avec une configuration commune et des noms sans collision.
- Afficher progression, annulation, erreurs individuelles et espace disque estimé.
- Ajouter, si utile, un enregistrement direct dans Photos en complément de la feuille de partage.

## 2. Sécurité de la bibliothèque

### Corbeille récupérable

- Remplacer la suppression immédiate par un déplacement atomique vers une corbeille locale.
- Restaurer original, retouches, favoris, dossier et étiquettes.
- Proposer une suppression définitive et une politique de purge explicite.
- Préserver la protection contre les sauvegardes asynchrones tardives.

### Historique persistant

- Conserver une version bornée de l’historique Undo/Redo avec le document.
- Migrer les sidecars existants sans modifier leur rendu.
- Éviter une croissance incontrôlée du stockage pour les pinceaux et les masques raster.

## 3. Synchronisation

### Bibliothèque iCloud

- Synchroniser les originaux, retouches, dossiers, étiquettes et favoris entre appareils.
- Rendre l’état local ou distant visible et permettre un usage hors connexion.
- Définir une résolution des conflits explicite pour les éditions concurrentes.
- Garder la synchronisation optionnelle et ne jamais écraser silencieusement une version.
- Tester les migrations, reprises après interruption et bibliothèques volumineuses.

### Presets

- Ajouter des presets intégrés clairement séparés des presets personnels.
- Proposer dossiers, aperçu miniature et synchronisation iCloud facultative.
- Conserver l’import/export JSON et sa validation stricte.

## 4. Géométrie et masques

### Calibration architecturale à plusieurs guides

- Permettre de tracer plusieurs guides verticaux et horizontaux sur la photo.
- Estimer la transformation de perspective à partir de l’ensemble des lignes.
- Afficher le résultat de manière non destructive avec Undo/Redo et poignées directes.
- Gérer les configurations insuffisantes ou contradictoires sans produire de transformation instable.

### Affinage des masques intelligents

- Attacher un pinceau d’ajout et de retrait directement à une composante Vision.
- Conserver la matte générée comme base reproductible et les corrections comme données éditables.
- Étudier le suivi des contours et la détection de cheveux sans dépendance à un service distant.

## 5. RAW, HDR et profondeur de couleur

### Développement RAW avancé

- Exposer les paramètres natifs pertinents de `CIRAWFilter` sans doubler exposition, netteté ou débruitage.
- Afficher les capacités réellement disponibles pour chaque fichier et chaque boîtier.
- Calibrer les contrôles sur un corpus RAW multi-marques et plusieurs niveaux ISO.

### Pipeline HDR/EDR

- Retarder l’écrêtage actuellement introduit par la LUT sRGB 32³.
- Définir des espaces de travail et de sortie explicites pour HDR et gamut étendu.
- Ajouter l’aperçu EDR sur les appareils compatibles.
- Étudier HEIF HDR et TIFF 16 bits avec métadonnées et profils corrects.
- Garantir que le chemin SDR actuel reste visuellement stable.

## 6. Performance et validation matérielle

- Mesurer la fluidité réelle des gestes et curseurs sur plusieurs générations d’iPhone ; ne déclarer 60 fps qu’après mesure.
- Profiler mémoire, GPU, caches et export sur des images 48 MP.
- Tester JPEG, HEIC, PNG et TIFF avec orientations, profils couleur et métadonnées variés.
- Valider RAW/DNG et profils optiques sur plusieurs boîtiers physiques.
- Étudier un rendu tuilé à 100 % pour le zoom profond sans décoder inutilement toute l’image pendant un geste.
- Ajouter des tests de charge pour l’import, la synchronisation et l’export en lot.

## Ordre recommandé

1. Import en lot.
2. Traitement et export par lots.
3. Corbeille récupérable.
4. Synchronisation de bibliothèque et presets.
5. Guides architecturaux et affinage des masques intelligents.
6. Contrôles RAW, HDR/EDR et sorties à profondeur supérieure.
7. Optimisation finale fondée sur les mesures réalisées sur appareil.
