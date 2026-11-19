#!/usr/bin/env bash
# Usage : scripts/set_image_tag.sh <dev|staging|prod> <tag>
set -euo pipefail
OVERLAY="$1"; TAG="$2"
FILE="k8s/overlays/${OVERLAY}/kustomization.yaml"
sed -i -E "s|(newTag:).*|\1 \"${TAG}\"|" "$FILE"
echo "Overlay ${OVERLAY} -> ${TAG}"
