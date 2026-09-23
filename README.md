# Lumora

Éditeur photo natif SwiftUI, iOS 18+, Swift 6, sans dépendance tierce.
Lumora propose un développement non destructif, des masques composables, une bibliothèque locale, l’export pleine résolution et une pile de **treize Creative FX**. Les derniers ajouts sont Silver B&W, Silver Toning et Darken / Lighten Center.

État documenté au **22 septembre 2026** : Darken / Lighten Center est implémenté, avec déplacement direct du centre et huit looks. Son banc compte **831 PASS / 13 WARN photographiques / 0 FAIL** ; les WARN concernent les nouvelles hautes lumières écrêtées en SDR. L’inspection visuelle reste ouverte, comme celle de Silver Toning (Deep Selenium mauve sur les portraits). Aucun Golden Master Silver ou Darken / Lighten Center n’est créé ; un PASS technique ne constitue pas une approbation esthétique.

## Exécuter

Ouvrir `Lumora.xcodeproj`, choisir le scheme **Lumora**, puis un iPhone ou un simulateur. La signature utilise l’équipe déjà configurée dans le projet ; adapter celle-ci si nécessaire sur un appareil physique.

```sh
xcodebuild -project Lumora.xcodeproj -scheme Lumora -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
swift test --filter LumoraCoreTests
```

Les tests Swift Testing exécutent le cœur partagé et Core Image sur macOS, indépendamment de SwiftUI. Le filtre ci-dessus lance le cœur sans les campagnes photographiques. `swift test` sans filtre inclut le Visual Test Lab et exige notamment le corpus local pour les campagnes Silver ; voir [les commandes et prérequis du banc](Docs/VISUAL_VALIDATION.md). Une cible XCTest UI séparée vérifie le parcours Photos → réglage → Undo/Redo → comparaison → restauration sur simulateur. Elle suppose une photothèque de simulateur contenant au moins deux photos et sélectionne une tuile via son identifiant d’accessibilité système.

## Utilisation

