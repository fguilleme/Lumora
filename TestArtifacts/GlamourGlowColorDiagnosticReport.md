# Glamour Glow — equal-luminance color diagnostic

Production code was not changed. All outputs use `CreativeStackRenderer.apply` and the actual Glamour Glow Metal kernels in extended linear sRGB / RGBAf.

Settings: `amount=90.0, glow=90.0, highlightProtection=55.0, shadowProtection=0.0, softness=65.0, threshold=40.0, warmth=0.0`. Fixed source disc radius 32 px in a 384×384 frame; measured halo annulus 35 ≤ radius < 76 px, excluding source. Measured pixel count and integrated RGB are in the JSON alongside this report. The plotted PNGs are SDR display previews; measurement is made before display conversion and preserves RGB values above 1.

## Actual equations

`Y = 0.2126·max(R,0) + 0.7152·max(G,0) + 0.0722·max(B,0)`; `L = sqrt(max(Y,0))`; `knee = 0.30 + threshold·0.55 = 0.52`; `gate = smoothstep(knee−0.20, knee+0.25, L)`. Extraction is `max(RGB,0)·gate`. Three Gaussian fields are combined with weights `0.50/0.32/0.18`; the combined RGB is tinted (neutral Warmth here), scaled by Amount, Glow, shadow and highlight guards, then limited per receiving channel by `max(0,1−RGB)·(2−1.65·highlightProtection)`. Thus the gate is color-independent at equal Y, while final energy may depend on hue through RGB diffusion and per-channel headroom.

## Old `GG_color_blue` warning

The old isolated test compares unequal RGB colors at the same approximate channel peak, using the same threshold 40 and ring ROI `(246,345,20,20)` around a radius 0.13×512 disc. Its `haloMeanLuminance` is the output mean of that ring. Its `haloChromaticityError=1` is an explicit sentinel when summed RGB halo ≤ 1e-10, not a measured hue error. The blue source has `L=0.3185122`, below the gate start of `0.32`, so its gate is exactly zero and the extracted field and halo are black. This is a source-selection/measurement issue, not evidence by itself of a blue-only kernel defect.

| Old case | RGB | Y | sqrt(Y) | gate |
|---|---|---:|---:|---:|
| red | 0.95, 0.02, 0.02 | 0.217718 | 0.4666026 | 0.2492508 |
| green | 0.02, 0.95, 0.02 | 0.685136 | 0.8277294 | 1 |
| blue | 0.02, 0.04, 0.95 | 0.10145 | 0.3185122 | 0 |
| orange | 0.95, 0.32, 0.02 | 0.432278 | 0.6574785 | 0.8436963 |

## Equal linear luminance

Targets are derived from the real knee: Low SDR = 0.95×minimum unit-color Y = 0.06859, Knee start = (knee−0.14)² = 0.1444, Medium = knee² = 0.2704, High = (knee+0.30)² = 0.6724. Low SDR is the highest practical common SDR pure-color level, but falls below the gate start; Knee start samples the rising gate. At the latter three levels, saturated blue necessarily exceeds RGB=1 in extended linear sRGB. No pre-clamp was applied. Maximum measured within-level Y spread: 5.309582e-08.

