# Inventaire du projet

Les sections numérotées ci-dessous conservent l’historique des premières étapes. La carte actuelle des Creative FX est présentée en tête.

## Creative FX — état au 22 septembre 2026

| Emplacement | Rôle |
|---|---|
| `Lumora/Creative/CreativeEffect.swift` | Catalogue des douze effets, paramètres, pile et presets/Custom |
| `Lumora/Creative/CreativeRenderer.swift` | Registre et compositor commun, masques et opacité |
| `Lumora/Creative/` | Renderers et modèles, dont Film Grain, Film Emulation, Silver B&W et Silver Toning |
| `Lumora/UI/CreativeEffectsView.swift` | Gestion de pile, presets et contrôles spécialisés |
| `Lumora/Rendering/RenderEngine.swift` | Preview, HQ, export et inspection native |
| `Tests/LumoraVisualTestLab/` | Mires, mesures GPU, corpus, rapports et validation dédiée par effet |
| `VisualTestAssets/` | Huit originaux photographiques locaux, non embarqués |
| `TestArtifacts/` | Rapports, métriques et images générées ; certains résultats sont versionnés explicitement |
| `Docs/CREATIVE_FX.md` | Architecture de la pile et des moteurs |
| `Docs/VISUAL_VALIDATION.md` | Commandes, prérequis, résultats et règles de validation |
| `Documentation/CreativeEffects.md` | Guide utilisateur et workflows film/argentique |

Les fichiers `SilverBW*.swift` et `SilverToning*.swift` du Lab séparent validation numérique, intégration, photographies et rapport. `SilverToningStatistics.swift` ajoute les tableaux descriptifs ; `SilverToningRegression.swift` compare les effets antérieurs à une référence temporaire explicitement enregistrée.


## Fichiers créés

- `.gitignore` : exclusions des fichiers de compilation.
- `Package.swift` : compilation et tests du cœur sans SwiftUI.
- `README.md` : installation, utilisation, architecture et périmètre.
- `Documentation/Rendering.md` : pipeline, espaces couleur, performances et limites.
- `Documentation/Roadmap.md` : fonctions différées, validations matérielles et ordre de reprise recommandé.
- `Documentation/Files.md` : cet inventaire.
- `Documentation/Editor-Simulator.jpg` : capture réelle de l’éditeur dans le simulateur.
- `Lumora/Editor/EditState.swift` : paramètres Codable/Sendable, plages et validation.
- `Lumora/Editor/HistoryManager.swift` : commandes et regroupement Undo/Redo.
- `Lumora/Editor/EditorSession.swift` : orchestration observable, annulation et générations.
- `Lumora/Adjustments/TonalResponse.swift` : réponse tonale, saturation, vibrance.
- `Lumora/Rendering/RenderEngine.swift` : rendu Core Image/Metal, RAW et caches réduits.
- `Lumora/Rendering/Histogram.swift` : histogramme échantillonné et compteurs d’écrêtage.
- `Lumora/Library/PhotoDocument.swift` : document versionné et erreurs explicites.
- `Lumora/Library/ImportedPhoto.swift` : transfert de fichiers Photos.
- `Lumora/Persistence/DocumentStore.swift` : originaux immuables et sidecars JSON atomiques.
- `Lumora/UI/LibraryView.swift` : bibliothèque locale, miniatures, réouverture et suppression confirmée.
- `Lumora/UI/EditorView.swift` : écran et panneaux Lumière/Couleur.
- `Lumora/UI/AdjustmentSlider.swift` : curseur, reset, précision et haptique.
- `Lumora/UI/PhotoCanvas.swift` : affichage, zoom, déplacement et comparaison.
- `Lumora/UI/HistogramView.swift` : affichage RVB/luminance.
- `Tests/LumoraCoreTests/EditorTests.swift` : tests des modèles, traitement et persistance.
- `LumoraUITests/EditorUITests.swift` : parcours d’interface dans le simulateur.
- `Lumora.xcodeproj/xcshareddata/xcschemes/Lumora.xcscheme` : scheme partagé avec tests UI.

