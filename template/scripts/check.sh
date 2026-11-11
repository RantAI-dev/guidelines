#!/usr/bin/env bash
# The one gate. People, agents, the pre-commit hook and CI all run this file, so "green" means the
# same thing everywhere. Edit the CONFIGURE block for this repo and leave the interface alone.
#
#   scripts/check.sh             every stack (what CI runs)
#   scripts/check.sh --changed   only the stacks touched since the merge base with the main branch
#   scripts/check.sh --staged    fast format and lint for staged files (pre-commit)
#
# Passing steps print one line. A failing step prints the tail of its output, because an agent
# reads every line this script prints.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

# ---- CONFIGURE ----------------------------------------------------------------------------------
# One block per stack: a path regex that says "this stack was touched", the full check, and the
# fast check for pre-commit. Delete the stacks this repo does not have.
BASE_REF="${CHECK_BASE:-origin/main}"
TAIL_LINES="${CHECK_TAIL:-60}"

ts_paths='\.(ts|tsx|js|jsx|mjs|cjs)$|(^|/)(package\.json|bun\.lock|tsconfig[^/]*\.json|biome\.json)$'
ts_full()  { bun run typecheck && bun run lint && bun run boundaries && bun run test; }
ts_fast()  { bunx biome check --staged --no-errors-on-unmatched; }

rust_paths='^rust/|(^|/)Cargo\.(toml|lock)$'
rust_full() { (cd rust && cargo fmt --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace); }
rust_fast() { (cd rust && cargo fmt --check); }

py_paths='\.py$|(^|/)(pyproject\.toml|uv\.lock)$'
py_full()  { ruff check . && ruff format --check . && python -m pytest -q; }
py_fast()  { ruff check . && ruff format --check .; }

STACKS=(ts rust py)
# -------------------------------------------------------------------------------------------------

mode=full
case "${1:-}" in
  --changed) mode=changed ;;
  --staged)  mode=staged ;;
  "" ) ;;
  *) echo "usage: scripts/check.sh [--changed|--staged]" >&2; exit 2 ;;
esac

files=""
if [ "$mode" = changed ]; then
  base="$(git merge-base HEAD "$BASE_REF" 2>/dev/null || git rev-list --max-parents=0 HEAD | tail -1)"
  files="$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u)"
elif [ "$mode" = staged ]; then
  files="$(git diff --cached --name-only --diff-filter=ACMR)"
fi

touched() {  # stack name -> 0 when the stack should run
  local var="$1_paths"
  [ "$mode" = full ] && { git ls-files | grep -Eq "${!var}"; return; }
  printf '%s\n' "$files" | grep -Eq "${!var}"
}

log="$(mktemp)"; trap 'rm -f "$log"' EXIT
ran=(); failed=()
for stack in "${STACKS[@]}"; do
  touched "$stack" || continue
  fn="${stack}_full"; [ "$mode" = staged ] && fn="${stack}_fast"
  start=$SECONDS
  if "$fn" >"$log" 2>&1; then
    echo "check: $stack ok ($((SECONDS - start))s)"
  else
    echo "check: $stack FAILED ($((SECONDS - start))s) — last $TAIL_LINES lines:"
    tail -n "$TAIL_LINES" "$log"
    failed+=("$stack")
  fi
  ran+=("$stack")
done

# File size: a source file over the limit fails; one already over it may only shrink. Always runs.
if [ -x scripts/file-size.sh ]; then
  if scripts/file-size.sh >"$log" 2>&1; then echo "check: size ok"; else cat "$log"; failed+=("size"); fi
  ran+=("size")
fi

# The ratchet: counts that may fall but never rise. Skipped in the fast pre-commit mode.
if [ "$mode" != staged ] && [ -x scripts/ratchet.sh ] && grep -qEv '^[[:space:]]*(#|$)' .agents/ratchet.tsv 2>/dev/null; then
  if scripts/ratchet.sh >"$log" 2>&1; then echo "check: ratchet ok"; else cat "$log"; failed+=("ratchet"); fi
  ran+=("ratchet")
fi

if [ "${#ran[@]}" -eq 0 ]; then echo "check: nothing to run ($mode)"; exit 0; fi
if [ "${#failed[@]}" -gt 0 ]; then echo "check: FAIL (${failed[*]})"; exit 1; fi
echo "check: PASS (${ran[*]}; $mode)"
