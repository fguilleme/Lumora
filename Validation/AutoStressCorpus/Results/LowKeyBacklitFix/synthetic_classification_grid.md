# Grille synthétique de classification

47 distributions : huit archétypes, 24 combinaisons P50/P95, 15 perturbations autour de trois frontières. P99 et occupation noire varient aussi. La distribution est créée comme rampe de quantiles neutres ; les valeurs mesurées sont celles de `ImageAnalysis.measure`.

| Distribution | P50 mesuré | P95 mesuré | P99 mesuré | noirs | classe | EV | ombres |
|---|---|---|---|---|---|---|---|
| pure low-key | 0.02005 | 0.4001 | 0.55 | 0.1011 | lowKey | 0 | 3 |
| night with small lights | 0.01603 | 0.2708 | 0.9498 | 0.04077 | lowKey | 0 | 3 |
| dark foreground + bright background | 0.005129 | 0.9599 | 0.99 | 0.188 | backlit | 0.5 | 16 |
| silhouette + sunset | 0.00906 | 0.4603 | 0.7799 | 0.1001 | lowKey | 0 | 3 |
| normal high contrast | 0.2001 | 0.96 | 0.99 | 0.01245 | normal | 0 | 0 |
| high-key | 0.6 | 0.97 | 0.99 | 0.0009766 | highKey | 0 | 0 |
| dark without highlights | 0.01501 | 0.08004 | 0.12 | 0.1082 | normal | 1.5 | 0 |
| dark with moderate highlights | 0.01008 | 0.6002 | 0.8499 | 0.09521 | lowKey | 0 | 3 |

## Perturbations ±0,002

| Centre | max ΔEV adjacent | max Δombres adjacent |
|---|---|---|
| perturb P50=0.04 P95=0.79 | 0.01 | 0.09827 |
| perturb P50=0.06 P95=0.82 | 0.01 | 0.1793 |
| perturb P50=0.045 P95=0.9 | 0.01 | 0.3029 |

Voir `synthetic_grid.json` pour chaque cellule et valeur mesurée.