## Fichiers modifiés

- `Lumora/ContentView.swift` : remplace l’écran initial par l’éditeur.
- `Lumora.xcodeproj/project.pbxproj` : iOS 18+, Swift 6, isolation explicite et cible UI tests.

`MyApp.swift` est conservé. Les modifications préexistantes dans les fichiers utilisateur Xcode ne font pas partie de cette implémentation.

## Deuxième étape : courbes

Voir [les fichiers et détails de l’itération courbes](Curves.md).

## Troisième étape : mélangeur HSL

Voir [les fichiers et détails de l’itération HSL](ColorMixer.md).

## Quatrième étape : color grading

Voir [les fichiers et détails de l’itération grading](ColorGrading.md).

## Cinquième étape : export

- `Lumora/Export/ExportSettings.swift` : formats, profils, dimensions et instantané des paramètres.
- `Lumora/Export/ExportMetadata.swift` : sélection des métadonnées et suppression GPS.
- `Lumora/Export/ExportController.swift` : tâche, progression, annulation et nettoyage.
- `Lumora/UI/ExportView.swift` : options, résultat et partage système.
- `Tests/LumoraCoreTests/ExportTests.swift` : dimensions, codecs, orientation, profils, métadonnées, rendu et annulation.
- `Documentation/Export.md` et `Export-Simulator.png` : documentation et capture.

Le moteur, la session, l’écran principal, le package et les tests UI intègrent ce parcours. Le projet déclare le motif d’ajout à Photos pour l’action système d’enregistrement.

## Sixième étape : effets

- `Lumora/Adjustments/Effects.swift` : modèle, validation et traitements spatiaux Core Image.
- `Tests/LumoraCoreTests/EffectsTests.swift` : migration, historique et vérifications réelles du rendu.
- `Documentation/Effects.md` : algorithmes, ordre du pipeline, validation et limites.
- `Documentation/Effects-Simulator.png` : capture du panneau validé par XCTest.

`EditState`, `EditorSession`, `RenderEngine`, `EditorView`, le parcours UI, le README et la documentation de rendu intègrent cette étape.

## Septième étape : détail

- `Lumora/Adjustments/Detail.swift` : modèles de netteté et débruitage, séparation luminance/chrominance et rendu Core Image.
- `Lumora/UI/DetailView.swift` : panneau structuré et accessible.
- `Tests/LumoraCoreTests/DetailTests.swift` : tests numériques du traitement et de la migration.
- `Documentation/Detail.md` : comportement, pipeline, validation et limites.
- `Documentation/Detail-Simulator.png` : capture du panneau validé par XCTest.

Le modèle d’édition, la session, le moteur, l’écran principal et le parcours UI intègrent également cette étape.

## Huitième étape : optique

- `Lumora/Adjustments/Optics.swift` : modèle, disponibilité du profil et corrections manuelles Core Image.
- `Lumora/UI/OpticsView.swift` : profil RAW, informations EXIF et curseurs accessibles.
- `Tests/LumoraCoreTests/OpticsTests.swift` : métadonnées, migration et vérifications numériques du rendu.
- `Documentation/Optics.md` : comportement, honnêteté des capacités et limites.
- `Documentation/Optics-Simulator.png` : capture du panneau validé par XCTest.

`EditState`, `EditorSession`, `RenderEngine`, l’export, l’écran principal et le parcours UI intègrent cette étape.

## Neuvième étape : géométrie

- `Lumora/Adjustments/Geometry.swift` : modèle, ratios, perspective et transformations Core Image.
- `Lumora/UI/GeometryView.swift` : rotations, miroirs, perspective, format et contrôles de crop accessibles.
- `Tests/LumoraCoreTests/GeometryTests.swift` : migration, dimensions, pixels transformés, opacité et cohérence export.
- `Documentation/Geometry.md` : ordre du pipeline, comportement, validation et limites.
- `Documentation/Geometry-Simulator.png` : capture du panneau validé par XCTest.

