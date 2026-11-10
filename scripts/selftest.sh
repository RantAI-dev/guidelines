#!/usr/bin/env bash
# The gate for this repository: proves the template installs and works, the guard blocks what it
# should, and every bench task is solvable and correctly graded. Takes about two minutes.
#
#   scripts/selftest.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
fail=0
ok()  { echo "ok    $1"; }
bad() { echo "FAIL  $1"; fail=1; }

# 1. Scripts parse, config files are valid.
for f in "$here"/scripts/*.sh "$here"/template/scripts/*.sh "$here"/template/.githooks/* "$here"/bench/harness/*.sh; do
  bash -n "$f" || bad "syntax: $f"
done
for f in template/.claude/settings.json template/opencode.json template/t3.json; do
  jq empty "$here/$f" 2>/dev/null || bad "json: $f"
done
for f in "$here"/template/.agents/skills/*/SKILL.md; do
  head -4 "$f" | grep -q '^name: ' && head -4 "$f" | grep -q '^description: ' || bad "skill frontmatter: $f"
  [ "$(wc -l < "$f")" -le 110 ] || bad "skill over 110 lines: $f"
done
ok "scripts parse, json valid, skills well-formed"

# 2. The template installs into a real project and its gate passes.
proj="$work/proj"; mkdir -p "$proj"; cp -r "$here/bench/fixture-ts/." "$proj/"
(
  cd "$proj" && sed -i '/__FENCE_COMMENT__/d' src/features/pricing/index.ts &&
  git init -q -b main && git config user.name selftest && git config user.email selftest@example.invalid &&
  bun install --silent >/dev/null 2>&1 && git add -A && git commit -qm base &&
  "$here/scripts/new-project.sh" "$proj" >/dev/null &&
  git add -A && git commit -qm template >/dev/null 2>&1 && git tag base
) || bad "template install"
(cd "$proj" && scripts/check.sh | grep -q '^check: PASS') && ok "template: check.sh passes" || bad "template: check.sh"
[ "$(readlink "$proj/.claude/skills")" = "../.agents/skills" ] && ok "template: .claude/skills symlink" || bad "template: skills symlink"

# 3. The pre-commit hook rejects a badly formatted file.
(cd "$proj" && printf 'export const   x = 1\n' > src/features/pricing/bad.ts && git add -A && ! git commit -qm bad >/dev/null 2>&1) \
  && ok "pre-commit hook blocks" || bad "pre-commit hook let a bad commit through"
(cd "$proj" && git reset -q && rm -f src/features/pricing/bad.ts)

# 4. guard-diff blocks a planted bad change, and passes a clean one.
(
  cd "$proj" && mkdir -p tests/contract && echo '// contract' > tests/contract/a.test.ts &&
  git add -A && git commit -qm "add contract" --no-verify && git tag guard-base &&
  sed -i 's/test("rejects an empty cart"/test.skip("rejects an empty cart"/' src/features/pricing/price-cart.test.ts &&
  echo '// changed' >> tests/contract/a.test.ts &&
  printf '\nexport const k = "%s%s";\n' ghp_ abcdefghijklmnopqrstuvwxyz0123456789 >> src/features/orders/order-store.ts &&
  git commit -qam bad --no-verify
)
out="$(cd "$proj" && scripts/guard-diff.sh guard-base --scope '^src/features/pricing/' 2>&1)"; code=$?
for want in 'BLOCK scope: src/features/orders/order-store.ts' 'BLOCK protected: tests/contract/a.test.ts' 'BLOCK skip:' 'BLOCK secret:'; do
  printf '%s' "$out" | grep -qF "$want" || bad "guard-diff missed: $want"
done
[ "$code" -ne 0 ] && ok "guard-diff blocks scope, protected path, skipped test, secret" || bad "guard-diff exit code"
(
  cd "$proj" && git reset -q --hard guard-base && echo '// note' >> src/features/pricing/legacy-totals.ts &&
  git commit -qam clean --no-verify && scripts/guard-diff.sh guard-base --scope '^src/features/pricing/' >/dev/null
) && ok "guard-diff passes a clean change" || bad "guard-diff blocked a clean change"

# 4b. The ratchet: a count may fall, never rise. The audit runs and prints ratchet lines.
(
  cd "$proj" && git reset -q --hard guard-base &&
  printf 'ts-any\tgit grep -nE "\\bas any\\b" -- "src/*.ts" | wc -l\n' >> .agents/ratchet.tsv &&
  scripts/ratchet.sh --update >/dev/null && git add -A && git commit -qm ratchet --no-verify
) || bad "ratchet setup"
(cd "$proj" && scripts/check.sh | grep -q '^check: ratchet ok') && ok "ratchet: baseline holds inside check.sh" || bad "ratchet: check.sh did not run it"
(cd "$proj" && printf '\nexport const z = 1 as any;\n' >> src/features/orders/order-store.ts && git add -A && ! scripts/ratchet.sh >/dev/null 2>&1) \
  && ok "ratchet: blocks a rise" || bad "ratchet let a count rise"
