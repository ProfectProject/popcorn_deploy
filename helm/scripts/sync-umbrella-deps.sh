#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_CHARTS_DIR="${HELM_DIR}/charts"
UMBRELLA_DIR="${HELM_DIR}/popcorn-umbrella"
UMBRELLA_CHARTS_DIR="${UMBRELLA_DIR}/charts"

if ! command -v helm >/dev/null 2>&1; then
  echo "helm command not found"
  exit 1
fi

echo "[sync] packaging local charts into ${UMBRELLA_CHARTS_DIR}"

for chart_dir in "${SOURCE_CHARTS_DIR}"/*; do
  if [[ -d "${chart_dir}" && -f "${chart_dir}/Chart.yaml" ]]; then
    helm package "${chart_dir}" --destination "${UMBRELLA_CHARTS_DIR}" >/dev/null
    echo "[sync] packaged $(basename "${chart_dir}")"
  fi
done

echo "[sync] done"
