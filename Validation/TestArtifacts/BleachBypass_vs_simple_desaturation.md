# Bleach Bypass vs simple desaturation

Baseline: linear Rec.709 Y, `Y' = Y + 0.22·Y·(1−Y)·(2Y−1)`, RGB residual chroma ×0.60. It has no separate density layer, toe, shoulder or shadow guard. Both renderings use the same synthetic chart; Bleach Bypass uses the production Classic preset.

- Mean absolute RGB difference: 0.0081051015934032
- Mean chroma: simple 0.1790625008288771, Bleach 0.18089361698366702
- Dark textured mean Y: simple 0.04489454656333163, Bleach 0.04979518233033652
- Near-white mean Y: simple 0.9419012007613947, Bleach 0.9343192756176002

[Comparison and amplified difference](BleachBypass/bleach_vs_simple_desat.png). These measurements demonstrate structural difference, not aesthetic superiority.