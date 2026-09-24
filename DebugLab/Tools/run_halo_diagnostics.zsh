#!/bin/zsh
set -euo pipefail

tool_dir=${0:A:h}
repo_root=${tool_dir:h:h}
scratch_dir=$(mktemp -d /private/tmp/lumora-halo.XXXXXX)
trap 'rm -rf "$scratch_dir"' EXIT

# The Debug Lab uses ImageAnalysis, but the remainder of AutoAnalysis.swift
# depends on production render types. Extract exactly that standalone struct;
# do not change or duplicate its implementation in this diagnostic tool.
awk '/^struct AutoCorrectionIntent/{exit} {print}' \
  "$repo_root/Lumora/Adjustments/AutoAnalysis.swift" > "$scratch_dir/ImageAnalysis.swift"

source_files=(
  "$scratch_dir/ImageAnalysis.swift"
  "$repo_root/Lumora/UI/DebugLabBitmap.swift"
  "$repo_root/Lumora/UI/DebugAdaptiveToneMetal.swift"
  "$repo_root/Lumora/UI/DebugPhase1Reference.swift"
  "$repo_root/Lumora/UI/DebugPhase4Importance.swift"
  "$repo_root/Lumora/UI/DebugSceneAnalysis.swift"
  "$repo_root/Lumora/UI/DebugAdaptiveToneLab.swift"
  "$repo_root/Lumora/UI/DebugHaloDiagnostics.swift"
)

mode=${1:-}
case "$mode" in
  synthetic)
    entry="$tool_dir/DebugHaloSynthetic.swift"
    ;;
  portrait-context)
    entry="$tool_dir/DebugPortraitContext.swift"
    ;;
  corpus|highres)
    entry="$tool_dir/DebugHaloCorpusRunner.swift"
    ;;
  overlay)
    entry="$tool_dir/DebugHaloOverlayExport.swift"
    ;;
  *)
    print -u2 'Usage: run_halo_diagnostics.zsh synthetic|portrait-context|corpus|highres|overlay [output original processed]'
    exit 2
    ;;
esac

swiftc -D DEBUG -O -parse-as-library "${source_files[@]}" "$entry" -o "$scratch_dir/diagnostic"
cd "$repo_root"
case "$mode" in
  synthetic)
    "$scratch_dir/diagnostic"
    ;;
  portrait-context)
    "$scratch_dir/diagnostic"
    ;;
  corpus)
    "$scratch_dir/diagnostic" DebugLab/HaloCorpus 512 \
      AdaptiveTone/Baseline/VisualTestAssets_*.png AutoStressCorpus/0[1-8]_*.png
    ;;
  highres)
    "$scratch_dir/diagnostic" DebugLab/HaloHighRes 1024 \
      AdaptiveTone/Baseline/VisualTestAssets_{01,03,04,07}*.png AutoStressCorpus/{01,05}*.png
    ;;
  overlay)
    "$scratch_dir/diagnostic" "${2:?output directory}" "${3:?original PNG}" "${4:?processed PNG}"
    ;;
esac
