#!/usr/bin/env bash
# Remplace actions/xxx@v4 par actions/xxx@<sha> # v4 dans un workflow.
set -euo pipefail
FILE="${1:-.github/workflows/ci-cd.yml}"
grep -oE 'uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@v[0-9][A-Za-z0-9._-]*' "$FILE" \
  | sed 's/uses: //' | sort -u | while read -r ref; do
  repo="${ref%@*}"; tag="${ref#*@}"
  owner_repo=$(echo "$repo" | cut -d/ -f1,2)
  sha=$(git ls-remote "https://github.com/${owner_repo}.git" "refs/tags/${tag}^{}" | awk '{print $1}')
  [ -z "$sha" ] && sha=$(git ls-remote "https://github.com/${owner_repo}.git" "refs/tags/${tag}" | awk '{print $1}')
  [ -z "$sha" ] && { echo "SHA introuvable pour $ref"; exit 1; }
  sed -i "s|uses: ${ref}\$|uses: ${repo}@${sha} # ${tag}|" "$FILE"
  echo "$ref -> $sha"
done
