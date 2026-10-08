# Éclairage — phases inspirées de l’étude ImageFlow

Travail dans `/Volumes/XTRA/Dev/Lumora`, branche `main`, schéma `Lumora`, bundle
`com.guilleme.Lumora` (1.2.1, build 20 préexistant). Aucun code d’ImageFlow repris.
Les modifications de version et les autres résultats locaux préexistants ont été conservés.

## Intégration

- Lumière originale 0–100 %, défaut 100 : réduit le signal existant avant l’ajout
  de lumière, y compris avec intensité 0. Ce n’est pas une séparation albédo/éclairage.
- Surfaces détaillées : normales MoGe-2 ViT-S, FP16, inférence locale Core ML.
  Entrée 512×768 RGB ; ajustement proportionnel et bord étendu, recadrage de la sortie.
  Normales non valides : repli sur les dérivées DA2. Depth Lens conserve son modèle.
- Modelé du portrait 0–100 %, défaut 0 : masques peau/yeux de l’analyse Beauty
  existante, faible réponse spéculaire de la peau et atténuation sur les yeux.
  Aucun visage, reflet d’œil ou matériau de cheveux généré.
- Ombres portées 0–100 %, défaut 0 : huit échantillons du rayon dans la profondeur
  visible ; atténuation de la seule source ajoutée. Douceur élargit la transition.
  Il s’agit d’une approximation dans l’espace de l’image, sans géométrie cachée.
- Les contrôles avancés sont enregistrés, validés et inclus dans Undo/Redo.
  Les documents sans ces champs conservent 100/false/0/0.
- Les preset values existantes sont conservées. Température et les deux poignées
  gardent leur interface. Le repère élevé éclaire les normales orientées vers le
  haut dans le nouveau mode ; la branche historique garde sa convention et son rendu.
- Une analyse de normales par source/géométrie/optique, aucune par mouvement de
  molette. L’analyse de visage partage le cache Beauty. Les mêmes cartes et le même
  graphe Core Image sont utilisés en aperçu et export.
- Modèle embarqué : environ 72 Mo supplémentaires ; licences et provenance incluses
  dans `Lumora/RelightingResources`, attribution ajoutée à l’aide FR/EN.

## Validation locale

`./Validation/RelightingPhases/run_local.sh` compile directement les sources réelles
et un renderer historique figé au commit `1104031`. Le script ne modifie aucun document.
Il vérifie : compatibilité du renderer historique, décodage des anciens documents,
réduction de la lumière sans lampe et maintien de l’alpha, sérialisation, calcul fini,
direction et hauteur des normales, protection des yeux, ombres sur un obstacle
analytique, cohérence d’échelle/origine et maintien des hautes lumières HDR.

Les options neutres utilisent désormais un kernel historique conservé séparément,
identique à celui de `1104031`. Écart FP32 ancien/nouveau dans le validateur : 0.
La première version avec kernel commun avait un écart de 3,87×10⁻⁷ ; elle a été
remplacée pour éviter toute variation d’arrondi sur les anciens réglages.
Écart d’échelle/origine sur surface uniforme : 4,67×10⁻⁴.
Normales calculées et inspectées sur portrait, cheveux clairs, lunettes et paysage.
Les images de diagnostic utilisent une profondeur uniforme ; ce ne sont pas les
rendus de production DA2. Les rendus de production sont dans `Device/`.

La commande globale `swift test` est bloquée par la disponibilité macOS 15 de
`MTLCompileOptions.mathMode` dans des fichiers préexistants et la cible package
macOS 14. Le validateur ciblé et la vraie cible iOS évitent cette incompatibilité ;
la suite globale n’est pas déclarée passée.

## Mesures sur appareil

iPhone 15 Pro connecté `00008130-001144C10162001C`, iOS 27.0.1, cible principale
Debug. Sonde `--relighting-phases-probe`, uniquement dans le build Debug,
dossier isolé Documents/RelightingPhasesInputs et sortie RelightingPhasesProbe.
Aucun document de l’utilisateur ouvert ou modifié par la sonde.

