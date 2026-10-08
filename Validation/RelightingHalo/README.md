# Correction du faux contour en Éclairage

Point de sauvegarde avant correction : `8843d08`, sur `main` dans la cible principale
`/Volumes/XTRA/Dev/Lumora`, schéma Lumora, bundle `com.guilleme.Lumora`.
Les modifications de version/build et les résultats de validation préexistants
restent hors de ce commit consacré à la correction du halo.

## Cause et correction

Le renderer ne déplace pas les pixels source. La carte DA2 lissée transforme parfois
la rupture sujet/fond en pente. Sa dérivée centrale produit alors une fausse normale
et une bande de lumière qui ressemble à un double contour.

Le calcul partagé estime maintenant cinq pentes adjacentes. Sur une surface régulière,
il garde la dérivée centrale ; si elles divergent, il utilise une estimation médiane
et rejette les résidus d'une forte transition de profondeur. Les distances d'analyse
conservent la référence 960 px pour l'aperçu et l'export. Même correction dans le repli
DA2 du mode MoGe ; les normales MoGe valides ne sont pas modifiées.

Aucun paramètre, preset, UI de réglage, modèle, document ou règle Undo modifié.
Le rendu change intentionnellement dans les zones où la profondeur crée ce faux relief.
La carte de profondeur et Depth Lens ne sont pas modifiés. Ce n'est pas une segmentation
haute résolution du sujet et cela ne garantit pas l'absence de toute frange sur tous les sujets.

## Vérifications locales

18 vérifications ciblées réussies (`regression.log`), exécutées avec les sources réelles :
plan régulier inchangé (écart FP32 0), conservation d'alpha et des hautes lumières HDR,
décodage/sérialisation, lumière originale, direction des normales, peau/yeux, ombres,
échelle/origine et quatre photos du corpus de normales.

Sur une rupture de profondeur lissée synthétique : écart total au rendu sans faux bevel
488,4417 avant, 1,3911 après, soit une réduction de 99,7 %. Cette mesure concerne ce
cas contrôlé, pas une métrique de qualité sur toute photographie.

Photo JPEG fournie : inférence DA2 issue du chemin de production, comparaisons avec
le renderer figé au commit `1104031`, même source, profondeur et réglages Studio
(cible 0,49/0,49), tailles 640/1024/2048. Inspection visuelle des bras et cheveux.
Les photos privées et rendus sont ignorés par Git ; `comparaison.png` présente
l'agrandissement à partir des deux rendus 1024 px. Ce sont des rendus de diagnostic,
pas des captures de l'interface ni le document exact actuellement ouvert sur l'iPhone.

Temps Mac après chauffe, 10 rendus Core Image : à 2048 px, 5,44 ms avant, 6,91 ms après.
Ces temps ne mesurent pas l'inférence ni une performance d'iPhone.

La suite globale `swift test` conserve ses blocages préexistants de disponibilité
macOS 15 et de tests DepthLighting obsolètes ; seule la validation ciblée est déclarée passée.

## Appareil et compilation

Compilations Debug et Release de la cible principale : réussies.
L'iPhone 15 Pro s'est reconnecté après un premier échec de préparation Xcode.
La sonde Debug isolée `--lighting-halo-probe` a rendu la photo JPEG fournie :
source, Studio puis Relief 0, avec un export Studio PNG **2048 × 1365**.
Sonde terminée, aucun avertissement mémoire, round-trip de l'état réussi.
Une seule inférence DA2, aucune inférence MoGe (mode Studio). Première activation
722 ms, rendu suivant Relief 0 5,88 ms, export 153 ms. Mémoire après export ~204 Mo.
Ces mesures comprennent le pipeline de production ; elles ne mesurent pas seulement
le shader ni une comparaison avant/après de vitesse sur appareil.
Rapport : `device-report.json`. Les rendus et la photo privée restent ignorés par Git.
Le document actuellement ouvert par l'utilisateur n'a pas été modifié ; pas de nouveau
parcours de gestes UI nécessaire pour ce changement de renderer.

Après le diagnostic, la version Release corrigée a été réinstallée sur le même
bundle et rouverte normalement, sans argument de validation.
