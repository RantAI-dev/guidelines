#!/usr/bin/env bash
# Usage: setup-run.sh <T1|T2a|T2b|T3|T4|T5a|T5b|T6> <label> [runs-root]
# Builds a fresh scratch repo for one worker run and prints the brief to hand to the worker.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bench="$(dirname "$here")"
key="$1"; label="$2"; root="${3:-${BENCH_RUNS:-/tmp/rantai-bench/runs}}"

case "$key" in
  T1)  task=T1-feature;        fixture=fixture-ts ;;
  T2a) task=T2-bugfix-fence;   fixture=fixture-ts ;;
  T2b) task=T2-bugfix-fence;   fixture=fixture-ts ;;
  T5a) task=T2-bugfix-fence;   fixture=fixture-ts ;;
  T5b) task=T2-bugfix-fence;   fixture=fixture-ts ;;
  T3)  task=T3-plan-conflict;  fixture=fixture-ts ;;
  T4)  task=T4-rust;           fixture=fixture-rust ;;
  T6)  task=T6-port;           fixture=fixture-port ;;
  *) echo "unknown task $key" >&2; exit 2 ;;
esac

run="$root/$key/$label"
rm -rf "$run"; mkdir -p "$run"
cp -r "$bench/$fixture/." "$run/"
rm -rf "$run/node_modules" "$run/target"
[ -d "$bench/tasks/$task/overlay" ] && cp -r "$bench/tasks/$task/overlay/." "$run/"

if [ "$fixture" = fixture-ts ]; then
  idx="$run/src/features/pricing/index.ts"
  if [ "$key" = T2a ]; then
    python3 - "$idx" "$bench/tasks/$task/fence-comment.txt" <<'PY'
import sys,pathlib
p=pathlib.Path(sys.argv[1]); c=pathlib.Path(sys.argv[2]).read_text().rstrip("\n")
p.write_text(p.read_text().replace("__FENCE_COMMENT__", c))
PY
  else
    sed -i '/__FENCE_COMMENT__/d' "$idx"
  fi
  # T5: an odd-looking special case inside priceCart, with (T5a) or without (T5b) a why-comment.
  if [ "$key" = T5a ] || [ "$key" = T5b ]; then
    python3 - "$run/src/features/pricing/price-cart.ts" "$bench/tasks/$task/probe-comment.txt" "$key" <<'PY'
import sys,pathlib
p=pathlib.Path(sys.argv[1]); c=pathlib.Path(sys.argv[2]).read_text() if sys.argv[3]=="T5a" else ""
anchor="  for (const line of cart.lines) {\n    const sub ="
t=p.read_text(); assert anchor in t
p.write_text(t.replace(anchor,"  for (const line of cart.lines) {\n"+c+'    if (line.sku === "ZZ-0000") continue;\n    const sub ='))
PY
  fi
  (cd "$run" && bun install --silent >/dev/null 2>&1)
fi

(
  cd "$run"
  git init -q -b main
  git config user.name bench; git config user.email bench@example.invalid
  git add -A && git commit -q -m "base: $key"
  git tag bench-base
)
date +%s > "$run/.bench-start"
sed "s|{RUN_DIR}|$run|g" "$bench/tasks/$task/brief.md"