| Level | Color | source RGB | Y | sqrt(Y) | gate | halo mean Y | halo peak Y | halo integrated Y | halo integrated RGB | energy/Y | relative efficiency | chroma error | weak halo |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| Low SDR | Red | 0.3226247, 0, 0 | 0.06859 | 0.2618969 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| Low SDR | Green | 0, 0.09590324, 0 | 0.06859 | 0.2618969 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| Low SDR | Blue | 0, 0, 0.95 | 0.06859 | 0.2618969 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| Low SDR | Cyan | 0, 0.08710948, 0.08710948 | 0.06859 | 0.2618969 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| Low SDR | Magenta | 0.2408357, 0, 0.2408357 | 0.06859 | 0.2618969 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| Low SDR | Yellow | 0.07392757, 0.07392757, 0 | 0.06859 | 0.2618969 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| Low SDR | Orange | 0.1481681, 0.05185885, 0 | 0.06859 | 0.2618969 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| Low SDR | White | 0.06859, 0.06859, 0.06859 | 0.06859 | 0.2618969 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| Knee start | Red | 0.6792098, 0, 0 | 0.1444 | 0.38 | 0.04859259 | 3.922842e-05 | 0.0005786021 | 0.5615941 | 2.641553, 0, 0 | 3.889156 | 0.9999556 | 0 | false |
| Knee start | Green | 0, 0.2019016, 0 | 0.1444 | 0.38 | 0.0485926 | 3.922478e-05 | 0.0005784997 | 0.5615419 | 0, 0.7851537, 0 | 3.888794 | 0.9998626 | 0 | false |
| Knee start | Blue | 0, 0, 2 | 0.1444 | 0.38 | 0.04859259 | 3.922572e-05 | 0.0005784734 | 0.5615554 | 0, 0, 7.777776 | 3.888888 | 0.9998867 | 0 | false |
| Knee start | Cyan | 0, 0.1833884, 0.1833884 | 0.1444 | 0.38 | 0.04859259 | 3.922945e-05 | 0.0005785513 | 0.5616088 | 0, 0.7132446, 0.7132446 | 3.889257 | 0.9999816 | 0 | false |
| Knee start | Magenta | 0.5070225, 0, 0.5070225 | 0.1444 | 0.38 | 0.04859261 | 3.922682e-05 | 0.0005785757 | 0.5615711 | 1.971809, 0, 1.971809 | 3.888996 | 0.9999145 | 0 | false |
| Knee start | Yellow | 0.155637, 0.155637, 0 | 0.1444 | 0.38 | 0.0485926 | 3.922792e-05 | 0.0005785086 | 0.5615868 | 0.6052887, 0.6052887, 0 | 3.889105 | 0.9999426 | 0 | false |
| Knee start | Orange | 0.311933, 0.1091765, 0 | 0.1444 | 0.38 | 0.04859259 | 3.922721e-05 | 0.0005785812 | 0.5615767 | 1.213155, 0.4245804, 0 | 3.889035 | 0.9999245 | 7.177293e-06 | false |
| Knee start | White | 0.1444, 0.1444, 0.1444 | 0.1444 | 0.38 | 0.04859259 | 3.923017e-05 | 0.0005786028 | 0.5616191 | 0.5616191, 0.5616191, 0.5616191 | 3.889329 | 1 | 0 | false |
| Medium | Red | 1.271872, 0, 0 | 0.2704 | 0.52 | 0.4170096 | 0.0006303976 | 0.009296046 | 9.024773 | 42.44954, 0, 0 | 33.37564 | 1.000034 | 0 | false |
| Medium | Green | 0, 0.3780761, 0 | 0.2704 | 0.52 | 0.4170096 | 0.0006303897 | 0.009297223 | 9.024659 | 0, 12.61837, 0 | 33.37522 | 1.000021 | 0 | false |
| Medium | Blue | 0, 0, 3.745152 | 0.2704 | 0.52 | 0.4170096 | 0.0006303628 | 0.009298114 | 9.024274 | 0, 0, 124.9899 | 33.37379 | 0.9999783 | 0 | false |
| Medium | Cyan | 0, 0.3434087, 0.3434087 | 0.2704 | 0.52 | 0.4170096 | 0.000630347 | 0.009297823 | 9.024048 | 0, 11.46056, 11.46056 | 33.37296 | 0.9999533 | 0 | false |
| Medium | Magenta | 0.9494382, 0, 0.9494382 | 0.2704 | 0.52 | 0.4170096 | 0.0006303768 | 0.009296927 | 9.024475 | 31.68706, 0, 31.68706 | 33.37454 | 1.000001 | 0 | false |
| Medium | Yellow | 0.2914421, 0.2914421, 0 | 0.2704 | 0.52 | 0.4170096 | 0.0006303815 | 0.00929637 | 9.024541 | 9.726817, 9.726817, 0 | 33.37478 | 1.000008 | 0 | false |
| Medium | Orange | 0.5841182, 0.2044414, 0 | 0.2704 | 0.52 | 0.4170096 | 0.0006303717 | 0.00929713 | 9.024401 | 19.49538, 6.822822, 0 | 33.37426 | 0.9999924 | 1.055454e-05 | false |
| Medium | White | 0.2704, 0.2704, 0.2704 | 0.2704 | 0.52 | 0.4170096 | 0.0006303764 | 0.009297029 | 9.024469 | 9.024469, 9.024469, 9.024469 | 33.37452 | 1 | 5.551115e-17 | false |
| High | Red | 3.162747, 0, 0 | 0.6724 | 0.82 | 1 | 0.003758968 | 0.05543649 | 53.81338 | 253.1203, 0, 0 | 80.0318 | 1.000013 | 0 | false |
| High | Green | 0, 0.9401566, 0 | 0.6724 | 0.82 | 1 | 0.003759117 | 0.05544554 | 53.81552 | 0, 75.24542, 0 | 80.03498 | 1.000052 | 0 | false |
| High | Blue | 0, 0, 9.31302 | 0.6724 | 0.82 | 1 | 0.003759068 | 0.05543643 | 53.81481 | 0, 0, 745.3575 | 80.03393 | 1.000039 | 0 | false |
| High | Cyan | 0, 0.8539497, 0.8539497 | 0.6724 | 0.82 | 1 | 0.003758905 | 0.05544266 | 53.81248 | 0, 68.34199, 68.34199 | 80.03046 | 0.9999959 | 0 | false |
| High | Magenta | 2.360955, 0, 2.360955 | 0.6724 | 0.82 | 1 | 0.003759036 | 0.05544608 | 53.81436 | 188.9549, 0, 188.9549 | 80.03326 | 1.000031 | 0 | false |
| High | Yellow | 0.7247251, 0.7247251, 0 | 0.6724 | 0.82 | 1 | 0.003758944 | 0.05544092 | 53.81304 | 58.00069, 58.00069, 0 | 80.0313 | 1.000006 | 0 | false |
| High | Orange | 1.452519, 0.5083816, 0 | 0.6724 | 0.82 | 1 | 0.003758982 | 0.05544205 | 53.81358 | 116.2492, 40.68652, 0 | 80.03209 | 1.000016 | 2.254898e-06 | false |
| High | White | 0.6724, 0.6724, 0.6724 | 0.6724 | 0.82 | 1 | 0.00375892 | 0.05543884 | 53.8127 | 53.8127, 53.8127, 53.8127 | 80.03079 | 1 | 0 | false |

