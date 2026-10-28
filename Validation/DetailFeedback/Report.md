# Détail, indicateurs et qualité du recadrage — 28 octobre 2026

Cible principale : `/Volumes/XTRA/Dev/Lumora/Lumora.xcodeproj`, branche `main`, schéma `Lumora`, bundle `com.guilleme.Lumora`. Les changements locaux préexistants (notamment le suivi des masques lors des transformations géométriques) sont conservés. Aucun commit n'est créé par cette passe.

## Modifications

- Flou gaussien dans Effets, sur la photo entière ou sur le masque sélectionné. Échelle 0–100 ; rayon proportionnel à la taille de l'image ; zéro conserve le rendu existant. Réutilise les instructions Détail des calques, leur sauvegarde, le mélange masqué et Undo/Redo. Les anciens documents sans cette clé conservent un flou nul.
- Les réglages de réduction de bruit sont intitulés « Bruit L » et « Bruit C ». Chaque groupe et ses réglages secondaires sont entourés d'un trait fin ; la molette commune conserve son comportement.
- Point turquoise sur les onglets qui contiennent des réglages différents des défauts, y compris dans les masques. L'indication est calculée à partir de l'état sauvegardé, sans état visuel indépendant. Les réglages conservés dans un outil désactivé restent signalés.
- Résumé permanent des réglages dans la liste des masques. Le résumé complet du masque sélectionné est également affiché, sans délai de disparition. L'information est accessible à VoiceOver.
- Aide Effets complétée pour le flou ; libellés français et anglais.

## Vérification de Géométrie

Le fichier original reste intact et le rendu repart de l'original, pas d'une succession d'exports. Deux problèmes de réduction prématurée ont été corrigés :

1. **Aperçu d'un cadrage serré.** L'ancien aperçu réduisait la source à 2048 px avant de recadrer. Sur une mire de 3200 × 2400, un cadrage à 80 conservait seulement **737 px** de largeur d'aperçu pour **1151 px** disponibles dans la zone native. Le nouvel aperçu donne **1151 × 863**, soit les dimensions disponibles de ce cadrage. Le décodage HQ utilise des paliers et est plafonné à 4096 px côté source pour les retouches légères ; il conserve le budget de 2048 px avec Beauté, Éclairage/Depth Lens, Cinematic Glow, effets créatifs, flou ou une pile de plus de trois masques, pour contenir les allocations GPU et modèles.  Le résultat affiché reste limité à la taille de prévisualisation. Les aperçus interactifs gardent leur budget rapide.
2. **Export RAW avec limite de taille.** Le RAW était lui aussi réduit avant la géométrie, ce qui réduisait à nouveau la zone recadrée. L'export décode désormais la source native et redimensionne après la géométrie. Un CR2 réel, recadré en 4:5 à 60, demandé avec un grand côté de 1600 px, donne **1279 × 1600** (arrondi de cadrage à un pixel).

Un test compare les pixels d'un export PNG recadré sans changement d'échelle avec la même zone d'un export natif complet : erreur maximale autorisée de 1/255 par composante. Il vérifie également que les octets du fichier source restent identiques. Le recadrage réduit naturellement le nombre de pixels disponibles ; redressement et perspective demandent toujours une interpolation.

## Tests de rendu et de données

28 tests ciblés réussis : flou local limité à la zone couverte, migration, sauvegarde, bornage, Undo/Redo, indicateurs, résumé, réduction de bruit existante, netteté, géométrie, pincement/déplacement calculés, alignement des masques et concordance aperçu/export. Les mesures précédant la correction sont conservées dans `geometry-before.log`, les mesures corrigées dans `geometry-quality.log`, les résultats finaux dans `core-tests.log`.

Le manifeste de validation temporaire `.build/FeedbackValidation/Package.swift` réutilise les sources réelles et cible macOS 15 pour les API Metal déjà employées par le projet ; le manifeste de production n'est pas changé. La suite ciblée évite les tests historiques sans rapport dont les initialiseurs ne correspondent plus aux renderers actuels.

## Tests d’interface

- `DetailFeedbackUITests` réussi sur iPhone 18 Pro Max / iOS 27.0 : défilement des paramètres, libellés Bruit L/C, saisie numérique du flou, indicateur d’onglet, Undo/Redo, reset, création d’un masque radial, flou local, résumé persistant après navigation et attente, reset local. Captures dans `Screenshots`, planche dans `Preview.png`. Résultat final : `/tmp/lumora-detail-feedback-ui-v5.xcresult`.
- `GeometryCropUITests` réussi : formats Instagram/TikTok, pincement, déplacement, une opération Undo par geste, bascule Cadrage/Ajustements, paysage et inversion du côté des contrôles. Résultat : `/tmp/lumora-detail-feedback-ui-v2.xcresult` (le test Détail de cette passe a ensuite été corrigé côté automatisation et validé séparément en v5).
- Compilation de la cible principale réussie. Les reprises du test Détail corrigent les requêtes XCTest : doublons d’accessibilité du bouton d’alerte, éléments hors écran et identifiants supprimés par le pont UIKit des menus contextuels. Elles ne masquent pas un échec de rendu ou de réglage.

## Limites

Rendu testé sur le Mac et interactions sur simulateur iPhone. Après le signalement du plantage, le démarrage et la mémoire ont été contrôlés sur l’iPhone physique (voir le complément ci-dessous). Les gestes automatisés restent validés sur simulateur. Les images et paramètres exacts du retour de l'utilisatrice n'étant pas fournis, les mesures utilisent une mire synthétique, un portrait du corpus et un CR2 local.


## Correction du plantage au lancement et déplacement dans Effets

Le document restauré au premier plantage porte un flou nul sur la photo et sur ses quatre masques : le filtre ne s’exécute pas. Il combine un CR2, Beauté, corrections manuelles, Éclairage avec surfaces détaillées et Cinematic Glow. Sur l’iPhone 15 Pro, le lancement instrumenté avec le nouvel aperçu de source 2048 × 3072 se termine par le signal 9 après l’estimation des normales. Le même document a terminé son rendu avec le budget source précédent (1366 × 2048). Les journaux A/B sont conservés dans `CrashFix` ; aucun original ni fichier d’état personnel n’est ajouté au dépôt.

Le budget de compensation du cadrage tient désormais compte des traitements lourds. Les sources surdimensionnées du cache sont relâchées quand ce budget diminue. Les paramètres enregistrés et le rendu d’export ne sont pas désactivés ou modifiés par cette limite d’aperçu. Un test de régression couvre notamment le cas Beauté + Éclairage à normales, le flou local et le retour au budget des retouches légères.

À la demande de l’utilisateur, le contrôle Flou est déplacé dans Effets. Son stockage spatial existant et son moteur sont conservés pour ne pas perdre les valeurs déjà enregistrées. Le point d’onglet correspond maintenant à Effets, et aucun point Détail n’est créé par le seul flou. L’aide suit le même déplacement.

Compilation iPhone et installation de la correction réussies. Le lancement avec le budget de production corrigé a achevé le rendu ; l’application est restée active pendant les manipulations sur l’appareil. Les diagnostics de mémoire sont uniquement disponibles en DEBUG avec l’argument explicite `--render-memory-probe`.

Validation finale du déplacement : `DetailFeedbackUITests` réussi dans `/tmp/lumora-effects-blur-ui.xcresult` : absence de Flou dans Détail, présence et saisie dans Effets, flou global/local, indicateur Effets, Undo/Redo et reset. Les captures et la planche sont actualisées.