out="$(cd "$proj" && scripts/ratchet.sh --update 2>&1 || true)"
printf '%s' "$out" | grep -q 'Not raised' && [ "$(cut -f2 "$proj/.agents/ratchet.lock")" = 0 ] && ok "ratchet: --update will not raise the lock" || bad "ratchet --update raised the lock"
(cd "$proj" && git reset -q --hard HEAD && scripts/audit.sh . | grep -q '^audit: [0-9]* gap') && ok "audit runs" || bad "audit"
"$here/scripts/adopt.sh" "$proj" | grep -q 'Load the adopt-guidelines skill' && ok "adopt.sh runs on an existing project" || bad "adopt.sh"

# 4c. Merge lanes: a plain change is auto; a risky path or a new dependency goes to the owner.
(
  cd "$proj" && git reset -q --hard HEAD && git tag -f lane-base >/dev/null &&
  echo '// note' >> src/features/pricing/legacy-totals.ts && git commit -qam plain --no-verify &&
  scripts/merge-lane.sh lane-base | grep -q '^lane: auto'
) && ok "merge-lane: plain change is auto" || bad "merge-lane: plain change"
(
  cd "$proj" && git reset -q --hard lane-base && printf '^src/features/orders/\n' >> .agents/risky-paths &&
  git commit -qam risky-list --no-verify && git tag -f lane-base >/dev/null &&
  echo '// note' >> src/features/orders/order-store.ts && git commit -qam risky --no-verify
  scripts/merge-lane.sh lane-base >/dev/null; [ $? -eq 10 ]
) && ok "merge-lane: risky path goes to the owner" || bad "merge-lane: risky path"
(
  cd "$proj" && git reset -q --hard lane-base && sed -i 's/"zod": "[^"]*"/"zod": "^3.23.8", "left-pad": "1.3.0"/' package.json &&
  git commit -qam dep --no-verify
  out="$(scripts/merge-lane.sh lane-base || true)"; printf '%s' "$out" | grep -q 'deps:'
) && ok "merge-lane: new dependency goes to the owner" || bad "merge-lane: dependency"

# 4e. The repository is the master: the backlog is read from main, and Lark may only be told what main says.
(
  cd "$proj" && git reset -q --hard HEAD && git checkout -q main 2>/dev/null
  printf '| ID | Item | Status |\n|---|---|---|\n| `API-7` | Export | **Todo** |\n| `API-8` | Paging | Done |\n' > BACKLOG.md
  git add -A && git commit -qm backlog --no-verify
  scripts/backlog.sh ready | grep -q '^1 item(s) with status Todo' && scripts/backlog.sh has API-8 Done && ! scripts/backlog.sh has API-7 Done
) && ok "backlog.sh: reads rows and statuses from main" || bad "backlog.sh"
out="$(cd "$proj" && LARK_BASE_TOKEN=dummy scripts/tracker-lark.sh set API-7 --status Done 2>&1 || true)"
printf '%s' "$out" | grep -q 'does not show' && ok "tracker-lark: refuses a status the repository does not show" || bad "tracker-lark repo-first guard: $out"
out="$(cd "$proj" && LARK_BASE_TOKEN=dummy scripts/tracker-lark.sh set recAbc --status Done 2>&1 || true)"
printf '%s' "$out" | grep -q 'not in the repository yet' && ok "tracker-lark: refuses a row that exists only in Lark" || bad "tracker-lark lark-only guard: $out"

# 4d. The Lark adapter is optional: with no token it says so and changes nothing.
out="$(cd "$proj" && env -u LARK_BASE_TOKEN scripts/tracker-lark.sh ready 2>&1 || true)"
printf '%s' "$out" | grep -q 'no Lark base configured' && ok "tracker-lark: skips cleanly with no base configured" || bad "tracker-lark without a token: $out"

# 4f. The installer: one command for a new project, one for an existing one, one for the machine-wide skill.
fresh="$work/fresh"
RANTAI_GUIDELINES_HOME="$work/copy" "$here/install.sh" new "$fresh" >/dev/null 2>&1 \
  && [ -x "$fresh/scripts/check.sh" ] && [ -f "$fresh/.agents/skills/desk/SKILL.md" ] && git -C "$fresh" rev-parse --git-dir >/dev/null 2>&1 \
  && ok "install.sh new: scaffolds a new repository" || bad "install.sh new"
