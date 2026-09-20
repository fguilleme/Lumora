# Pipeline de rendu

1. **Import immuable** : copie privée des octets originaux. Les métadonnées restent dans ce fichier, jamais écrasé. Le JSON ne contient que le développement et la référence relative.
2. **Décodage/orientation** : ImageIO produit directement une miniature orientée pour les fichiers développés. CIRAWFilter utilise `scaleFactor` pour les RAW et applique son développement par défaut/as-shot. Les possibilités réelles dépendent des décodeurs système et du boîtier.
3. **Optique** : correction constructeur pendant le décodage RAW lorsqu’elle est disponible et activée, puis corrections manuelles de distorsion, aberration chromatique et vignetage. Voir [Optique](Optics.md).
4. **Gestion couleur** : ImageIO conserve les profils des miniatures ; CIImage en tient compte. Le contexte travaille en extended linear sRGB. Les RAW réduits sont matérialisés en RGBA half-float linéaire afin de préserver davantage la latitude que dans un cache 8 bits.
5. **Balance des blancs** : adaptation relative à l’image décodée via CITemperatureAndTint, zéro = identité. L’interface affiche un décalage relatif, **pas une température absolue mesurée en kelvins**. Les contrôles natifs de développement RAW ne sont pas encore exposés ; aucun doublon exposition/contraste/netteté utilisateur n’est injecté dans le décodeur.
6. **Exposition** : CIExposureAdjust en lumière linéaire.
7. **Ton, courbes et couleur** : CIColorCubeWithColorSpace avec espace sRGB explicite. Des transitions smoothstep sélectionnent les ombres, hautes lumières et extrémités ; le contraste utilise une courbe en S. Les changements tonals déplacent la luminance sans affecter artificiellement chaque canal de manière indépendante. Les courbes PCHIP RVB puis par canal s’appliquent après le ton, via tables précalculées. La saturation est globale ; la vibrance diminue selon la saturation existante et protège progressivement le secteur orangé. C’est une heuristique chromatique, pas un détecteur de peau. Le mélangeur HSL sélectionne ensuite huit plages de teinte avec des transitions circulaires smoothstep ; les gris exacts sont préservés. Le grading intervient ensuite avec trois zones tonales : contrairement au mélangeur HSL, il peut volontairement colorer les gris.
8. **Effets spatiaux structurels** : Texture à rayon fin, Clarté à rayon intermédiaire et Correction du voile à grand rayon. Voir [le détail des algorithmes](Effects.md).
9. **Détail** : réduction du bruit coloré, réduction du bruit de luminance puis netteté de luminance avec masque de contours. Voir [le panneau Détail](Detail.md).
10. **Finition** : Vignette puis Grain ; ce dernier reste ainsi intact après le débruitage.
11. **Géométrie** : rotation, miroirs, perspective verticale/horizontale, redressement sans coins transparents, aspect, échelle, décalage, ratio et crop normalisé. Voir [Géométrie](Geometry.md).
12. **Pile de modifications** : développement du calque Photo entière, géométrie commune, puis composition et mélange successifs des calques masqués. Voir [Pile de modifications](AdjustmentLayers.md), [Masques](Masks.md) et [Masques intelligents](SmartMasks.md).
13. **Sortie écran** : CGImage Display P3 8 bits SDR. L’histogramme provient d’un échantillonnage de 160×160 en sRGB hors MainActor. L’écrêtage affiché décrit cet aperçu SDR, pas le contenu récupérable du capteur RAW.

## Ordre et compromis

L’exposition avant les opérations perceptuelles évite d’ajouter de la luminosité gamma-encodée. Les masques tonals sont calculés avant saturation/vibrance pour préserver la séparation des intentions. La LUT sRGB borne à [0, 1] : des valeurs hors gamut/HDR sont écrêtées à cette étape, et ne constituent pas une pipeline d’export HDR. Les réglages sont crédibles et différenciés, mais ne prétendent pas reproduire les algorithmes propriétaires d’un autre logiciel.

