#!/usr/bin/env bash
# Writes one version to every file that carries it, the same files
# release-please-config.json lists as extra-files.
# Usage: scripts/set-version.sh 0.2.0
# $v in the jq filters below is a jq variable, not a shell one.
# shellcheck disable=SC2016
set -euo pipefail

version="${1:-}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 X.Y.Z" >&2
  exit 1
fi

cd "$(git rev-parse --show-toplevel)"

printf '%s # x-release-please-version\n' "$version" > VERSION

set_json() { # file jq-filter
  local tmp
  tmp="$(mktemp)"
  jq --arg v "$version" "$2" "$1" > "$tmp"
  mv "$tmp" "$1"
}

set_json package.json '.version = $v'
set_json .claude-plugin/plugin.json '.version = $v'
set_json .claude-plugin/marketplace.json '.metadata.version = $v | .plugins[0].version = $v'
set_json .release-please-manifest.json '.["."] = $v'

echo "set-version: $version written to VERSION, package.json, plugin.json, marketplace.json and the release-please manifest"
