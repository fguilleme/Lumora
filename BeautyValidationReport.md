# Beauty V1 — validation sur corpus dédié

**Passage peau et pipeline du 25 septembre 2026 :** le masque suit désormais le contour facial Vision, étend le front et protège les détails locaux. La boucle Swift pixel par pixel des masques a été remplacée par un pipeline vectoriel/Core Image/Metal. Les corrections antérieures des dents 08, de l’œil de profil 12 et de l’alignement sont conservées. Voir la [planche avant/après des douze portraits](BeautyValidation/skin_mask_before_after.png), les [mesures par étape](TestArtifacts/BeautyValidationReport.md) et la [comparaison des temps](BeautyValidation/Results/skin_mask_pipeline_timing_comparison.md). Les sections historiques ci-dessous décrivent la conception Beauty V1 ; les résultats de cette passe font foi lorsqu’ils la précisent.

## Architecture et périmètre

`BeautyState` est enregistré dans `EditState` avec une version de schéma. Un ancien document sans clé `beauty` reste neutre. Les trois presets sont des valeurs éditables de ces mêmes curseurs ; le retour à leurs valeurs exactes rétablit le nom du preset, sinon l’interface indique `Custom`. Une action de preset ou une manipulation de curseur s’intègre à l’historique Undo/Redo existant.

Le graphe commun aperçu/HQ/export place Beauté après les corrections optiques, géométriques et de développement, avant le détail différé, les masques locaux, le grain et Creative FX. Quand Beauté est neutre, l’ancien graphe reste inchangé. Aucun pixel n’est déplacé géométriquement et aucun changement n’a été apporté aux renderers des effets existants. La V1 applique les mêmes paramètres à tous les visages fiables ; le réglage indépendant par personne reste hors périmètre.

## Vision, masques et cache

`BeautyFaceAnalysis` détecte les visages et landmarks natifs Vision sur une prévisualisation orientée et transformée, limitée à 1024 pixels sur le côté long. Un visage nécessite une taille minimale et au moins un œil fiable. `BeautyMaskPipeline` dessine le contour facial en vecteur, prolonge le front depuis les sourcils, puis applique une confiance chromatique continue issue d’échantillons clairsemés des joues. Les yeux, sourcils, lèvres et narines sont exclus par des formes douces. Les détails locaux détectés sur l’image diminuent le poids du masque autour des poils, lunettes, rides et taches de rousseur, sans changer l’intensité du renderer. Les masques yeux et cernes utilisent la géométrie des yeux ; celui des cernes suit l’axe œil–nez. Le masque dents nécessite des lèvres internes ouvertes et un candidat clair, peu saturé. Celui des imperfections exige un excès local de rouge dans la peau ; il ne vise donc pas automatiquement les taches de rousseur sombres.

Les masques sont temporaires, jamais inscrits au document. `RenderEngine` les conserve pour une même source, optique et géométrie ; le changement d’un curseur Beauté réutilise l’analyse, tandis qu’un miroir force sa reconstruction. L’analyse se fait hors du fil UI, avec annulation et contrôle de génération avant mise à jour de la session. Aucun visage donne une identité de rendu et une indication explicite dans l’onglet. L’afficheur des cinq masques est disponible uniquement en Debug.

## Rendu et espace couleur

Le rendu utilise des kernels Core Image/Metal sur des pixels float en sRGB linéaire étendu. Seules les mattes sont en gris 8 bits. Pour la peau, `low = Gaussian(original, rayon lié à la largeur du visage)` et `high = original − low`. Uniformité rapproche les variations larges de `low` d’une version plus diffuse sans retirer `high` ; Texture change modérément le gain de `high`. La reconstruction neutre `low + high` a été vérifiée jusqu’à 8 linéaire. Imperfections mélange localement vers un voisinage flouté uniquement sous son masque. Cernes réchauffe et relève légèrement les zones sous les yeux ; Yeux agit sur luminosité et détail local ; Dents réduit la chaleur et relève légèrement la luminosité dans le masque dentaire. Tous les gains sont bornés. La V1 ne crée ni maquillage, ni retouche des cheveux, ni reshape.