La réduction avant les réglages privilégie la latence. Les previews HQ restent limitées à 2048 px et le zoom ne déclenche pas encore de rendu tuilé à 100 %. Une image 48 MP n’est jamais demandée pendant le mouvement d’un curseur. Un RAW peut néanmoins occasionner des allocations internes propres au décodeur d’Apple.

Une annulation coopérative vérifie la tâche avant le décodage, lors de la génération de LUT et autour du rendu GPU. Une soumission Core Image déjà engagée peut finir ; son résultat ne sera pas affiché si la génération a changé. L’actor sérialise l’accès au contexte. Les filtres sont créés pour chaque graph et les caches de sources sont vidés au changement de document et en cas d’alerte mémoire.

Le panneau DEBUG indique la durée du calcul et une estimation des deux bitmaps affichées ; cette estimation **n’inclut pas toute la mémoire GPU ni le cache**. Le FPS reste explicitement « non mesuré ». Aucun objectif de 60 fps n’est annoncé comme atteint.

## Validation

Les tests couvrent sérialisation/validation, regroupement Undo/Redo, branchement de l’historique et sa borne, identité tonale, ciblage ombres/hautes lumières, protection vibrance, conservation des octets originaux, sauvegardes désordonnées, erreurs de décodage, annulation et traitement d’une mire via le véritable contexte Core Image. Les tests RAW sur fichiers de boîtiers et les mesures sur iPhone physique restent à effectuer.

## Résultat vérifié le 20 septembre 2026

- Build Debug iOS Simulator réussi, cible minimale iOS 18.
- `swift test` : **82 tests réussis**, exécutés sur macOS arm64 avec le véritable moteur Core Image.
- XCTest UI sur iPhone 18 Pro / iOS 27 Simulator : parcours Masques réussi avec pinceau Peindre/Effacer, renommage, visibilité, opacité, déplacement et contour progressif radial, gestion des composantes, restauration après relance et réordonnancement Undo/Redo. Le menu intelligent expose aussi Personne, Visage, Yeux, Ciel et Peau ; la segmentation par instances reste sautée sur simulateur lorsque celui-ci ne peut pas créer son contexte d'inférence.
- Aucun warning du compilateur Swift. Avertissement Xcode non bloquant : extraction de métadonnées App Intents ignorée (aucune dépendance AppIntents). Le runtime du simulateur émet également un diagnostic Apple de classes d’accessibilité dupliquées.
- Pas de test sur iPhone physique, ni de fixture RAW de boîtier dans cette livraison. JPEG testé dans le simulateur ; PNG et TIFF orienté testés automatiquement. Le support HEIC/RAW repose sur les décodeurs système et reste à valider avec un corpus réel.

Derniers résultats XCTest : `/tmp/LumoraQuickLayerMenuUI-v2.xcresult` vérifie le sélecteur rapide Photo entière/Radial 1 ainsi que l’overlay rouge dans Lumière après le réglage d’Exposition ; `/tmp/LumoraEffectsDetailFocusUI.xcresult` vérifie que Correction du voile et Gain changent réellement les pixels et libèrent la barre d’outils. Le parcours des gestes d’aperçu reste archivé dans `/tmp/LumoraPreviewGesturesUI-v9.xcresult`, celui des opérations groupées dans `/tmp/LumoraBatchSelectionUI.xcresult` et celui du zoom des masques dans `/tmp/LumoraMaskZoomOverlayUI.xcresult`.

## Export pleine résolution

Le moteur repart de l’original avec une instance séparée du contexte Core Image. Le graphe de réglages est partagé avec l’aperçu ; seuls le décodage, les dimensions et le profil de sortie changent. Voir [les options, la validation et les limites](Export.md). Les résultats de validation ci-dessus décrivent la première étape.
