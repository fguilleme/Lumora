# Beauty V1 — comparaison des temps avant/après pipeline de masques

Mac mini M2 Pro, 16 Go, douze mêmes portraits. Ancien passage : raster Swift pixel par pixel et boucle d’imperfections. Nouveau passage : contours vectoriels et kernels Core Image/Metal, avec cinq masques matérialisés une fois par source. Les mesures incluent les sondes diagnostiques ; les sondes isolées face/landmarks et CI→CG ne sont pas additives. Variations de fréquence/cache et échauffement GPU : comparer surtout les ordres de grandeur, non les décimales.

| Cas | Ancien raster conjoint ms | Nouvelle composition masques ms¹ | Anciennes imperfections ms | Nouvelles imperfections ms | Analyse totale avant ms | Analyse totale après ms |
|---|---:|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 1590.0 | 211.9 | 251.0 | 10.9 | 1938.2 | 378.5 |
| 02_dark_skin_texture | 1930.4 | 45.2 | 207.6 | 3.0 | 2184.5 | 106.6 |
| 03_acne_redness | 1479.0 | 54.6 | 152.7 | 3.4 | 1661.9 | 97.0 |
| 04_strong_freckles | 1759.5 | 46.2 | 239.4 | 5.8 | 2038.1 | 93.4 |
| 05_older_wrinkles | 1286.0 | 41.4 | 271.3 | 2.6 | 1582.1 | 73.7 |
| 06_beard_moustache | 1484.0 | 38.8 | 164.4 | 5.9 | 1713.9 | 124.7 |
| 07_glasses | 1487.7 | 86.6 | 152.7 | 3.4 | 1710.6 | 170.1 |
| 08_open_smile_teeth | 1489.3 | 55.9 | 229.0 | 6.4 | 1746.8 | 96.2 |
| 09_pronounced_dark_circles | 1239.1 | 45.5 | 210.7 | 2.6 | 1471.9 | 78.1 |
| 10_detailed_eyes | 1523.5 | 44.8 | 185.0 | 3.0 | 1743.3 | 91.9 |
| 11_45_degree_face | 1491.8 | 40.4 | 274.0 | 2.8 | 1800.3 | 83.3 |
| 12_profile_face | 1312.5 | 40.7 | 300.6 | 2.8 | 1639.5 | 79.5 |

Médianes : raster/composition **1488.5 → 45.3 ms** ; imperfections **219.8 → 3.2 ms** ; analyse totale **1728.6 → 94.8 ms**. Le rapport du banc donne toutes les étapes individuellement.

¹ Somme des étapes « Face raster », « Feature exclusions », « Detail prep », « Skin raster/compose », « Final masks ». La matérialisation supplémentaire des cartes diagnostiques est incluse dans le total, mais absente du parcours normal des curseurs.

Aucune mesure iPhone nouvelle dans cette passe. Le cache du RenderEngine conserve les masques entre mouvements de curseur.