Deux portraits, sept étapes par photo, exports PNG 768×1152 et round-trip de l’état :
terminés, aucun avertissement mémoire.

- Variante CPU/GPU : mémoire après rendu ~940 Mo ; non retenue.
- Variante `.all` : ~500 Mo après rendu. Première activation froide : 9,88 s
  (chargement/compilation compris), deuxième photo : 361 ms.
- Analyse portrait initiale : quelques centaines de ms, puis cache.
- Réglages suivants : 6,58 / 6,62 ms, compteurs d’inférence inchangés.
- Exports : 38,5 / 49,2 ms ; une seule inférence de normales par photo.

Sources des mesures : `device-cpu-gpu-report.json`, `device-all-report.json`, `device-final-report.json`.
Dernière passe après correction de la hauteur de source : normales 371 / 335 ms,
réglages 6,53 / 6,46 ms, mémoire après export 514 / 500 Mo, aucune alerte mémoire.
Ces mesures portent sur ce modèle d’iPhone et sur deux photos modestes, pas sur
un iPhone plus ancien, de gros RAW ou un export 48 MP.

## Limites et suite

Pas d’équivalence visuelle garantie avec ImageFlow, pas de suppression des ombres
initiales, pas d’albédo, pas de segmentation cheveux, pas de vrais objets occultés,
pas de multi-source ni de ray tracing 3D. Une validation photographique plus large
reste nécessaire pour recommander systématiquement les nouvelles options.

## Interface sur appareil

Parcours portrait réussi (67,97 s, zéro échec) dans la cible principale : activation,
ouverture Avancé, Surfaces détaillées, sélection et défilement des paramètres,
saisie 75/70/70, molette relative, reset actif, Undo/Redo d’un geste et zoom/pan.
Le test cible le bouton UIKit intérieur de la boîte de dialogue, car XCTest expose
aussi une enveloppe portant le même identifiant. La fermeture numérique est
explicitement demandée avant la mise à jour du renderer.

Captures portrait `Screenshots/01-Legacy-default.png` à `05-Advanced-after-reset.png`.
Ces captures utilisent la même photo du corpus, mais les réglages changent
volontairement pour illustrer chaque phase.

Builds Debug et Release de Lumora : réussis. Pas de nouvelle archive ou commit.

Paysage sur le même iPhone : test dédié réussi (26,1 s), orientation initiale
portrait explicite puis rotation stabilisée ; canvas et commande d’inversion
accessibles. Captures `06-Landscape.png` et `07-Landscape-inverted.png`.
Les captures produites par le rectangle de l’application étaient incomplètes en
paysage avec cette version de XCTest. Une capture de l’écran complet est utilisée.
Les originaux XCTest restent dans les dossiers UI de validation.

Dernière compilation Debug et Release avec kernel historique séparé : réussie.
Release installée sur l’iPhone (bundle/version inchangés), puis lancement normal
sans argument de validation. Le test paysage avec capture plein écran réussit
aussi ; ses PNG sont les captures livrées, sans transformation des pixels.

- [Avant, réponse historique](Screenshots/01-Legacy-default.png)
- [Surfaces détaillées](Screenshots/02-Surface-normals.png)
- [Lumière originale à 75 %](Screenshots/03-Original-light75.png)
- [Modelé et ombres](Screenshots/04-Portrait-and-shadows.png)
- [Reset](Screenshots/05-Advanced-after-reset.png)
- [Paysage](Screenshots/06-Landscape.png)
- [Paysage inversé](Screenshots/07-Landscape-inverted.png)

## Correctif ultérieur du halo

Les résultats de compatibilité pixel identique ci-dessus décrivent le point de
sauvegarde `8843d08`. La passe suivante corrige volontairement le faux relief aux
ruptures sujet/fond ; voir `../RelightingHalo/README.md`. Le validateur conserve
l'ancien renderer comme référence et vérifie désormais l'identité sur la surface
régulière, puis la réduction du faux contour sur une rupture de profondeur lissée.
