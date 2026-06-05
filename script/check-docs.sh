#!/bin/bash
# Validate the docs build output.
# Fails on: asciidoctor warnings, missing expected outputs, missing search index,
# or any links to the upstream AeroSpace documentation host.
set -euo pipefail
cd "$(dirname "$0")/.."

errors=0

fail() {
    echo "ERROR: $*" >&2
    errors=$((errors + 1))
}

# ── 1. Required site output files ────────────────────────────────────────────
required_html=(
    .site/index.html
    .site/guide.html
    .site/commands.html
    .site/goodies.html
    .site/config-reference.html
    .site/compatibility.html
    .site/version.html
)
for f in "${required_html[@]}"; do
    test -f "$f" || fail "Missing expected site output: $f"
done

# ── 2. Pagefind search index ──────────────────────────────────────────────────
test -d .site/pagefind || fail "Missing Pagefind search index directory: .site/pagefind"
test -f .site/pagefind/pagefind.js || fail "Missing .site/pagefind/pagefind.js"

# ── 3. No links to upstream AeroSpace documentation host ────────────────────
# Retain issue links (github.com/nikitabobko/AeroSpace/issues) but reject
# the nikitabobko.github.io/AeroSpace documentation host.
upstream_host="nikitabobko.github.io"
if grep -rl "$upstream_host" .site/*.html 2>/dev/null | grep -q .; then
    echo "ERROR: Generated HTML links to upstream AeroSpace documentation host ($upstream_host):" >&2
    grep -rn "$upstream_host" .site/*.html >&2 || true
    errors=$((errors + 1))
fi

# Also check source docs for accidental upstream links
if grep -rn "$upstream_host" docs/ --include="*.adoc" --include="*.toml" 2>/dev/null | grep -q .; then
    echo "ERROR: Source docs still contain links to $upstream_host:" >&2
    grep -rn "$upstream_host" docs/ --include="*.adoc" --include="*.toml" >&2 || true
    errors=$((errors + 1))
fi

# ── 4. Report ─────────────────────────────────────────────────────────────────
if test "$errors" -gt 0; then
    echo "$errors check(s) failed." >&2
    exit 1
fi
echo "Docs checks passed."
