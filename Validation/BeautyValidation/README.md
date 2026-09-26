# BeautyValidation — corpus photographique dédié

Ce corpus sert à juger la qualité photographique de Beauty V1. Les portraits Auto Stress restent réservés aux tests techniques de robustesse ; ils ne servent plus à conclure sur l'aspect de la peau, des yeux ou des dents.

Les douze photos couvrent, dans l'ordre : pores sur peau claire, texture de peau sombre, acné/rougeurs, taches de rousseur marquées, rides d'un visage âgé, barbe/moustache, lunettes, sourire avec dents visibles, cernes marqués, détails de l'œil et de la sclère, visage à environ 45°, et profil. Les teints et âges varient. Les photos sources ne sont ni lissées, ni retouchées, ni recolorisées par le banc. Les cadrages sont uniquement les rectangles fixes de [`corpus.json`](corpus.json), après orientation EXIF ; le visage détecté occupe 40–60 % de la largeur cadrée. La détection Vision et cette mesure doivent être vérifiées dans le rapport généré.

Les photographies de `Sources/` proviennent des pages indiquées dans `corpus.json`, avec auteurs et licences. La photo 04 est de **Eddy Van 3000**, sous [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/), et ses crops/planche dérivés conservent cette attribution et cette licence. Les autres images gardent leurs conditions Pexels ou Unsplash indiquées par source. Ce corpus est destiné à la validation interne ; vérifier ces conditions avant toute redistribution des images ou planches.

Exécution sur macOS avec Vision et Metal disponibles :

```sh
swift test --disable-sandbox --filter beautyPhotographicValidation
```

Le banc crée [`TestArtifacts/BeautyValidation/contact_sheet.png`](../TestArtifacts/BeautyValidation/contact_sheet.png), puis, pour chaque cas, `comparison.png` (Original, Natural, Portrait, Beauty), `masks.png` (peau, yeux, cernes, dents, imperfections) cinq feuilles `Crops/*_100pct.png` et trois feuilles `Skin/{cheek,forehead,chin}_100pct.png` affichant source, masque et overlay. La [planche peau avant/après](skin_mask_before_after.png) compare les douze anciens masques conservés dans `Results/BaselineSkinMasks/`, la nouvelle région peau avant protection, le masque effectif et sa superposition sur la photo. Chaque case des feuilles de crops est une fenêtre de **320 × 320 pixels sources**, sans agrandissement. Certains masques peuvent légitimement être vides, notamment les dents sur une bouche fermée ; une planche vide ne valide donc pas leur qualité. Les crops utilisent un point diagnostique fixe par zone et doivent être examinés avec la planche entière et les masques.

Les mesures, le cadrage, les aires de masques et les éventuels WARN figurent dans [`TestArtifacts/BeautyValidationReport.md`](../TestArtifacts/BeautyValidationReport.md). Le [passage ciblé précédent](Results/BeautyTargetedValidationReport.md) conserve les masques 08/12 avant/après et l’inspection initiale de peau à 100 %. La [comparaison de performance du nouveau pipeline](Results/skin_mask_pipeline_timing_comparison.md) distingue les anciennes boucles Swift des nouvelles étapes Core Image/Metal. Le bilan de projet est [`BeautyValidationReport.md`](../Reports/BeautyValidationReport.md). Les écarts moyens de pixels mesurent l'amplitude du rendu, pas son mérite esthétique. Aucun Golden Master n'est créé et aucun réglage esthétique Beauty n'est ajusté automatiquement après ce passage.
