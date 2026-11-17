#!/bin/sh
# Checks that the fork patches survive every upstream merge: system fonts are the
# default, no shipped asset loads Google Fonts, the PNG export blocks remote hosts.
# Run from anywhere: sh tools/fork-guard.sh
set -eu

cd "$(dirname "$0")/.."

SKILL=skills/diagram-design
STYLE=$SKILL/references/style-guide.md
EXPORT=$SKILL/scripts/export_png.py

fail() {
  echo "fork-guard: $1" >&2
  exit 1
}

# 1. Default font source stays system.
grep -q '^Font source: `system`$' "$STYLE" ||
  fail "style-guide.md: 'Font source: \`system\`' fehlt"
! grep -q '^Font source: `web`' "$STYLE" ||
  fail "style-guide.md: Font source steht wieder auf web"
grep -q '^| `system` (default) |' "$STYLE" ||
  fail "style-guide.md: system ist nicht mehr als Default markiert"
grep -q 'Default font source is `system`' $SKILL/SKILL.md ||
  fail "SKILL.md: Default-Hinweis auf system fehlt"
grep -q '(`system`)' $SKILL/references/profiles.md ||
  fail "profiles.md: Pristine-Check erwartet nicht mehr system"

# 2. PNG export blocks every request except file: and data:.
grep -q 'fork-patch' "$EXPORT" ||
  fail "export_png.py: fork-patch-Marker fehlt"
grep -q 'LOCAL_SCHEMES = ("file:", "data:")' "$EXPORT" ||
  fail "export_png.py: Schema-Allowlist file:/data: fehlt"
grep -q 'route.abort()' "$EXPORT" ||
  fail "export_png.py: route.abort() fehlt"
grep -q 'context.route("\*\*/\*", block_remote)' "$EXPORT" ||
  fail "export_png.py: context.route(...) fehlt"
! grep -q 'browser.new_page(' "$EXPORT" ||
  fail "export_png.py: browser.new_page() umgeht den Context mit der Route-Sperre"

# 3. No shipped asset loads Google Fonts (any HTML under skills/).
hits=$(grep -rlE 'fonts\.(googleapis|gstatic)\.com' "$SKILL/assets" || true)
[ -z "$hits" ] ||
  fail "Google-Fonts-Referenz in Assets: $(echo "$hits" | head -3 | tr '\n' ' ')"

# 4. Docs may show the css2 link only as clearly marked opt-in: the word "opt-in"
#    must stand within the three lines above every css2 URL in a .md file.
bad=$(find skills commands -name '*.md' -exec awk '
  { l3 = l2; l2 = l1; l1 = prev; prev = $0 }
  /fonts\.googleapis\.com\/css2/ {
    if (tolower(l1 "\n" l2 "\n" l3 "\n" $0) !~ /opt-in/) print FILENAME ":" FNR
  }' {} + || true)
[ -z "$bad" ] ||
  fail "css2-Link ohne opt-in-Kennzeichnung: $(echo "$bad" | head -3 | tr '\n' ' ')"

echo "fork-guard: Fork-Patches vorhanden"