- Importer depuis Photos ou Fichiers. Le sélecteur Photos donne uniquement accès au fichier choisi, sans autorisation globale de photothèque.
- Ajuster Lumière / Couleur. Les contrôles défilent dans un panneau compact. La ligne d’informations est réservée aux panneaux de développement ; elle affiche le nom sans extension, le calque actif, le format et la résolution. Elle est masquée dans Creative, Optique, Géométrie, Masques et Presets, libérant cet espace pour l’aperçu.
- Pendant le déplacement d’un curseur, l’interface secondaire s’efface sur le fond noir pour laisser l’image et le réglage actif au premier plan.
- Toucher une valeur numérique pour activer/désactiver le réglage fin. Double-toucher le curseur, ou utiliser sa flèche, pour le réinitialiser.
- Annuler/rétablir avec les boutons supérieurs. Un déplacement continu du curseur crée une opération d’historique.
- Maintenir la photographie pour voir l’original ; relâcher pour revenir.
- Pincer pour zoomer, déplacer lorsque l’image est agrandie, puis double-toucher pour rétablir le cadrage initial.
- Ouvrir **Courbes** pour modifier RVB/Rouge/Vert/Bleu. Le graphe est d’abord en consultation : on peut faire défiler le panneau sans changer la courbe. **Modifier** active l’édition ; toucher le graphe ajoute un point, glisser un point le déplace, et les contrôles Entrée/Sortie permettent un réglage précis. La **pipette** situe une tonalité de la photo sur la courbe ; le bouton **+** crée ensuite un point si souhaité. **Terminé** rend le défilement passif.
- Ouvrir **Colorimétrie**, puis le sous-onglet **Mélangeur**, pour régler Teinte/Saturation/Luminance sur huit plages de couleur.
- Dans **Colorimétrie**, ouvrir **Grading**, choisir Ombres, Tons moyens ou Hautes lumières, puis utiliser la roue chromatique unique ainsi que les réglages de mélange et de balance.
- **Presets Color Grading** : 16 réglages photographiques éditables, Neutral/Personnalisé, familles Portrait/Cinematic/Atmosphere/Special. [Guide et validation](Documentation/ColorGradingPresets.md).
- Ouvrir **Effets** pour régler séparément Texture, Clarté, Correction du voile, Vignette et Grain.
- Ouvrir **Creative** pour ajouter un effet, choisir un look, régler ses paramètres, lui affecter un masque et modifier l’ordre de la pile. Une modification de preset affiche **Custom** ; Undo/Redo s’applique à toute la pile. L’inspecteur **100 %** permet d’examiner une région à la résolution source.
- Dans **Darken / Lighten Center**, déplacer la poignée sur le sujet puis régler séparément Center et Border en EV. Size, Shape, Feather et Rotation définissent une zone elliptique ; les coordonnées fines sont accessibles via **Position précise X / Y**.
- Pour un tirage monochrome, utiliser **Silver B&W → Silver Toning**, puis ajouter **Film Grain** si souhaité. Inverser les effets change le résultat.
- Ouvrir **Détail** pour la netteté avec masquage et les réductions de bruit de luminance et de couleur.
- Ouvrir **Optique** pour le profil constructeur RAW, la distorsion, l’aberration chromatique et le vignetage optique.
- Ouvrir **Géométrie** pour tourner, redresser l’horizon et corriger les perspectives verticale et horizontale manuellement ou automatiquement, ajuster aspect/échelle/décalage, puis recadrer avec une grille de tiers.
- Les icônes **Photos** et **Bibliothèque** de la barre supérieure donnent un accès direct à l’import et aux images enregistrées.
- Ouvrir **Masques** pour gérer la pile de modifications. **Photo entière** est le premier calque ; chaque masque ajouté devient un calque sélectionnable, renommable, réordonnable et doté de sa propre opacité. Le nom du calque affiché à côté du fichier ouvre aussi un sélecteur rapide accessible depuis les autres panneaux. Les poignées blanches et jaunes déplacent et redimensionnent directement les gradients sur la photo, même après zoom. Le pinceau distingue Peindre, Effacer et Déplacer ; un double toucher remet le zoom à 100 % dans chacun de ces modes sans modifier le masque ; dans Masques, seule la visualisation du masque est actualisée, puis le développement reprend à la sortie du panneau. Le bouton Visible / Contour alterne overlay rouge et contour blanc sans désactiver le calque. Les réglages de développement du calque se font dans Lumière, Couleur, Courbes, Mélangeur, Grading, Effets et Détail ; leurs sliders ne sont plus dupliqués dans Masques.
- Ouvrir **Presets** pour enregistrer des groupes de réglages, les appliquer avec Undo/Redo et les importer ou exporter au format JSON.
- Choisir **Exporter** dans le menu supérieur : format, dimensions, profil couleur et métadonnées, puis **Créer le fichier** et **Partager ou enregistrer…**.
- Utiliser **Auto** dans Lumière, Couleur ou Courbes pour obtenir des paramètres éditables à partir d’une analyse commune. Auto Lumière/Courbes remplace explicitement le couple Lumière + courbe RVB pour éviter une double correction ; Auto Couleur reste indépendant. [Fonctionnement et limites](Documentation/AutoCorrection.md). La [correction du mapping WB](Documentation/AutoWBMapping.md) documente les axes mesurés et la validation des dominantes connues ; la [validation low-key/contre-jour](AutoStressCorpus/Results/LowKeyBacklitFix/LowKeyBacklitClassificationFixReport.md) examine la distinction entre portrait sombre, silhouette et nuit.
- Toucher l’histogramme RVB flottant pour l’agrandir ou le réduire sans déplacer la photo. En mode agrandi, de discrets indicateurs signalent une occupation notable des extrémités de l’aperçu SDR ; ils ne mesurent pas l’écrêtage irrécupérable du fichier original. Voir le [rapport de validation](HistogramOverlayValidationReport.md).
- Ouvrir **Bibliothèque** dans le menu supérieur pour rechercher les développements locaux, les trier par date ou nom, gérer leurs favoris, dossiers et étiquettes multiples, rouvrir une photo ou la supprimer après confirmation. **Sélectionner** permet d’appliquer ces classements ou une suppression à plusieurs photos. Le dernier document reste restauré automatiquement au prochain lancement.

## Architecture