## Tests techniques

| Contrôle | Résultat | Classe |
|---|---|---|
| État neutre, Amount 0, aucun visage | PASS : rendu identique, sans nœud Core Image Beauty | Hard |
| Reconstruction de fréquences et HDR 0…8 | PASS : erreur maximale < 0,003, valeurs finies | Hard |
| Rendu masqué | PASS : changement local, extérieur inchangé à la tolérance du test | Hard |
| Ancien document, sérialisation, presets, Undo/Redo | PASS | Hard |
| Annulation Vision | PASS | Hard |
| Portraits, recadrage et miroir | PASS : détection conservée | Hard |
| Cache | PASS : même matte après changement de curseur ; matte reconstruite après miroir | Hard |
| Prévisualisation/HQ | PASS technique : aucun non-fini ; MAE normalisée 0,001601, incluant le rééchantillonnage des entrées | Qualité |
| Rotation à 90° | PASS : visage détecté après rotation | Hard |
| Export documentaire complet sur appareil | Non exécuté ; partage le même renderer que l’aperçu/HQ | Couverture |

Le nouveau Visual Test Lab traite **douze portraits BeautyValidation distincts**, sans photo Auto Stress pour l'évaluation photographique. Il détecte un visage dans chacun, avec un visage occupant **41,0 à 56,5 %** de la largeur cadrée, et ne trouve aucun pixel non fini dans les trois rendus par photo. Le tableau complet des douze cas, les MAE et les temps mesurés sont dans le [rapport détaillé du banc](TestArtifacts/BeautyValidationReport.md). Les MAE mesurent seulement l'amplitude du changement, jamais sa qualité esthétique. Les contrôles techniques du tableau ci-dessus proviennent de la campagne Beauty V1 initiale ; le nouveau test du corpus a été relancé séparément après ajout des photos.

## Corpus photographique dédié

Les [douze sources et leurs attributions](BeautyValidation/corpus.json) couvrent les pores sur peau claire, la texture de peau sombre, l'acné et les rougeurs, les taches de rousseur, les rides, la barbe et la moustache, les lunettes, les dents visibles dans un sourire, les cernes, les yeux et la sclère, une vue à environ 45° et un profil. Chaque cadrage est fixé dans le manifeste. Le banc conserve les pixels sources pour ses crops **320 × 320 à 100 %**, sans agrandissement, et produit pour chaque image Original, Natural, Portrait, Beauty et une planche des cinq masques. La méthode et les licences sont décrites dans le [README du corpus](BeautyValidation/README.md).

Le cas 09 présente un éclairage clair sur le visage, mais les détails sous les yeux restent visibles ; son utilité photographique doit être confirmée par comparaison directe. Lors de la première campagne, le masque dentaire 08 ne couvrait qu'une partie des dents et le profil 12 présentait deux régions « yeux ». Ces deux défauts, ainsi qu'un décalage vertical des masques par rapport aux pixels, sont corrigés et vérifiés dans la [campagne ciblée](BeautyValidation/Results/BeautyTargetedValidationReport.md). Les autres masques, notamment imperfections et cernes, exigent toujours une inspection esthétique à 100 %.

Pour la passe actuelle, les douze anciens masques peau ont été [archivés](BeautyValidation/Results/BaselineSkinMasks/) avant modification. Le banc compare l’aire pondérée de l’ancien masque, du nouveau masque avant protection et du masque effectif. Exemples en pourcentage de l’image d’analyse : peau claire 01 **16,1 → 21,2 → 19,6 %**, peau sombre 02 **7,7 → 14,9 → 14,4 %**, rides 05 **20,4 → 29,5 → 26,2 %**, barbe 06 **7,5 → 13,0 → 10,6 %**, profil 12 **19,6 → 31,8 → 31,5 %**. Ces chiffres décrivent la couverture, pas l’exactitude dermatologique ; le [tableau des douze cas](TestArtifacts/BeautyValidationReport.md) et la [planche](BeautyValidation/skin_mask_before_after.png) doivent être lus ensemble.

