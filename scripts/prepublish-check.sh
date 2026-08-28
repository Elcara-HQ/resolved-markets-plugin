#!/usr/bin/env bash
# Verifies this folder is safe and self-contained before it is published.
# Run from anywhere: ./scripts/prepublish-check.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fail=0
note() { printf '  %s\n' "$1"; }
ok()   { printf 'ok    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }

scan() { grep -rIn --exclude-dir=.git --exclude-dir=dist --exclude-dir=node_modules "$@" . 2>/dev/null; }

echo "== 1. no real API keys =="
# A placeholder is rm_your_key_here; a real key is a long hex string.
if hits=$(scan -E 'rm_[0-9a-f]{16,}'); then
  bad "possible live API key"; note "$hits"
else ok "no rm_ key material"; fi

echo "== 2. no machine-specific or escaping paths =="
esc='\.\.'"/"'\.\.'
pat="/User""s/|/hom""e/[a-z]|$esc"
if hits=$(scan -E "$pat"); then
  bad "absolute or escaping path"; note "$hits"
else ok "all paths are self-contained"; fi

echo "== 3. no symlinks =="
if hits=$(find . -path ./.git -prune -o -type l -print 2>/dev/null | grep -v '^$'); then
  bad "symlink found"; note "$hits"
else ok "no symlinks"; fi

echo "== 4. no env or secret files =="
if hits=$(find . -path ./.git -prune -o \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name 'settings.local.json' \) -print 2>/dev/null | grep -v '^$'); then
  bad "secret-bearing file"; note "$hits"
else ok "no env/secret files"; fi

echo "== 5. no top-level bin/ (rejected by claude.ai) =="
if [ -d plugins/resolved-markets/bin ]; then bad "plugins/resolved-markets/bin exists"; else ok "no bin/"; fi

echo "== 6. manifests parse =="
for f in .claude-plugin/marketplace.json plugins/resolved-markets/.claude-plugin/plugin.json plugins/resolved-markets/.mcp.json; do
  if python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null; then ok "$f"; else bad "$f is not valid JSON"; fi
done

echo "== 7. every SKILL.md has frontmatter and stays under 500 lines =="
while IFS= read -r s; do
  n=$(wc -l < "$s" | tr -d ' ')
  head -1 "$s" | grep -q '^---$' || bad "$s missing frontmatter"
  grep -q '^description:' "$s" || bad "$s has no description"
  if [ "$n" -gt 500 ]; then bad "$s is $n lines (cap 500)"; else ok "$s ($n lines)"; fi
done < <(find plugins -name SKILL.md)

echo "== 8. every skill's reference links resolve from its own directory =="
missing=0
for s in plugins/resolved-markets/skills/*/SKILL.md; do
  d=$(dirname "$s")
  for ref in $(grep -oE 'references/[a-z-]+\.md' "$s" | sort -u); do
    [ -f "$d/$ref" ] || { bad "$s cites $ref but $d/$ref is missing"; missing=1; }
  done
done
[ "$missing" = "0" ] && ok "all reference links resolve"

echo "== 8b. duplicated references identical across skills (drift) =="
drift=0
for f in $(find plugins/resolved-markets/skills -path '*/references/*' -name '*.md' -exec basename {} \; | sort -u); do
  n=$(find plugins/resolved-markets/skills -path '*/references/*' -name "$f" | wc -l | tr -d ' ')
  u=$(find plugins/resolved-markets/skills -path '*/references/*' -name "$f" -exec shasum {} \; | awk '{print $1}' | sort -u | wc -l | tr -d ' ')
  if [ "$n" -gt 1 ] && [ "$u" -gt 1 ]; then bad "$f differs across its $n copies"; drift=1; fi
done
[ "$drift" = "0" ] && ok "no drift between duplicated references"

echo "== 9. plugin validation =="
if command -v claude >/dev/null 2>&1; then
  claude plugin validate --strict plugins/resolved-markets || bad "claude plugin validate failed"
else
  note "claude CLI not on PATH — skipped (run it before releasing)"
fi

echo
if [ "$fail" -eq 0 ]; then echo "PASS — safe to publish."; else echo "FAILED — fix the items above."; fi
exit "$fail"