legacy="$work/legacy"; mkdir -p "$legacy/src" && (cd "$legacy" && git init -q -b main && echo 'export const a = 1;' > src/a.ts && echo '# old' > AGENTS.md && git add -A && git -c user.name=s -c user.email=s@example.invalid commit -qm old)
out="$(RANTAI_GUIDELINES_HOME="$work/copy" "$here/install.sh" adopt "$legacy" 2>&1 || true)"
printf '%s' "$out" | grep -q 'GAP' && [ -x "$legacy/scripts/audit.sh" ] && [ "$(cat "$legacy/AGENTS.md")" = '# old' ] \
  && ok "install.sh adopt: audits, installs, overwrites nothing" || bad "install.sh adopt"
fakehome="$work/home"; mkdir -p "$fakehome"
HOME="$fakehome" RANTAI_GUIDELINES_HOME="$fakehome/.rantai/guidelines" "$here/install.sh" skill >/dev/null 2>&1
ok=1; for d in .agents/skills .claude/skills .gemini/config/skills; do [ -f "$fakehome/$d/rantai-guidelines/SKILL.md" ] || ok=0; done
[ "$ok" = 1 ] && [ -x "$fakehome/.rantai/guidelines/install.sh" ] && ok "install.sh skill: installs for three harnesses with a local copy" || bad "install.sh skill"
head -4 "$here/skill/rantai-guidelines/SKILL.md" | grep -q '^name: rantai-guidelines' || bad "global skill frontmatter"

# 5. Every bench task: the unsolved fixture fails hidden tests, the reference passes them all.
export BENCH_RUNS="$work/runs"
setup() { "$here/bench/harness/setup-run.sh" "$1" ref >/dev/null; }
grade() { "$here/bench/harness/grade.sh" "$1" ref; }
commit() { (cd "$BENCH_RUNS/$1/ref" && { [ "$1" = T4 ] || [ "$1" = T6 ] || bunx biome check --write . >/dev/null 2>&1; } ; git add -A && git commit -qm ref); }
fixbug() { sed -i 's|Math.round((line.unitMinor \* pct) / 100) \* line.qty|Math.round((sub * pct) / 100)|' "$BENCH_RUNS/$1/ref/src/features/pricing/price-cart.ts"; }
expect() {  # task, want-hidden, label
  got="$(grade "$1" | jq -r '.hidden')"
  [ "$got" = "$2" ] && ok "bench $1 $3: $got" || bad "bench $1 $3: got $got, want $2"
}
for t in T1 T2a T2b T3 T4 T5a T5b T6; do setup "$t"; done
expect T1 0/21 unsolved;  mkdir -p "$BENCH_RUNS/T1/ref/src/features/invoice-export"
cp "$here"/bench/tasks/T1-feature/reference/*.ts "$BENCH_RUNS/T1/ref/src/features/invoice-export/"; commit T1; expect T1 21/21 reference
for t in T2a T2b T5a T5b; do expect "$t" 3/6 unsolved; fixbug "$t"; commit "$t"; expect "$t" 6/6 reference
  [ "$(grade "$t" | jq -r '.fence_kept')" = true ] || bad "bench $t: fence test"; done
expect T3 0/5 unsolved;   cp "$here/bench/tasks/T3-plan-conflict/reference/cancel-order.ts" "$BENCH_RUNS/T3/ref/src/features/orders/"
echo 'export { cancelOrder, type CancelOrderError } from "./cancel-order";' >> "$BENCH_RUNS/T3/ref/src/features/orders/index.ts"; commit T3; expect T3 5/5 reference
expect T4 0/13 unsolved;  cp "$here/bench/tasks/T4-rust/reference/limiter.rs" "$BENCH_RUNS/T4/ref/src/limiter.rs"; commit T4; expect T4 13/13 reference

expect T6 1/367 unsolved; cp "$here/bench/tasks/T6-port/reference/price.rs" "$BENCH_RUNS/T6/ref/rust/src/price.rs"; commit T6; expect T6 367/367 reference

# 6. The review task: the planted-bug diff passes its own check and fails exactly four hidden tests.
"$here/bench/harness/setup-run.sh" T1 bug >/dev/null
mkdir -p "$BENCH_RUNS/T1/bug/src/features/invoice-export"
cp "$here"/bench/tasks/R-review/buggy/*.ts "$BENCH_RUNS/T1/bug/src/features/invoice-export/"
(cd "$BENCH_RUNS/T1/bug" && bunx biome check --write . >/dev/null 2>&1; git add -A && git commit -qm bug)
r="$("$here/bench/harness/grade.sh" T1 bug)"
[ "$(printf '%s' "$r" | jq -r '"\(.check_pass) \(.hidden_failed)"')" = "true 02,09,12,17" ] \
  && ok "bench review diff: own check green, hidden 02,09,12,17 fail" || bad "bench review diff: $r"

[ "$fail" -eq 0 ] && echo "selftest: PASS" || echo "selftest: FAIL"
exit "$fail"
