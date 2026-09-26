# Beauty V1 — comparaison des temps d’analyse

Mac mini M2 Pro, 16 Go ; mêmes douze fichiers et cadrages. Temps muraux d’un passage avant correction ciblée et d’un passage après, sans contrôle de fréquence ou de température : ils indiquent une tendance, pas un benchmark reproductible sur iPhone. Le passage final inclut davantage de sondes diagnostiques ; les estimations par sous-masque échantillonnées ne s’additionnent pas au temps mural.

| Cas | Avant total ms | Après total ms | Variation | Avant raster ms | Après raster ms | Après Vision ms | Après imperfections ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 1974.8 | 1938.2 | -1.9% | 1647.6 | 1590.0 | 84.9 | 251.0 |
| 02_dark_skin_texture | 3154.2 | 2184.5 | -30.7% | 2897.3 | 1930.4 | 26.4 | 207.6 |
| 03_acne_redness | 2289.6 | 1661.9 | -27.4% | 1962.9 | 1479.0 | 17.0 | 152.7 |
| 04_strong_freckles | 3153.3 | 2038.1 | -35.4% | 2872.3 | 1759.5 | 25.2 | 239.4 |
| 05_older_wrinkles | 2140.3 | 1582.1 | -26.1% | 1808.6 | 1286.0 | 16.9 | 271.3 |
| 06_beard_moustache | 2688.1 | 1713.9 | -36.2% | 2454.7 | 1484.0 | 22.6 | 164.4 |
| 07_glasses | 2647.6 | 1710.6 | -35.4% | 2401.0 | 1487.7 | 26.6 | 152.7 |
| 08_open_smile_teeth | 2679.0 | 1746.8 | -34.8% | 2400.1 | 1489.3 | 18.4 | 229.0 |
| 09_pronounced_dark_circles | 1879.2 | 1471.9 | -21.7% | 1647.5 | 1239.1 | 14.3 | 210.7 |
| 10_detailed_eyes | 2203.0 | 1743.3 | -20.9% | 1989.2 | 1523.5 | 18.4 | 185.0 |
| 11_45_degree_face | 2692.5 | 1800.3 | -33.1% | 2395.1 | 1491.8 | 22.4 | 274.0 |
| 12_profile_face | 2276.4 | 1639.5 | -28.0% | 1957.0 | 1312.5 | 16.8 | 300.6 |

**Médianes :** total 2468.6 → 1728.6 ms (-30.0 %) ; raster final 1488.5 ms ; Vision combiné final 20.4 ms ; imperfections finales 219.8 ms.

La réduction principale provient du rejet géométrique avant le test polygonal du masque dentaire, qui ne change pas le résultat mathématique pour les points extérieurs à sa boîte. Les autres écarts peuvent contenir de la variabilité système. Le raster reste le goulot d’étranglement ; aucune optimisation générale du masque de peau n’a été faite.
