#!/usr/bin/env bash
# The one gate. People, agents, the pre-commit hook and CI all run this file, so "green" means the
# same thing everywhere. Edit the CONFIGURE block for this repo and leave the interface alone.
#
#   scripts/check.sh                  every part (CI on main, nightly, and before a release)
#   scripts/check.sh --changed        only the parts the files changed since the merge base can affect
#   scripts/check.sh --staged         fast format and lint for staged files (pre-commit)
#   scripts/check.sh --plan [--changed]   print the parts that would run, as a JSON list (CI matrix)
#   scripts/check.sh --part NAME      run one part; "repo" is the checks for the whole repository
#
# Passing steps print one line. A failing step prints the tail of its output, because an agent
# reads every line this script prints.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

# ---- CONFIGURE ----------------------------------------------------------------------------------
BASE_REF="${CHECK_BASE:-origin/main}"
TAIL_LINES="${CHECK_TAIL:-60}"
# Time budgets in seconds, for a run with warm caches. Over budget prints a SLOW line and does not
# fail here, because a busy machine would make that flaky; CI enforces its own limit with
# timeout-minutes. Lower them if you can. Raising one is the owner's decision.
BUDGET_FULL="${CHECK_BUDGET_FULL:-600}"
BUDGET_CHANGED="${CHECK_BUDGET_CHANGED:-120}"
BUDGET_STAGED="${CHECK_BUDGET_STAGED:-15}"

# Parts. A part is a set of files and the checks that can break when they change: a whole stack to
# start with, later one crate or package group each, so a change rebuilds and tests only its part.
# For each name in PARTS define <name>_paths (an extended regex over repository paths), <name>_full
# and <name>_fast. Delete the parts this repo does not have.
ts_paths='\.(ts|tsx|js|jsx|mjs|cjs)$|(^|/)(package\.json|bun\.lock|tsconfig[^/]*\.json|biome\.json)$'
ts_full()  { bun run typecheck && bun run lint && bun run boundaries && bun run test; }
ts_fast()  { bunx biome check --staged --no-errors-on-unmatched; }

rust_paths='^rust/|(^|/)Cargo\.(toml|lock)$'
rust_full() { (cd rust && cargo fmt --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace); }
rust_fast() { (cd rust && cargo fmt --check); }
# Split by crate once the workspace has several, for example:
#   rust_ingest_paths='^rust/crates/ingest/'
#   rust_ingest_full() { (cd rust && cargo clippy -p ingest --all-targets -- -D warnings && cargo test -p ingest); }
# and list the crates every other crate depends on (core types, the workspace Cargo.toml and
# Cargo.lock) in ALL_PATHS. A crate's part must also cover the crates that depend on it.

py_paths='\.py$|(^|/)(pyproject\.toml|uv\.lock)$'
py_full()  { ruff check . && ruff format --check . && python -m pytest -q; }
py_fast()  { ruff check . && ruff format --check .; }

PARTS=(ts rust py)

# A changed file here can affect every part, so --changed runs all of them.
ALL_PATHS='^scripts/|^\.github/|^\.agents/|^\.githooks/|^\.env\.example$|(^|/)Dockerfile|^compose|^migrations/'
# A changed file here affects no part (the repository checks still run).
NO_PATHS='\.md$|^docs/|^LICENSE|^\.gitignore$|^\.claude/|^\.opencode/|^opencode\.json$|^t3\.json$'
# Any other file that no part claims selects every part: an unknown path means everything.
# -------------------------------------------------------------------------------------------------

mode=full; plan=0; only=""
while [ $# -gt 0 ]; do
  case "$1" in
    --changed) mode=changed ;;
    --staged)  mode=staged ;;
    --plan)    plan=1 ;;
    --part)    only="${2:-}"; [ -n "$only" ] || { echo "check: --part needs a name" >&2; exit 2; }; shift ;;
    *) echo "usage: scripts/check.sh [--changed|--staged] [--plan] [--part NAME]" >&2; exit 2 ;;
  esac
  shift
done

for part in "${PARTS[@]}"; do  # a part with a missing piece would be skipped without a word
  var="${part}_paths"
  [ -n "${!var:-}" ] && declare -F "${part}_full" >/dev/null && declare -F "${part}_fast" >/dev/null \
    || { echo "check: part $part needs ${part}_paths, ${part}_full and ${part}_fast in the CONFIGURE block" >&2; exit 2; }
done
if [ -n "$only" ] && [ "$only" != repo ] && [[ " ${PARTS[*]} " != *" $only "* ]]; then
  echo "check: no part named $only (parts: ${PARTS[*]} repo)" >&2; exit 2
fi

