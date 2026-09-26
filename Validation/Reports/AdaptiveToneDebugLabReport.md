# Adaptive Tone Debug Lab — validation initiale

## Périmètre et architecture

Le panneau **Debug** est ajouté à l'éditeur sous `#if DEBUG`. Il reçoit la même preview rendue que l'éditeur normal, convertit ses pixels display-P3/8-bit en sRGB linéaire, puis exécute les variantes dans un acteur isolé. Les sorties et cartes ne sont conservées que dans l'état transitoire de la vue : aucun `EditState`, document, historique Undo, export ou moteur Auto n'est modifié. L'interface Release ne contient ni onglet ni code compilé du Lab.

Cette entrée de preview rend les comparaisons A/B loyales sur les mêmes pixels, mais **ne valide pas le HDR source, le RAW pleine résolution ni le rendu export**. Les vues 100–200 % agrandissent la preview disponible et ne constituent pas une inspection pleine résolution. Les shaders restent en espace linéaire flottant pendant le calcul ; le bitmap de présentation est ensuite encodé en 8-bit.

Variantes disponibles : Off / Original pipeline ; Phase 1 Gaussian, Bilateral, Guided ; Phase 2 A, B, C ; Phase 4 Spatial, Semantic, Combined ; Phase 5 Shadow Budget A, B, C. Guided/Phase 2/Phase 5 exécutent sur Metal les équations et constantes des prototypes archivés. Phase 4 utilise leurs composantes et constantes spatiales/sémantiques, avec une carte construite en Swift. Gaussian/Bilateral sont des ports CPU de référence ; leurs filtrages/redimensionnements ne sont pas bit-identiques à OpenCV/SciPy.

Deux sélecteurs A/B, les modes A seul/B seul/Split, un séparateur mobile, un zoom et un pan communs, l'histogramme choisi sur A ou B, et les métriques de rendu forment la comparaison. Changer de variante ou de photo annule la tâche précédente ; l'identité de requête empêche une réponse tardive d'écraser une nouvelle comparaison. L'acteur retient au plus six sorties par image, avec invalidation au changement d'objet image ; les cartes Phase 4 sont également mises en cache. Le split et le pan n'entraînent aucun nouveau rendu.

Les métriques affichées sont le temps GPU ou CPU de traitement, la préparation, la taille du bitmap, l'estimation des allocations Metal, le P95 de référence, les fractions de pixels au gain >2×, >3× et >4×, le gain maximal et le cache hit. Ce ne sont pas des critères de qualité photographique.

## Advanced Scene Analysis

L'acteur `DebugSceneAnalyzer` produit un JSON versionné par preview : statistiques globales, grille 128 pixels au plus grand côté (luminance linéaire et logarithmique, chroma, contraste local, gradient, texture, zones sombres/claires), régions tonales connexes, visages, segmentation de personne, saliency, sujets candidats, scores d'interprétation, confiance, risques de bruit et durées. Les cartes peuvent être superposées dans le Lab ; le JSON complet peut être copié depuis le panneau Debug. Aucune sortie d'analyse ne génère un réglage photo.

Vision utilise `VNDetectFaceRectanglesRequest`, `VNGeneratePersonSegmentationRequest` et `VNGenerateAttentionBasedSaliencyImageRequest`. Le score sujet combine indice sémantique 35 %, taille 18 %, saliency 18 %, séparation locale 17 % et composition 12 %. Le backlight compare candidat et voisinage lumineux ; l'interprétation garde explicitement l'ambiguïté entre sujet blanc et high key. L'estimation de bruit d'ombre vient de la texture des cellules sombres à faible gradient, **pas** d'une mesure de bruit capteur.

Le cache Scene Analysis est limité à l'identité de la preview courante. C'est sûr contre la réutilisation d'un pointeur et contre les résultats tardifs, mais une modification de slider qui recrée la preview peut relancer Vision. La séparation source/géométrie/développement demandée reste donc **WARN**. Les tâches sont hors MainActor pour le calcul lourd ; l'application de résultat est gardée par annulation et identité de source.

## Campagne et constats

La campagne comprend 16 photos existantes (8 corpus photographique, 8 Auto Stress) et 4 cas complémentaires de faux positif/multi-sujet. Les 16 photos ont produit des cartes personne et saliency ; huit contiennent un visage reconnu. Les 13 variantes ont rendu six photos de stress à 384 px, soit 78 rendus, sans valeurs non finies observées. Les sorties complètes du corpus sous `Validation/DebugLab/Variants/` et les cartes individuelles sous `Validation/DebugLab/SceneAnalysis/` restent des artefacts locaux non figés ; les planches prioritaires et le JSON d'analyse compressé sont conservés avec le rapport.

**PASS — techniques vérifiées :** build Debug, build Release, 118 tests Core, test UI ciblé réussi, rendu des 13 variantes, calcul Vision et JSON des 16 photos, génération des planches, cache image-identité, requêtes annulables, valeurs finies sur les six photos de comparaison. Le test UI vérifie l'ouverture du Lab, la comparaison portrait/paysage, un déplacement du split, un pinch 2×, un pan et le retour à Lumière sans nouvelle action Undo. Une recherche dans le binaire Release n'y trouve ni le titre du Lab ni les libellés des variantes. Les réglages Auto et les renderers normaux n'ont pas été modifiés.

**WARN — qualité et portée de la mesure :**