`EditState`, `EditorSession`, `RenderEngine`, l’export, l’écran principal et le parcours UI intègrent également cette étape.

## Dixième étape : masques locaux

- `Lumora/Masks/LocalMask.swift` : modèle générique, composantes, formes et réglages locaux.
- `Lumora/Masks/MaskRenderer.swift` : création GPU des mattes, composition et mélange des réglages.
- `Lumora/UI/MasksView.swift` : création, sélection, Ajouter/Soustraire, inversion et contrôles.
- `Tests/LumoraCoreTests/MaskTests.swift` : migration et vérifications numériques des trois formes.
- `Documentation/Masks.md` : modèle, pipeline, validation et limites.
- `Documentation/Masks-Simulator.png` : capture du pinceau et de la soustraction radiale validée par XCTest.

`EditState`, `EditorSession`, `RenderEngine`, `PhotoCanvas`, l’export et le parcours UI intègrent également cette étape.

## Onzième étape : presets

- `Lumora/Presets/Preset.swift` : format versionné, groupes sélectionnés et application partielle.
- `Lumora/Persistence/PresetStore.swift` : bibliothèque atomique, import et export JSON.
- `Lumora/Editor/PresetController.swift` : orchestration observable de la bibliothèque.
- `Lumora/UI/PresetsView.swift` et `PresetFileDocument.swift` : création, renommage, suppression et échange système.
- `Tests/LumoraCoreTests/PresetTests.swift` : application partielle et cycle de stockage réel.
- `Documentation/Presets.md` : format, comportement, validation et limites.
- `Documentation/Presets-Simulator.png` : capture de la bibliothèque validée par XCTest.

`EditorSession`, `EditorView`, le package et le parcours UI intègrent également cette étape.

## Douzième étape : masques intelligents

- `Lumora/Masks/MaskGenerator.swift` : segmentation Sujet/Arrière-plan/Personne, détection Visage avec l’API Swift asynchrone de Vision et encodage PNG en niveaux de gris.
- `Lumora/Masks/SkyMaskGenerator.swift` : matte Ciel locale fondée sur la couleur, la douceur et la continuité depuis le bord supérieur.
- `Lumora/Masks/MaskBitmapSource.swift` : rasterisation sRGB bornée partagée par les analyses locales.
- `Lumora/Masks/SkinMaskGenerator.swift` : calibration chromatique depuis les visages et matte Peau progressive.
- `Lumora/Masks/LocalMask.swift` et `MaskRenderer.swift` : modèle raster borné, sidecar Codable et réutilisation de la matte dans le rendu local.
- `Lumora/UI/MasksView.swift` et `PhotoCanvas.swift` : création, progression, Ajouter/Soustraire et overlay de la matte détectée.
- `Tests/LumoraCoreTests/MaskTests.swift` : sérialisation, mise à l’échelle et application locale d’une matte générée.
- `Documentation/SmartMasks.md` : fonctionnement, persistance, validation et limites du runtime Vision.

`EditorSession`, `EditorView` et le parcours UI intègrent également cette étape.

## Treizième étape : pile de modifications

- `Lumora/Masks/LocalMask.swift` : `AdjustmentLayer` et jeu complet de réglages par calque, avec migration des anciens champs locaux.
- `Lumora/Editor/EditorSession.swift` : sélection du calque actif et routage des panneaux photographiques.
- `Lumora/Rendering/RenderEngine.swift` : développement et mélange séquentiels de chaque niveau masqué.
- `Lumora/UI/MasksView.swift` et `EditorView.swift` : premier calque Photo entière, pile sélectionnable et indication du calque actif.
- `Tests/LumoraCoreTests/MaskTests.swift` : rendu numérique d’une courbe locale et migration du sidecar.
- `Documentation/AdjustmentLayers.md` : modèle, ordre du pipeline et extensions prévues.
- `Documentation/AdjustmentLayers-Simulator.png` : pile Photo entière/Pinceau, composition Ajouter/Soustraire et masque superposé, validés par XCTest.

## Quatorzième étape : gestion des calques