files=""
if [ "$mode" = changed ]; then
  if base="$(git merge-base HEAD "$BASE_REF" 2>/dev/null)"; then
    files="$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u)"
  else
    echo "check: cannot find the merge base with $BASE_REF, so every part runs" >&2; mode=full
  fi
elif [ "$mode" = staged ]; then
  files="$(git diff --cached --name-only --diff-filter=ACMR)"
fi

# Which parts run. In --changed mode this fails closed: a shared or unknown file selects them all.
present() { local var="$1_paths"; git ls-files | grep -Eq "${!var}"; }
claims()  { local var="$1_paths"; printf '%s\n' "$2" | grep -Eq "${!var}"; }
selected=()
if [ "$mode" = changed ]; then
  every=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if printf '%s\n' "$f" | grep -Eq "$ALL_PATHS"; then every=1; break; fi
    hit=0; for part in "${PARTS[@]}"; do claims "$part" "$f" && hit=1; done
    [ "$hit" -eq 1 ] && continue
    printf '%s\n' "$f" | grep -Eq "$NO_PATHS" && continue
    echo "check: no part claims $f, so every part runs. Add it to a part, ALL_PATHS or NO_PATHS." >&2
    every=1; break
  done <<<"$files"
  for part in "${PARTS[@]}"; do
    if [ "$every" -eq 1 ]; then present "$part" && selected+=("$part")
    elif printf '%s\n' "$files" | grep -Eq "$(v="${part}_paths"; echo "${!v}")"; then selected+=("$part"); fi
  done
else
  for part in "${PARTS[@]}"; do
    if [ "$mode" = staged ]; then claims "$part" "$files" && selected+=("$part")
    else present "$part" && selected+=("$part"); fi
  done
fi
[ -n "$only" ] && { [ "$only" = repo ] && selected=() || selected=("$only"); }

if [ "$plan" -eq 1 ]; then
  printf '["repo"'; for part in "${selected[@]}"; do printf ',"%s"' "$part"; done; printf ']\n'; exit 0
fi

log="$(mktemp)"; trap 'rm -f "$log"' EXIT
ran=(); failed=()
for part in "${selected[@]}"; do
  fn="${part}_full"; [ "$mode" = staged ] && fn="${part}_fast"
  start=$SECONDS
  if "$fn" >"$log" 2>&1; then
    echo "check: $part ok ($((SECONDS - start))s)"
  else
    echo "check: $part FAILED ($((SECONDS - start))s) — last $TAIL_LINES lines:"
    tail -n "$TAIL_LINES" "$log"
    failed+=("$part")
  fi
  ran+=("$part")
done

# The checks for the whole repository: always, unless one other part was asked for.
if [ -z "$only" ] || [ "$only" = repo ]; then
  # File size: a source file over the limit fails; one already over it may only shrink. Always runs.
  if [ -x scripts/file-size.sh ]; then
    if scripts/file-size.sh >"$log" 2>&1; then echo "check: size ok"; else cat "$log"; failed+=("size"); fi
    ran+=("size")
  fi

  # Error codes: the registry is valid, published codes are unchanged, generated files are current.
  if [ -x scripts/error-codes.sh ] && [ -f .agents/error-codes.tsv ]; then
    if scripts/error-codes.sh >"$log" 2>&1; then echo "check: errors ok"; else cat "$log"; failed+=("errors"); fi
    ran+=("errors")
  fi

  # The ratchet: counts that may fall but never rise. Skipped in the fast pre-commit mode.
  if [ "$mode" != staged ] && [ -x scripts/ratchet.sh ] && grep -qEv '^[[:space:]]*(#|$)' .agents/ratchet.tsv 2>/dev/null; then
    if scripts/ratchet.sh >"$log" 2>&1; then echo "check: ratchet ok"; else cat "$log"; failed+=("ratchet"); fi
    ran+=("ratchet")
  fi
fi

if [ "${#ran[@]}" -eq 0 ]; then echo "check: nothing to run ($mode)"; exit 0; fi
total=$SECONDS
case "$mode" in changed) budget=$BUDGET_CHANGED ;; staged) budget=$BUDGET_STAGED ;; *) budget=$BUDGET_FULL ;; esac
if [ "$total" -gt "$budget" ]; then
  echo "check: SLOW ($mode took ${total}s; the budget is ${budget}s). The slowest step is in the lines above."
  echo "       Make it faster by caching, by splitting a crate or package so less is rebuilt, or by asking the"
  echo "       owner to move a slow suite to the nightly job. Never by removing or skipping a test. Report it in your handoff."
fi
if [ "${#failed[@]}" -gt 0 ]; then echo "check: FAIL (${failed[*]}; $mode; ${total}s)"; exit 1; fi
echo "check: PASS (${ran[*]}; $mode; ${total}s)"