- **Editor** : `EditState` Codable/Sendable, définitions des plages, commandes de paramètres, historique borné et presets partiels ; `EditorSession` Observable sur MainActor orchestre l’UI.
- **Rendering** : `RenderEngine` est un actor indépendant de SwiftUI. Core Image utilise Metal lorsqu’il est disponible. Deux originaux décodés réduits sont mis en cache, à 960 et 2048 pixels sur le grand côté. Les générations obsolètes ne remplacent jamais un résultat récent.
- **Adjustments / Masks** : pile ordonnée composée d’un développement pleine image puis de calques masqués. Chaque calque possède nom, visibilité et opacité et peut porter réponse tonale, courbes PCHIP, vibrance, mélangeur HSL, grading, effets, débruitage et netteté. Optique et géométrie restent communes au document.
- **Creative** : catalogue de paramètres et presets, pile ordonnée sérialisable, renderers Core Image/Metal et composition avec les masques existants. Les moteurs film, N&B et virage restent indépendants ; ils ne génèrent pas implicitement du grain.
- **Library / Persistence** : import par fichier transférable, copie privée unique de l’original, index reconstruit depuis les sidecars, recherche et tri en mémoire, favoris, dossiers et étiquettes multiples persistants, opérations groupées, miniatures locales et JSON atomique versionné. Les écritures périmées ou postérieures à une suppression sont rejetées.
- **Export** : rendu depuis l’original avec un contexte indépendant, options ImageIO, métadonnées filtrées et partage système.
- **UI** : écran, canvas, histogramme, curseur réutilisable dans des fichiers distincts.

Voir [le guide Creative FX](Documentation/CreativeEffects.md), [leur architecture](Docs/CREATIVE_FX.md), [le Visual Test Lab](Docs/VISUAL_VALIDATION.md), [la feuille de route différée](Documentation/Roadmap.md), [la bibliothèque locale](Documentation/Library.md), [les presets](Documentation/Presets.md), [la pile de modifications](Documentation/AdjustmentLayers.md), [l’édition directe des masques](Documentation/MaskEditing.md), [les masques locaux](Documentation/Masks.md), [les masques intelligents](Documentation/SmartMasks.md), [la géométrie et le recadrage](Documentation/Geometry.md), [les corrections optiques](Documentation/Optics.md), [le panneau Détail](Documentation/Detail.md), [les effets](Documentation/Effects.md), [l’export et ses limites](Documentation/Export.md), [le color grading](Documentation/ColorGrading.md), [le mélangeur HSL](Documentation/ColorMixer.md), [le fonctionnement des courbes](Documentation/Curves.md), [les choix de rendu et limites](Documentation/Rendering.md) et [l’inventaire](Documentation/Files.md).

## Périmètre réellement implémenté

Import Photos/Fichiers, bibliothèque locale avec miniatures/recherche/tri/favoris/dossiers/étiquettes multiples/sélection et opérations groupées/réouverture/suppression, décodage ImageIO JPEG/HEIC/PNG/TIFF, décodage RAW/DNG via CIRAWFilter lorsqu’Apple prend en charge le fichier, profil optique RAW lorsque disponible, corrections manuelles de distorsion/aberration/vignetage, orientation, rotation, miroirs, redressement automatique de l’horizon, perspective verticale/horizontale manuelle ou automatique, aspect, échelle, décalage et crop, réglages exposition/contraste/hautes lumières/ombres/blancs/noirs/température/teinte/saturation/vibrance, courbes RVB et par canal, panneau Colorimétrie réunissant mélangeur HSL à huit plages et grading tonal sur une roue unique, Texture, Clarté, Correction du voile, Vignette, Grain, netteté avec masquage, réduction du bruit lumineux et coloré, masques pinceau/linéaire/radial et Sujet/Arrière-plan/Personne/Visage/Yeux/Ciel/Peau composables, pinceau Peindre/Effacer avec diamètre visible, édition directe de la position, de la taille, de l’angle et du contour progressif des gradients, presets partiels importables/exportables, comparaison, zoom et déplacement, Undo/Redo, histogramme asynchrone, sauvegarde du dernier développement, export JPEG/HEIC/PNG/TIFF selon les encodeurs disponibles, panneau DEBUG de temps de rendu/dimensions/cache/génération.

## Creative FX disponibles

| Famille | Effets |
|---|---|
| Tonalité | High Key, Low Key, Pro Contrast |
| Exposition spatiale | Darken / Lighten Center |
| Détail | Tonal Contrast, Detail Extractor |
| Grain et diffusion | Film Grain, Glamour Glow |
| Réponses couleur | Bleach Bypass, Cross Processing, Film Emulation |
| Tirage monochrome | Silver B&W, Silver Toning |

