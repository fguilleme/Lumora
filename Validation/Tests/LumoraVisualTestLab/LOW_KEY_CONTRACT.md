# Low Key photographic validation contract

All classification and measurement uses input luminance in extended linear sRGB,
read back as floating-point pixels from the production Creative stack. No reference
renderer or effect-formula copy is used.

| Zone | Input luminance |
| --- | --- |
| Deep shadows | [0.00, 0.10) |
| Shadows | [0.10, 0.30) |
| Midtones | [0.30, 0.65) |
| Bright tones | [0.65, 0.90) |
| Specular whites | [0.95, 1.00] |

The 0.90–0.95 transition is intentionally excluded from named-zone averages, but
included in the full-ramp curves, finiteness, monotonicity and darkening centroid.
Zone classification uses source values, never output values. Measurements sample
the uniform full ramp; the same transform is spatially constant on this neutral
source with glow disabled. Sample counts and input/output means are exported.

- Absolute change: mean(output − input), signed linear luminance units.
- Relative change: absolute change / mean(input), not mean pixel-wise ratios.
- Plot intensity: positive input − output (and a separate relative-intensity plot).
- Darkening centroid: sum(input × max(0, input − output)) / sum(max(0, input − output)),
  over the entire [0,1] ramp. This must move right as Dynamic increases.

The isolated sweep uses Amount=60%, Dynamic=0/25/50/75/100%, opacity=100%,
darkProtection=65%, lightProtection=70%, contrast=saturation=glow=0,
glowRadius=30%, glowThreshold=70%, no mask. Every other effect field is frozen;
parameter equality is asserted after resetting only Dynamic to zero.

Each successive Dynamic step must reduce deep-shadow/shadow action and increase
bright-tone action, in both absolute and relative measures, by more than 1e-6.
These photographic expectations produce WARN if absent, never a forced PASS.
Specular preservation is a separate observation: specular relative action should
be below bright-tone relative action at the fixed protection setting. This is
not a causal test of changing lightProtection and imposes no shadow/specular
ordering. Baseline Dynamic=0 has no preceding-step comparison.

NaN/Inf anywhere in RGBA, any adjacent-ramp decrease beyond 1e-6, or brightening
above input beyond 1e-6 is a hard failure. No inversion-count allowance is used
for the isolated sweep.

LK01/LK02/LK03 and their original settings remain. Their old [0.90,1] measurement
is now named `legacy-specular-high-end-response-relativeChange`; the original
historical ordering check remains visible with its original outcome. It does not
represent the general bright-tone contract. Historical shadows [0,.1] and midtones
[.4,.6] remain separately labeled as ramp metrics; all five new zones are also
reported for the existing Low Key scenarios.

Artifacts: `Validation/TestArtifacts/CreativeFXValidationReport.md`,
`Reports/LK_DynamicSweep_*_{settings,ramp}.json`, `Reports/LK_dynamic_zones.json`,
`LowKey/dynamic_luminance_{absolute,relative}.png`, `LowKey/dynamic_transfer.png`,
and `LowKey/dynamic_contact_sheet.png`.

Run the full lab with `Validation/Scripts/run_visual_validation.sh`. No golden is accepted
or renderer parameter changed by this contract.