Le cadrage et les crops ont été corrigés dans le banc seulement après inspection des planches : le crop cernes 09 descendait initialement sur le nez et le crop taches de rousseur 04 montrait la bouche. Les nouvelles planches ciblent respectivement les cernes et le front. Aucune image source n'a été lissée, recolorisée ou retouchée, et aucun paramètre Beauty n'a été changé.

## Performance et portée

Sur ce Mac mini M2 Pro, la campagne ciblée antérieure mesurait **1,47 à 2,18 s** par photo, médiane **1,73 s**. Le pipeline actuel mesure **73,7 à 378,5 ms**, médiane **94,8 ms**, sur les mêmes douze cas. La composition des masques passe de **1 488,5 à 45,4 ms** médians ; les imperfections de **219,8 à 3,2 ms**. Le premier cas comprend un coût GPU froid élevé. Les [temps par cas et leurs limites](BeautyValidation/Results/skin_mask_pipeline_timing_comparison.md) précisent que les diagnostics matérialisent des cartes supplémentaires absentes du parcours normal. Vision reste asynchrone ; `RenderEngine` met les mattes en cache, sans readback à chaque déplacement de curseur. Aucune mesure iPhone nouvelle n’a été obtenue dans cette passe.

## État

- **PASS technique du passage actuel** : 12/12 photos traitées, 12 visages fiables, 0 pixel non fini, planche peau Old/New/Effective/Overlay, masques 08/12 alignés, une seule région d’œil pour le profil, barbe/ride protégées par le détail, build iOS Simulator et 11/11 tests Beauty réussis.
- **WARN qualité à inspecter** : les contours de cheveux 03/10 et les branches de lunettes 07 conservent un peu de masque ; la protection de détail réduit la couverture des rides 05 et de la barbe 06, mais sa qualité photographique doit être jugée à 100 %. Le cas 09 demande toujours une inspection humaine. Le front 02 est couvert au-dessus du sourcil, comme le montre sa [planche de diagnostic](TestArtifacts/BeautyValidation/02_dark_skin_texture/Skin/forehead_diagnostic.png).
- **Couverture non conclue** : inspection sur appareil, plusieurs visages dans une même scène et export réel. Les anciens tests Auto Stress peuvent seulement servir de tests techniques de robustesse.
- **FAIL restant** : aucun ; `swift test --disable-sandbox --filter beauty` passe 11/11 et le build iOS Simulator passe. L'inspection humaine reste nécessaire avant toute décision esthétique.

## Priority Visual Inspection

1. [Masques peau avant/après sur les douze portraits](BeautyValidation/skin_mask_before_after.png) et [planche globale des rendus](TestArtifacts/BeautyValidation/contact_sheet.png)
2. [Pores sur peau claire à 100 %](TestArtifacts/BeautyValidation/01_light_skin_pores/Crops/skin_100pct.png) et [texture de peau sombre à 100 %](TestArtifacts/BeautyValidation/02_dark_skin_texture/Crops/skin_100pct.png)
3. [Acné et masques](TestArtifacts/BeautyValidation/03_acne_redness/masks.png) ; [taches de rousseur à 100 %](TestArtifacts/BeautyValidation/04_strong_freckles/Crops/blemishes_100pct.png) ; [rides à 100 %](TestArtifacts/BeautyValidation/05_older_wrinkles/Crops/skin_100pct.png)
4. [Dents à 100 %](TestArtifacts/BeautyValidation/08_open_smile_teeth/Crops/teeth_100pct.png) et [masques du sourire](TestArtifacts/BeautyValidation/08_open_smile_teeth/masks.png)
5. [Cernes à 100 %](TestArtifacts/BeautyValidation/09_pronounced_dark_circles/Crops/under_eyes_100pct.png) ; [yeux à 100 %](TestArtifacts/BeautyValidation/10_detailed_eyes/Crops/eyes_100pct.png) ; [masques du profil](TestArtifacts/BeautyValidation/12_profile_face/masks.png)

Aucun Golden Master n'a été créé. Les WARN esthétiques de cette passe n'ont provoqué aucun réglage du renderer ou des presets Beauty ; la présente modification concerne le masque de peau et son pipeline uniquement.