Film Emulation propose sept types originaux. Silver B&W propose sept réponses spectrales et huit looks ; Silver Toning propose neuf toners et onze looks avec contributions argent/papier. Le Grain du panneau Effets et Film Grain partagent un moteur ; les activer ensemble additionne leurs contributions.

## Validation et documentation

**Adaptive Tone — recherche hors production** : l'essai du contrôle manuel sur iPhone a révélé un blocage de l'interface pour un gain visuel faible ; le contrôle et son rendu ont été retirés. Voir le [rapport de retrait](AdaptiveToneRemovalReport.md). Les prototypes des phases 1–5 et les artefacts de validation Phase 6 restent dans l'espace de travail de recherche, hors de l'application.

Color Grading Presets : **16 presets**, **876 PASS / 29 WARN / 0 FAIL**, 106 tests Core, tests UI iPhone/iPad et 126 comparaisons de rendu manuel/Creative FX réussis. Les WARN restent à inspecter ; aucun tuning automatique. [Bilan et limites](Documentation/ColorGradingPresetsValidation.md).

Les contrôles d’interface couvrent également les poignées de masque sous zoom, la navigation séparée du pinceau, le rendu différé dans Masques, les informations contextuelles et les actions Creative directes. Les tests de rendu des effets restent indépendants de ces changements d’éditeur.

Campagne Creative précédente, commit `514b724` : build iOS Simulator et test UI réussis, **97 tests Core réussis**, **77 presets antérieurs bit-identiques**. Darken / Lighten Center : **831 contrôles PASS**, dont **751 hard invariants**, **13 WARN de clipping SDR**, **aucun FAIL**. Le banc commun compte 58 cas PASS et neuf WARN historiques. Les mesures GPU sur M2 Pro sont de 0,18 / 0,73 / 2,91 ms à 1024 / 2048 / 4096 ; elles ne certifient pas les performances d’un iPhone. Les corrections techniques et la revalidation sont consignées dans le rapport.

- [Rapport Darken / Lighten Center](TestArtifacts/DarkenLightenCenterValidationReport.md) : géométrie, positionnement, exposition, huit photos et interaction directe.
- [Rapport Silver Toning](TestArtifacts/SilverToningValidationReport.md) : résultats, tableaux par photo, performances et liens « Priority Visual Inspection ».
- [Rapport Silver B&W](TestArtifacts/SilverBWValidationReport.md) : conversion spectrale, filtres, tonalité et structure.
- [Rapport Film Emulation](TestArtifacts/FilmEmulationValidationReport.md) : campagne initiale ; le raffinement Dense Slide approuvé est décrit dans la documentation Creative.
- [Inventaire du projet](Documentation/Files.md) : code, guides et bancs de validation.

`TestArtifacts/` est ignoré par défaut, avec certains rapports et résultats synthétiques explicitement versionnés. Les originaux et planches photographiques restent locaux : un clone sans [le corpus](VisualTestAssets/README.md) ne contient pas tous les fichiers liés. Les images sont des artefacts de validation, pas des Golden Masters approuvés.

## Fonctions différées

L’import en lot, la synchronisation de bibliothèque et la calibration architecturale à plusieurs guides ne sont **pas encore implémentés**. La perspective automatique repose sur les structures rectangulaires visibles ; les poignées directes permettent ensuite de corriger manuellement ses quatre coins et le recadrage.

Les kernels film/Silver acceptent les valeurs extended linear sRGB ; cela ne constitue pas une chaîne HDR complète. Pas encore de validation RAW multi-boîtiers, de mesure 60 fps sur matériel, de rendu HDR/EDR de bout en bout, de traitement par lots, ni de persistance de l’historique Undo au redémarrage. Une connexion peut être nécessaire pour récupérer un original situé dans iCloud via le sélecteur système ; le développement et sa bibliothèque restent locaux.

Le détail, les critères attendus et l’ordre recommandé sont conservés dans [la feuille de route](Documentation/Roadmap.md).

Les panneaux Auto et Grading utilisent des [contrôles compacts](Documentation/UIDensity.md), avec cibles tactiles de 44 pt.