- `Lumora/Masks/LocalMask.swift` : visibilité et opacité migrables avec valeurs compatibles pour les anciens sidecars.
- `Lumora/Editor/EditorSession.swift` : renommage, activation, opacité et réordonnancement intégrés à Undo/Redo et à la persistance.
- `Lumora/Masks/MaskRenderer.swift` et `Rendering/RenderEngine.swift` : calques masqués ignorés lorsqu’ils sont cachés et matte modulée par l’opacité.
- `Lumora/UI/MasksView.swift` : commandes de visibilité, renommage, opacité et ordre d’application.
- `Tests/LumoraCoreTests/MaskTests.swift` et `LumoraUITests/EditorUITests.swift` : migration, rendu numérique et parcours persistant complet.

## Quinzième étape : édition directe des masques

- `Lumora/UI/PhotoCanvas.swift` : poignées normalisées du centre, de la direction et des rayons, avec aperçu interactif.
- `Lumora/Editor/EditorSession.swift` : transformation, opération, réordonnancement et suppression des composantes avec Undo/Redo.
- `Lumora/UI/MasksView.swift` : sélecteur Ajouter/Soustraire et commandes d’ordre/suppression de la composante active.
- `LumoraUITests/EditorUITests.swift` : geste réel sur une poignée, Undo/Redo et cycle complet de gestion des composantes.
- `Documentation/MaskEditing.md` : interactions, coordonnées, accessibilité et limites.

## Seizième étape : contour progressif direct

- `Lumora/UI/PhotoCanvas.swift` : poignée orange et guide visuel pour le contour progressif des gradients radial et linéaire.
- `LumoraUITests/EditorUITests.swift` : geste direct, Undo/Redo et persistance après relance.
- `Documentation/MaskEditing.md` : géométrie et comportement des nouvelles poignées.

## Dix-septième étape : gomme du pinceau

- `Lumora/Masks/LocalMask.swift` : traits d’effacement persistants et migration des anciens pinceaux.
- `Lumora/Masks/MaskRenderer.swift` : retrait progressif des traits dans la matte Core Image.
- `Lumora/Editor/EditorSession.swift` : mode Peindre/Effacer avec une transaction d’historique par trait.
- `Lumora/UI/MasksView.swift` et `Lumora/UI/PhotoCanvas.swift` : sélecteur de mode et diamètre rouge/cyan pendant le geste.
- `Tests/LumoraCoreTests/MaskTests.swift` et `LumoraUITests/EditorUITests.swift` : rendu numérique, sérialisation et parcours tactile.

## Dix-huitième étape : masque Personne

- `Lumora/Masks/LocalMask.swift` : nouveau type intelligent Personne, sérialisable avec son titre et son symbole.
- `Lumora/Masks/MaskGenerator.swift` : segmentation de toutes les silhouettes via `GeneratePersonInstanceMaskRequest` et erreur dédiée en l’absence de personne.
- `Lumora/UI/MasksView.swift` : Personne apparaît automatiquement dans les menus Nouveau, Ajouter et Soustraire.
- `Documentation/SmartMasks.md` : distinction entre premier plan générique et silhouettes humaines.

## Dix-neuvième étape : masque Visage

- `Lumora/Masks/LocalMask.swift` : nouveau type intelligent Visage, sérialisable et disponible dans les opérations de composantes.
- `Lumora/Masks/MaskGenerator.swift` : détection de tous les visages, conversion en ellipses progressives et erreur dédiée en l’absence de visage.
- `LumoraUITests/EditorUITests.swift` : présence de Visage vérifiée dans le menu des masques intelligents.
- `Documentation/SmartMasks.md` : distinction explicite entre détection rectangulaire, matte elliptique et segmentation sémantique.

## Vingtième étape : masque Ciel

