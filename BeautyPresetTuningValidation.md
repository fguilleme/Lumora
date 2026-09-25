# Beauty V1 — unique passe de réglage des presets

Natural reste inchangé. Portrait et Beauty ont été augmentés une seule fois au moyen des contrôles existants ; ni masque, ni Vision, ni renderer, ni pipeline n’a été modifié.

| Contrôle | Natural | Portrait avant → après | Beauty avant → après |
|---|---:|---:|---:|
| Uniformité | 12 | 28 → 42 | 45 → 70 |
| Texture | −4 | −8 → −8 | −15 → −15 |
| Imperfections | 10 | 24 → 44 | 42 → 70 |
| Cernes | 8 | 20 → 40 | 32 → 65 |
| Éclat yeux | 7 | 16 → 25 | 25 → 42 |
| Détail yeux | 5 | 12 → 16 | 20 → 28 |
| Dents | 6 | 14 → 18 | 23 → 32 |

Les [douze portraits complets](BeautyValidation/aesthetic_contact_sheet.png) et les [dix crops à 100 %](BeautyValidation/aesthetic_crops_100pct.png) montrent Original | Natural | Portrait | Beauty. Les [anciennes planches](BeautyValidation/Results/PresetTuningBaseline/) sont conservées pour comparaison A/B. Le test Beauty complet passe **11/11**, dont le rendu des douze portraits, la stabilité des masques et les contrôles d’identité/HDR.

**Inspection initiale :** pores 01, texture sombre 02, taches de rousseur 04, rides 05 et barbe 06 restent visibles à 100 %. Sur 07, pas de halo franc autour des lunettes ; sur 08, dents non blanc pur ; sur 10, sclère naturelle et pas de halo évident autour de l’œil. Aucun critère hard n’a échoué dans ces planches.

**WARN esthétique :** la différence Portrait/Beauty reste modeste en vue normale et parfois subtile même à 100 %. Les petites rougeurs de 03 et les cernes de 09 restent peu atténuées malgré les valeurs plus élevées. Le cas 09, fortement éclairé sous les yeux, est en outre peu démonstratif. La hiérarchie numérique des presets est respectée, mais son évidence photographique demande l’inspection humaine des planches et de l’appareil.

**Arrêt :** aucune seconde passe de valeurs, aucune correction des algorithmes ou des seuils à partir de ces résultats. Attendre la décision visuelle humaine avant toute autre modification.
