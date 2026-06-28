#!/usr/bin/env bash
# scripts/render-appprojects.sh
# ----------------------------------------------------------------------------
# Regenerates the committed rendered AppProject YAML files under
# apps/appprojects/rendered/ from the Helm chart at apps/appprojects/.
#
# Usage:
#   bash scripts/render-appprojects.sh
#
# After running, diff the rendered/ files and commit if they changed.
# ----------------------------------------------------------------------------
set -euo pipefail

CHART_DIR="apps/appprojects"
OUTPUT_DIR="${CHART_DIR}/rendered"

# Ensure the output directory exists
mkdir -p "${OUTPUT_DIR}"

# Render the chart and split into one file per AppProject.
# Each AppProject is separated by "---" in the Helm output. We use csplit
# to split them into individual files by matching the "apiVersion" line.
helm template "${CHART_DIR}" -s templates/appproject.yaml \
  | csplit -sz -f "${OUTPUT_DIR}/tmp-" - '/^---$/' '{*}'

# Rename the split files based on the AppProject name.
# The template emits projects in the order defined in values.yaml:
#   0 → infrastructure, 1 → platform, 2 → workloads
declare -A NAMES=(
  [0]="infrastructure"
  [1]="platform"
  [2]="workloads"
)

# Remove old files
rm -f "${OUTPUT_DIR}/infrastructure.yaml" \
      "${OUTPUT_DIR}/platform.yaml" \
      "${OUTPUT_DIR}/workloads.yaml"

# Rename split files
for i in "${!NAMES[@]}"; do
  src="${OUTPUT_DIR}/tmp-${i}"
  dst="${OUTPUT_DIR}/${NAMES[$i]}.yaml"
  if [ -f "$src" ]; then
    mv "$src" "$dst"
    echo "  wrote ${dst}"
  fi
done

# Cleanup any leftover tmp files
rm -f "${OUTPUT_DIR}/tmp-"*

echo "Done. ${OUTPUT_DIR} updated."