- `Lumora/Masks/SkyMaskGenerator.swift` : analyse à résolution bornée, score progressif et croissance de région sans modèle externe.
- `Lumora/Masks/MaskGenerator.swift` : intégration asynchrone, erreur dédiée et stockage dans le format commun des mattes.
- `Tests/LumoraCoreTests/MaskTests.swift` : mire paysage synthétique vérifiant la sélection du ciel bleu et le rejet du sol.
- `LumoraUITests/EditorUITests.swift` : présence de Ciel vérifiée dans le menu intelligent.

## Vingt-et-unième étape : masque Peau

- `Lumora/Masks/MaskBitmapSource.swift` : factorisation de la lecture RGBA et de la création des mattes grises.
- `Lumora/Masks/SkinMaskGenerator.swift` : échantillonnage YCbCr propre à la photographie et sélection progressive des pixels compatibles.
- `Lumora/Masks/MaskGenerator.swift` : détection préalable des visages, adoucissement Core Image et erreur dédiée.
- `Tests/LumoraCoreTests/MaskTests.swift` : mire synthétique vérifiant visage, seconde zone correspondante et rejet du fond.
- `LumoraUITests/EditorUITests.swift` : présence de Peau vérifiée dans le menu intelligent.

## Vingt-deuxième étape : redressement automatique

- `Lumora/Adjustments/GeometryAnalyzer.swift` : détection asynchrone de l’horizon avec Vision et rejet des observations peu fiables.
- `Lumora/Adjustments/Geometry.swift` : conversion du repère Vision vers le paramètre Redresser et borne à ±15°.
- `Lumora/Editor/EditorSession.swift` : application non destructive, contrôle du document courant, persistance et Undo/Redo.
- `Lumora/UI/GeometryView.swift` : action Horizon auto avec progression et accessibilité.
- `Tests/LumoraCoreTests/GeometryTests.swift` : conversion, signe, bornes et valeur non finie.
- `LumoraUITests/EditorUITests.swift` : présence de l’action vérifiée dans le panneau Géométrie.

## Vingt-troisième étape : perspective automatique

- `Lumora/Adjustments/GeometryAnalyzer.swift` : détection asynchrone de quadrilatères avec Vision et erreur dédiée lorsqu’aucune structure n’est exploitable.
- `Lumora/Adjustments/Geometry.swift` : pondération par surface et confiance, conversion des bords opposés vers les deux axes de perspective et bornes.
- `Lumora/Editor/EditorSession.swift` : application résiduelle des deux axes, persistance et transaction Undo/Redo unique.
- `Lumora/UI/GeometryView.swift` : action Perspective auto partageant l’état de progression de l’analyse géométrique.
- `Tests/LumoraCoreTests/GeometryTests.swift` : signe, pondération, rejet des formes faibles et saturation des valeurs.
- `LumoraUITests/EditorUITests.swift` : présence des deux actions automatiques vérifiée dans le panneau Géométrie.

## Vingt-quatrième étape : poignées directes de géométrie

- `Lumora/Adjustments/Geometry.swift` : conversions pures entre coordonnées normalisées et perspective, position ou zoom du recadrage.
- `Lumora/UI/PhotoCanvas.swift` : quadrilatère orange, quatre coins de perspective, poignée centrale de position et poignée cyan de zoom.
- `Lumora/UI/EditorView.swift` : connexion des gestes au même état et aux mêmes transactions que les curseurs.
- `Tests/LumoraCoreTests/GeometryTests.swift` : signes, échelles et bornes des conversions directes.
- `LumoraUITests/EditorUITests.swift` : présence accessible et capture des poignées sur le simulateur.

## Vingt-cinquième étape : bibliothèque locale

- `Lumora/Library/PhotoDocument.swift` : entrée de bibliothèque associant document et URL privée.
- `Lumora/Persistence/DocumentStore.swift` : liste reconstruite depuis les sidecars, chargement par identifiant, tri et suppression protégée contre les écritures tardives.
- `Lumora/Editor/EditorSession.swift` : chargement de la liste, validation avant changement de document et nettoyage du document courant supprimé.
- `Lumora/UI/LibraryView.swift` : miniatures ImageIO, date, état Ouvert, actualisation et confirmation destructive.
- `Tests/LumoraCoreTests/EditorTests.swift` : tri, rechargement, suppression, nettoyage de la sélection et rejet d’une sauvegarde postérieure.
- `LumoraUITests/EditorUITests.swift` : import, ouverture de la bibliothèque et capture de la liste réelle.
- `Documentation/Library.md` : stockage, comportement, validation et limites.