- 01 portrait intérieur sombre : visage détecté et candidat présent, mais classement « Dark scene with isolated lights », score backlight 0,008. La présence du visage sombre devant la fenêtre ne suffit pas au modèle d'interprétation actuel.
- 05 silhouette au coucher du soleil : candidat présent, mais même classement sombre, backlight 0,003 ; l'hypothèse « silhouette intentionnelle » n'émerge pas.
- 02 portrait de plage surexposé : « Possible backlit subject » (0,281), alors que high key/surexposition reste plausible.
- Une photo encadrée peut produire un faux visage ; le cas à deux personnes ne sépare pas toujours les deux sujets ; l'animal/objet non humain de la cuisine n'est pas retenu malgré la saliency disponible.
- Phase 1 CPU et carte Phase 4 ne sont pas des reproductions numériques exactes des exécutables Python archivés ; la comparaison n'est donc pas une preuve de parité pixel à pixel.
- Cache Vision non stratifié, coût iPhone non mesuré, agrandissement de preview plutôt que vraie inspection à 200 % de l'original ; les mesures ne certifient pas une expérience interactive sur appareil.

**FAIL : 0** sur les contrôles exécutés. Les WARN restent ouverts à l'inspection visuelle ; aucune constante ni heuristique photographique n'a été retouchée.

## Performances et mémoire

Mesures de diagnostic sur Mac, six photos de stress à 384 px, médianes de traitement : Phase 1 Gaussian **35,86 ms CPU**, Bilateral **16,25 ms CPU**, Guided **1,35 ms GPU**, Phase 2 C **1,87 ms GPU**, Phase 4 Combined **3,61 ms GPU** (hors préparation de carte), Phase 5 C **1,60 ms GPU**. Les maxima respectifs observés : 38,68 / 18,09 / 4,23 / 2,58 / 6,93 / 2,07 ms. Ce ne sont ni des mesures iPhone ni des durées de bout en bout. La UI expose séparément la préparation et l'estimation de mémoire par variante.

Sur les 16 photos, médiane / P95 / max de Scene Analysis en ms : global 51,12 / 65,30 / 69,56 ; spatial 0,35 / 0,41 / 0,48 ; faces 8,44 / 31,93 / 125,75 ; personne 21,61 / 43,97 / 82,22 ; saliency 9,68 / 34,93 / 56,53 ; scoring 0,07 / 0,14 / 0,16. Ces durées sont des sous-étapes instrumentées sur Mac et n'incluent pas toutes les copies/présentations UI. Le cache de six bitmaps et les buffers Metal temporaires peuvent occuper plusieurs dizaines de Mo selon la taille de preview ; aucun profil RSS sur iPhone n'a été réalisé.

## Validation de l'interface et limites

Le Lab se place dans la colonne Controls en paysage et la comparaison dans la colonne Photo, selon le mode gaucher existant. Les captures UI finales montrent les deux moitiés alignées dans les orientations portrait et paysage. Une correction technique a supprimé une inversion verticale du bitmap Debug ; un aller-retour bitmap mesuré s'aligne à 0,115/255 d'erreur RGB moyenne. L'essai physique à 200 % reste nécessaire pour juger la netteté, le pan et la fluidité.

### Correctifs après retour sur appareil — 24 septembre 2026

L'assert iPhone montré dans Xcode provenait du dispatch Metal du kernel `percentile` : son argument `thread_position_in_grid` est scalaire, tandis que le Lab envoyait un groupe 16 × 16. Un dispatch 1 × 1 est désormais utilisé pour ce kernel uniquement ; les autres kernels gardent leur grille 2D. Le build Debug et le test UI iPhone passent après correction. **La disparition de l'assert sur l'iPhone physique reste à confirmer sur l'appareil de l'utilisateur** : les tests automatisés ont utilisé le simulateur.

Sur iPad, la condition d'activation des colonnes paysage était limitée explicitement à l'idiome iPhone. Elle dépend maintenant de la géométrie disponible, quel que soit l'appareil. Un test UI sur iPad Pro 13″ Simulator vérifie une fenêtre paysage de 1376 × 1032 points, la colonne Controls à x=0…340, la photo à x=340…1376, le bouton d'inversion du côté et la comparaison A/B prête. Le test paysage préexistant passe aussi sur iPad, y compris l'inversion gauche/droite, la rotation et les panneaux Light, Color, Grading, Effects, Masks et Curves. Le build Release passe également. Les captures XCTest d'iPad peuvent porter une orientation de fichier incohérente ; les coordonnées d'accessibilité et le résultat du test font foi pour la disposition.

Historique des corrections techniques avant cette campagne : décodage float Core Image transparent remplacé par CGContext ; cache par adresse seule remplacé par rétention forte de la source ; lecture du pixel buffer saliency étendue aux formats float/half ; inversion verticale du bitmap supprimée ; signature de gesture du test UI corrigée après une première compilation de test échouée. Aucune de ces corrections ne change les traitements photographiques archivés.

## Artefacts à inspecter

1. [off_vs_phase2c.png](../DebugLab/off_vs_phase2c.png)
2. [guided_vs_phase2c.png](../DebugLab/guided_vs_phase2c.png)
3. [phase2c_vs_semantic.png](../DebugLab/phase2c_vs_semantic.png)
4. [semantic_vs_shadowbudget.png](../DebugLab/semantic_vs_shadowbudget.png)
5. [zoom_200_percent.png](../DebugLab/zoom_200_percent.png)
6. [landscape.png](../DebugLab/landscape.png)
7. [vision_maps.png](../DebugLab/vision_maps.png)
8. [Scene Analysis contact sheet](../DebugLab/SceneAnalysis/contact_sheet.png)
9. [Scene Analysis JSON compressé](../DebugLab/SceneAnalysis/scene_analysis.json.gz) — le JSON non compressé reste un artefact local du banc.

Aucun Golden Master n'a été créé. Aucun variant gagnant n'est choisi.
