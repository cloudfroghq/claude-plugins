#!/usr/bin/env bash
# Validates the marketplace entries that `claude plugin validate` cannot check:
# archive checksums, git-subdir pins and the transport/credential rules of every .mcp.json.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root/.claude-plugin/marketplace.json"
fail=0

err() {
  printf 'error: %s\n' "$*" >&2
  fail=1
}

command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
[ -f "$manifest" ] || { echo "missing $manifest" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

sha256_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# 1. archive entries: sha256(zip) == entry.sha256 == the checksums.txt line of the same release.
while IFS=$'\t' read -r name url want; do
  [ -n "$name" ] || continue
  file="$tmp/${name}.zip"
  if ! curl -fsSL --proto '=https' -o "$file" "$url"; then
    err "$name: cannot download $url"
    continue
  fi
  got="$(sha256_of "$file")"
  [ "$got" = "$want" ] || err "$name: entry sha256 $want does not match the downloaded archive ($got)"
  base="${url%/*}"
  asset="${url##*/}"
  if curl -fsSL --proto '=https' -o "$tmp/${name}.checksums" "$base/checksums.txt"; then
    line="$(awk -v a="$asset" '$2 == a { print $1 }' "$tmp/${name}.checksums")"
    [ -n "$line" ] || err "$name: $asset is not listed in checksums.txt"
    [ -z "$line" ] || [ "$line" = "$want" ] || err "$name: checksums.txt says $line, the entry says $want"
  else
    err "$name: cannot download $base/checksums.txt"
  fi
done < <(jq -r '.plugins[] | select((.source | type) == "object" and .source.source == "archive") | [.name, .source.url, .source.sha256] | @tsv' "$manifest")

# 2. git-subdir entries: ref is a v<semver> tag and sha is a lowercase 40-hex commit.
while IFS=$'\t' read -r name ref sha; do
  [ -n "$name" ] || continue
  [[ "$ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || err "$name: ref '$ref' is not a v<semver> tag"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || err "$name: sha '$sha' is not a 40-hex commit"
done < <(jq -r '.plugins[] | select((.source | type) == "object" and .source.source == "git-subdir") | [.name, (.source.ref // ""), (.source.sha // "")] | @tsv' "$manifest")

# 3. no entry carries a version (plugin.json wins) and every entry has a description.
jq -e '[.plugins[] | select(has("version"))] | length == 0' "$manifest" >/dev/null || err "marketplace entries must not set version"
jq -e '[.plugins[] | select((.description // "") == "")] | length == 0' "$manifest" >/dev/null || err "every marketplace entry needs a description"

# 4. .mcp.json files: HTTPS only, and the only credential allowed is a user_config reference.
while IFS= read -r f; do
  if grep -nE "http://" "$f" >/dev/null; then
    err "$f: contains a plain http:// URL"
  fi
  if grep -E 'Bearer ' "$f" | grep -vE 'Bearer \$\{user_config\.[a-z_]+\}' >/dev/null; then
    err "$f: contains a Bearer value that is not a user_config reference"
  fi
done < <(find "$root/plugins" -name .mcp.json -type f)

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "marketplace entries ok"