## Vingt-sixième étape : recherche, tri et favoris

- `Lumora/Library/PhotoDocument.swift` : requête pure par nom et tris stables par date ou nom.
- `Lumora/Persistence/DocumentStore.swift` : marqueur de favori indépendant du sidecar de réglages.
- `Lumora/Editor/EditorSession.swift` : chargement et basculement persistants des favoris.
- `Lumora/UI/LibraryView.swift` : champ de recherche, menu de tri, étoile accessible et état vide filtré.
- `Tests/LumoraCoreTests/EditorTests.swift` : recherche accentuée, trois ordres et persistance du marqueur.
- `LumoraUITests/EditorUITests.swift` : basculement réel du favori après import.

## Vingt-septième étape : dossiers de bibliothèque

- `Lumora/Library/PhotoDocument.swift` : dossier identifié et portée Toutes/Favoris/Dossier pour la requête de bibliothèque.
- `Lumora/Persistence/DocumentStore.swift` : catalogue atomique, affectation par document et suppression non destructive.
- `Lumora/Editor/EditorSession.swift` : création, suppression et affectation reflétées immédiatement dans la liste observable.
- `Lumora/UI/LibraryView.swift` : sélecteur de portée, gestion des dossiers, comptage et déplacement depuis le menu d’une photo.
- `Tests/LumoraCoreTests/EditorTests.swift` : persistance, tri des dossiers, affectation, filtrage et conservation des photos.
- `LumoraUITests/EditorUITests.swift` : création, affectation et filtre validés sur simulateur.

## Vingt-huitième étape : overlay de masque fidèle au zoom

- `Lumora/Masks/MaskRenderer.swift` : conversion de la matte composée en overlay rouge dont l’alpha conserve les transitions.
- `Lumora/UI/PhotoCanvas.swift` : rendu asynchrone borné, transformation commune photo/matte et coordonnées de pinceau corrigées par le zoom.
- `Tests/LumoraCoreTests/MaskTests.swift` : couleur, transparence intérieure/extérieure et contour progressif vérifiés numériquement.
- `LumoraUITests/EditorUITests.swift` : poignée déplacée avec un zoom ×2 puis contour progressif encore éditable.

## Vingt-neuvième étape : étiquettes personnalisées

- `Lumora/Library/PhotoDocument.swift` : modèle d’étiquette, affectations multiples et portée Étiquette pour la requête de bibliothèque.
- `Lumora/Persistence/DocumentStore.swift` : catalogue racine atomique, liste d’étiquettes par document et suppression non destructive.
- `Lumora/Editor/EditorSession.swift` : chargement, création, suppression et basculement des étiquettes dans l’état observable.
- `Lumora/UI/LibraryView.swift` : gestion, comptage, affectation multiple, filtre dédié et symbole de portée dynamique.
- `Tests/LumoraCoreTests/EditorTests.swift` : affectations multiples, persistance, filtrage et conservation des photos à la suppression.
- `LumoraUITests/EditorUITests.swift` : création et affectation d’un dossier et d’une étiquette, puis validation des deux filtres sur simulateur.
- `Documentation/Library-Tags-Simulator.png` : résultat visuel du filtre Étiquette avec dossier et favori conservés.

## Trentième étape : sélection multiple et opérations groupées

- `Lumora/Persistence/DocumentStore.swift` : validation préalable et opérations groupées pour favoris, dossier, étiquette et suppression.
- `Lumora/Editor/EditorSession.swift` : synchronisation immédiate de tous les documents concernés et nettoyage sûr du document ouvert.
- `Lumora/UI/LibraryView.swift` : mode de sélection, Tout/Aucun, compteur et barre d’actions groupées.
- `Tests/LumoraCoreTests/EditorTests.swift` : cycle groupé complet sur deux documents réels.
- `LumoraUITests/EditorUITests.swift` : sélection tactile de deux lignes et vérification de l’ajout commun aux favoris.
- `Documentation/Library-Batch-Selection-Simulator.png` : deux photos cochées et barre d’actions sur simulateur.