`energy/Y` is integrated annulus luminance divided by measured center-source Y; `relative efficiency` is that ratio divided by White at the same target. At Low SDR, both White and colors have no halo, so efficiency is omitted. Chromaticity is RGB/sum(RGB); error is mean absolute component difference. Below integrated halo Y=1e-6 it is omitted and `weak halo=true`. Exact source and halo chromaticity vectors plus the annulus pixel count are in the adjacent JSON.

## Equal RGB peak (diagnostic contrast)

| Level | Color | source RGB | Y | sqrt(Y) | gate | halo mean Y | halo peak Y | halo integrated Y | halo integrated RGB | energy/Y | relative efficiency | chroma error | weak halo |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| RGB peak 1 | Red | 1, 0, 0 | 0.2126 | 0.4610857 | 0.2332544 | 0.0002772187 | 0.004088633 | 3.968664 | 18.66728, 0, 0 | 18.66728 | — | 0 | false |
| RGB peak 1 | Green | 0, 1, 0 | 0.7152 | 0.845695 | 1 | 0.003998391 | 0.05897635 | 57.24096 | 0, 80.03491, 0 | 80.03491 | — | 0 | false |
| RGB peak 1 | Blue | 0, 0, 1 | 0.0722 | 0.2687006 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| RGB peak 1 | Cyan | 0, 1, 1 | 0.7874 | 0.8873556 | 1 | 0.004402032 | 0.06493006 | 63.01948 | 0, 80.03491, 80.03491 | 80.03491 | — | 0 | false |
| RGB peak 1 | Magenta | 1, 0, 1 | 0.2848 | 0.5336666 | 0.4622538 | 0.0007360024 | 0.0108567 | 10.53661 | 36.99652, 0, 36.99652 | 36.99652 | — | 0 | false |
| RGB peak 1 | Yellow | 1, 1, 0 | 0.9278 | 0.9632238 | 1 | 0.005186951 | 0.07650763 | 74.25638 | 80.03491, 80.03491, 0 | 80.03491 | — | 0 | false |
| RGB peak 1 | Orange | 1, 0.35, 0 | 0.46292 | 0.6803822 | 0.8968142 | 0.002320883 | 0.03422861 | 33.22577 | 71.77632, 25.12042, 0 | 71.77432 | — | 6.608554e-06 | false |
| RGB peak 1 | White | 1, 1, 1 | 1 | 1 | 1 | 0.005590591 | 0.08246134 | 80.03491 | 80.03491, 80.03491, 80.03491 | 80.03491 | — | 0 | false |

