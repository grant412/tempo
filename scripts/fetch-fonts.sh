#!/bin/zsh
# Downloads the three OFL families from github.com/google/fonts into Resources/Fonts.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Resources/Fonts
for dir in bricolagegrotesque geist geistmono; do
  curl -fsSL "https://api.github.com/repos/google/fonts/contents/ofl/$dir" \
  | python3 -c '
import json, sys
for f in json.load(sys.stdin):
    n = f["name"]
    if n.endswith(".ttf") or n == "OFL.txt":
        print(n + "\t" + f["download_url"])' \
  | while IFS=$'\t' read -r name url; do
      [[ "$name" == "OFL.txt" ]] && name="$dir-OFL.txt"
      curl -fsSL -o "Resources/Fonts/$name" "$url"
      echo "fetched $name"
    done
done