## Trente-et-unième étape : interface compacte et colorimétrie unifiée

- `Lumora/UI/AdjustmentSlider.swift` : curseurs sur une ligne et mode de concentration qui estompe les autres contrôles pendant le geste.
- `Lumora/UI/EditorView.swift` : hauteur fixe du panneau d’inspection, donc hauteur stable de l’aperçu, et entrée Colorimétrie unique.
- `Lumora/UI/ColorToolsView.swift` : sous-onglets Mélangeur et Grading dans un même panneau.
- `Lumora/UI/ColorGradingView.swift` : sélecteur Ombres/Tons moyens/Hautes lumières et roue chromatique unique.
- `LumoraUITests/EditorUITests.swift` : vérification de la hauteur de l’aperçu, de la compacité et de la structure du panneau.
- `Documentation/Unified-Color-Interface-Simulator.png` : résultat final validé sur simulateur.

## Trente-deuxième étape : gestes de l’aperçu

- `Lumora/UI/PhotoCanvas.swift` : double toucher ramenant systématiquement le zoom et le déplacement au cadrage initial ; appui long conservé pour afficher temporairement l’original.
- `Lumora/UI/EditorView.swift` : suppression du bouton œil devenu redondant dans la barre des outils.
- `LumoraUITests/EditorUITests.swift` : exercice de l’appui long et vérification de l’absence du bouton de comparaison.

## Trente-troisième étape : retour fiable des contrôles

- `Lumora/UI/AdjustmentSlider.swift` : fin de réglage garantie par le geste de glissement, même lorsqu’un rerendu remplace une partie de l’interface.
- `Lumora/UI/DetailView.swift` : contrôles secondaires désactivés et expliqués tant que Gain, Luminance ou Couleur ne les active pas.
- `LumoraUITests/EditorUITests.swift` : comparaison des pixels avant/après Effets et Détail, puis vérification du retour de la barre après une exposition locale de masque.

## Trente-quatrième étape : overlay persistant du masque sélectionné

- `Lumora/UI/EditorView.swift` : visibilité de la matte rouge liée au masque sélectionné dans tous les panneaux et masquage temporaire pendant les curseurs photographiques.
- `Lumora/UI/PhotoCanvas.swift` : séparation entre affichage de l’overlay et autorisation de peindre ou de transformer le masque.
- `Tests/LumoraCoreTests/MaskTests.swift` : overlay rouge vérifié pour les formes radial, linéaire, pinceau et la matte intelligente Peau.
- `LumoraUITests/EditorUITests.swift` : overlay contrôlé dans Lumière après création et modification d’un masque radial, avec capture du résultat.

## Trente-cinquième étape : sélection rapide du calque

- `Lumora/UI/EditorView.swift` : le nom du calque sous l’aperçu devient un menu listant Photo entière et tous les masques, avec sélection et visibilité.
- `LumoraUITests/EditorUITests.swift` : passage de Radial 1 à Photo entière puis retour au masque depuis ce menu.

## Trente-sixième étape : masque Yeux

- `Lumora/Masks/LocalMask.swift` : type intelligent Yeux sérialisable, nommé et présenté avec son icône.
- `Lumora/Masks/MaskGenerator.swift` : détection des repères faciaux Vision et extraction des contours gauche/droit.
- `Lumora/Masks/EyeMaskGenerator.swift` : composition de deux ellipses progressives par visage dans une matte huit bits.
- `Tests/LumoraCoreTests/MaskTests.swift` : séparation des deux yeux, centre opaque, contour progressif et sérialisation.
- `LumoraUITests/EditorUITests.swift` : présence de Yeux vérifiée dans le menu intelligent.
