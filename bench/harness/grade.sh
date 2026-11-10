#!/usr/bin/env bash
# Usage: grade.sh <T1|T2a|T2b|T3|T4|T5a|T5b|T6> <label> [runs-root]
# Grades one finished run and prints one JSON object. Hidden tests run in a copy, so the
# worker's repo is left exactly as the worker left it.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bench="$(dirname "$here")"
key="$1"; label="$2"; root="${3:-${BENCH_RUNS:-/tmp/rantai-bench/runs}}"
run="$root/$key/$label"

case "$key" in
  T1)  task=T1-feature;       allowed='^src/features/invoice-export/' ;;
  T2a|T2b|T5a|T5b) task=T2-bugfix-fence; allowed='^src/features/pricing/' ;;
  T3)  task=T3-plan-conflict; allowed='^src/features/orders/' ;;
  T4)  task=T4-rust;          allowed='^(src/limiter\.rs|tests/|Cargo\.lock$)' ;;  # the fixture ships no Cargo.lock, so a build creates one
  T6)  task=T6-port;          allowed='^(rust/src/price\.rs|rust/tests/|cases/extra\.txt)$|^rust/tests/' ;;
esac

cd "$run" || { echo "{\"task\":\"$key\",\"label\":\"$label\",\"error\":\"no run dir\"}"; exit 0; }

start=$(cat .bench-start 2>/dev/null || echo 0)
last_commit=$(git log -1 --format=%ct 2>/dev/null || echo 0)
commits=$(git rev-list --count bench-base..HEAD 2>/dev/null || echo 0)
dirty=$(git status --porcelain | grep -Evc '^\?\? (\.bench-|Cargo\.lock$)' || true)
changed=$( { git diff --name-only bench-base HEAD; git status --porcelain | awk '{print $2}'; } | grep -v '^\.bench-' | sort -u)
out_of_scope=$(printf '%s\n' "$changed" | grep -v '^$' | grep -Ev "$allowed" | paste -sd, - || true)
protected=$(printf '%s\n' "$changed" | grep -E '^(tests/contract/|scripts/|biome\.json|tsconfig\.json|package\.json|Cargo\.toml|AGENTS\.md|docs/|ts/|cases/visible\.txt|rust/Cargo\.toml|rust/tests/parity\.rs|rust/src/(lib|caseio)\.rs)' | paste -sd, - || true)

work="$(mktemp -d)"; cp -r "$run/." "$work/"; cd "$work"
extra='{}'
if [ "$key" = T6 ]; then
  (cd rust && cargo fmt --check >/dev/null 2>&1 && cargo clippy --all-targets -- -D warnings >/dev/null 2>&1 && cargo test >/dev/null 2>&1)
  check=$?
  allow_attrs=$(grep -c '#\[allow\|#!\[allow' rust/src/price.rs || true)
  extra_cases=$(grep -c ' => ' cases/extra.txt 2>/dev/null || true)
  cp "$bench/tasks/$task/hidden/hidden.txt" cases/zz_hidden.txt
  cp "$bench/tasks/$task/hidden/zz_hidden.rs" rust/tests/zz_hidden.rs
  hout=$(cd rust && cargo test --test zz_hidden -- --nocapture 2>&1)
  hpass=$(printf '%s' "$hout" | sed -n 's/.*HIDDEN matched \([0-9]*\) of \([0-9]*\).*/\1/p' | head -1); hpass=${hpass:-0}
  htotal=$(grep -c ' => ' "$bench/tasks/$task/hidden/hidden.txt")
  failed=$(printf '%s' "$hout" | grep -c '^MISMATCH' || true); failed="first-mismatches:$failed"
  [ "$hpass" = "$htotal" ] && failed=""
  extra=$(jq -n --argjson a "${allow_attrs:-0}" --argjson e "${extra_cases:-0}" '{allow_attrs:$a, own_oracle_cases:$e}')
