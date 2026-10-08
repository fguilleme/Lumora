#!/bin/zsh
set -eu
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
validation_dir="$repo_root/Validation/RelightingPhases"
xcrun swiftc -O -o /tmp/lumora-relight-probe \
    "$validation_dir/Sources/RelightProbe.swift" "$validation_dir/Sources/LegacyLightingRenderer.swift" \
    "$repo_root/Lumora/Adjustments/DepthLightingSettings.swift" \
    "$repo_root/Lumora/Rendering/DepthLighting/DepthLightingRenderer.swift" \
    "$repo_root/Lumora/Rendering/DepthLighting/DepthLightingLegacyRenderer.swift" \
    "$repo_root/Lumora/Rendering/DepthLighting/DepthLightingGradient.swift" \
    "$repo_root/Lumora/Rendering/DepthLighting/DepthLightingMaterials.swift" \
    "$repo_root/Lumora/Rendering/DepthLighting/MoGeNormalEstimator.swift"
/tmp/lumora-relight-probe "$repo_root"