## Extended range, unclamped sources

| Level | Color | source RGB | Y | sqrt(Y) | gate | halo mean Y | halo peak Y | halo integrated Y | halo integrated RGB | energy/Y | relative efficiency | chroma error | weak halo |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| RGB peak 1 | Blue | 0, 0, 1 | 0.0722 | 0.2687006 | 0 | 0 | 0 | 0 | 0, 0, 0 | 0 | — | — | true |
| RGB peak 2 | Blue | 0, 0, 2 | 0.1444 | 0.38 | 0.04859259 | 3.922572e-05 | 0.0005784734 | 0.5615554 | 0, 0, 7.777776 | 3.888888 | — | 0 | false |
| RGB peak 4 | Blue | 0, 0, 4 | 0.2888 | 0.5374012 | 0.4746801 | 0.0007663887 | 0.011303 | 10.97162 | 0, 0, 151.9615 | 37.99038 | — | 0 | false |
| RGB peak 1 | White | 1, 1, 1 | 1 | 1 | 1 | 0.005590591 | 0.08246134 | 80.03491 | 80.03491, 80.03491, 80.03491 | 80.03491 | — | 0 | false |
| RGB peak 2 | White | 2, 2, 2 | 2 | 1.414214 | 1 | 0.01118118 | 0.1649227 | 160.0698 | 160.0698, 160.0698, 160.0698 | 80.03491 | — | 0 | false |
| RGB peak 4 | White | 4, 4, 4 | 4 | 2 | 1 | 0.02236237 | 0.3298454 | 320.1396 | 320.1396, 320.1396, 320.1396 | 80.03491 | — | 0 | false |

## Invariants and interpretation

Amount=0 max RGB error: 0; non-finite rendered source/halo pixels: 0. The gate curves are identical by construction when compared at the same Y. Medium-Y glow energy uses a documented ±25% quality heuristic against White, not a pass target for the renderer. Medium-Y color outside that tolerance: false. Any differences at equal Y would arise downstream of the gate through RGB diffusion/recombination/headroom; none exceeded the heuristic here. Radial profiles are peak-normalized for shape only, not energy.

[Equal-Y source/glow/difference](GlamourGlow/equal_luminance_color_glow.png) · [radial profiles](GlamourGlow/equal_luminance_color_glow_profile.png) · [gate curves](GlamourGlow/color_gate_response.png) · [neon scene](GlamourGlow/colored_neon_comparison.png).

## Conclusion

**A — TEST ISSUE**. The old blue warning is primarily explained by unequal luminance at equal RGB peak and a chromaticity sentinel on a zero halo. At equal medium luminance the measured glow energies remain within the documented comparison band; the old warning does not indicate a color-dependent gate.