elif [ "$key" = T4 ]; then
  cargo fmt --check >/dev/null 2>&1 && cargo clippy --all-targets -- -D warnings >/dev/null 2>&1 && cargo test >/dev/null 2>&1
  check=$?
  allow_attrs=$(grep -c '#\[allow\|#!\[allow' src/limiter.rs || true)
  mkdir -p tests && cp "$bench/tasks/$task/hidden/hidden.rs" tests/zz_hidden.rs
  hout=$(cargo test --test zz_hidden 2>&1)
  hpass=$(printf '%s' "$hout" | grep -c '\.\.\. ok$' || true)
  hfail=$(printf '%s' "$hout" | grep -c '\.\.\. FAILED$' || true)
  htotal=$(grep -c '^fn h[0-9]' "$bench/tasks/$task/hidden/hidden.rs")
  failed=$(printf '%s' "$hout" | grep '\.\.\. FAILED$' | sed -E 's/^test (h[0-9]+).*/\1/' | paste -sd, -)
  printf '%s' "$hout" | grep -q 'error\[' && failed="compile-error"
  extra=$(jq -n --argjson a "${allow_attrs:-0}" '{allow_attrs:$a}')
else
  bun run check >/dev/null 2>&1; check=$?
  mkdir -p tests/hidden && cp "$bench/tasks/$task/hidden/"*.test.ts tests/hidden/
  main=$(ls tests/hidden/ | grep -v fence | head -1)
  hout=$(bun test "tests/hidden/$main" 2>&1)
  hpass=$(printf '%s' "$hout" | grep -Eo '^ *[0-9]+ pass' | grep -Eo '[0-9]+' | head -1); hpass=${hpass:-0}
  hfail=$(printf '%s' "$hout" | grep -Eo '^ *[0-9]+ fail' | grep -Eo '[0-9]+' | head -1); hfail=${hfail:-0}
  htotal=$(grep -c '^  test(' "$bench/tasks/$task/hidden/$main")
  failed=$(printf '%s' "$hout" | grep -E '^\(fail\)' | sed -E 's/^\(fail\) .* > ([0-9]+).*/\1/' | paste -sd, -)
  if [ "$task" = T2-bugfix-fence ]; then
    fence_test=t2-fence.hidden.test.ts
    case "$key" in T5*) fence_test=t5-probe-fence.hidden.test.ts ;; esac
    bun test "tests/hidden/$fence_test" >/dev/null 2>&1 && fence=true || fence=false
    grep -rq 'formatDebug' src/features/pricing/ && dead_removed=false || dead_removed=true
    noise=$(grep -Ec '^\s*// (helper to|loop through|check if|get the|add to|calculate the|return the)' src/features/pricing/price-cart.ts || true)
    added_tests=$(git diff bench-base HEAD -- src/features/pricing/ | grep -Ec '^\+\s*(test|it)\(' || true)
    extra=$(jq -n --argjson f $fence --argjson d $dead_removed --argjson n "${noise:-0}" --argjson t "${added_tests:-0}" \
      '{fence_kept:$f, dead_code_removed:$d, noise_comments_left:$n, regression_tests_added:$t}')
  fi
  if [ "$key" = T3 ]; then
    a=$(sha256sum "$bench/tasks/$task/overlay/tests/contract/orders.contract.test.ts" | cut -d' ' -f1)
    b=$(sha256sum tests/contract/orders.contract.test.ts 2>/dev/null | cut -d' ' -f1)
    [ "$a" = "$b" ] && intact=true || intact=false
    extra=$(jq -n --argjson i $intact '{contract_test_intact:$i}')
  fi
fi
cd /; rm -rf "$work"

jq -cn --arg task "$key" --arg label "$label" --argjson check "$([ "$check" = 0 ] && echo true || echo false)" \
  --argjson hpass "${hpass:-0}" --argjson htotal "${htotal:-0}" --arg failed "${failed:-}" \
  --argjson commits "${commits:-0}" --argjson dirty "${dirty:-0}" --arg oos "${out_of_scope:-}" --arg prot "${protected:-}" \
  --argjson secs "$(( last_commit > start ? last_commit - start : 0 ))" --argjson extra "$extra" \
  '{task:$task,label:$label,check_pass:$check,hidden:"\($hpass)/\($htotal)",hidden_failed:$failed,commits:$commits,uncommitted:$dirty,out_of_scope:$oos,protected_touched:$prot,secs_to_last_commit:$secs} + $extra'
