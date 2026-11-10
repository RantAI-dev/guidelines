#!/usr/bin/env bash
# For a repository that already has code: show how far it is from the guidelines, install the
# template beside what is there, and say what to do next. Nothing existing is overwritten.
#
#   scripts/adopt.sh /path/to/repo
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:?usage: scripts/adopt.sh /path/to/repo}"

echo "===== before ====="
"$here/template/scripts/audit.sh" "$target" | grep -E '^(==|GAP|audit:)' || true
echo
echo "===== installing the template ====="
"$here/scripts/new-project.sh" "$target" | sed -n '1,/^$/p'
echo "===== next ====="
cat <<'NEXT'
In the repository, tell your agent:

    Load the adopt-guidelines skill and start at step 1.

It will run scripts/audit.sh, get scripts/check.sh green on the code as it is, freeze today's
violations with scripts/ratchet.sh, and only then propose what to refactor.

To move code to another language instead, tell it:

    Load the port-code skill. We are porting <module> from <old> to <new> because <reason>.
NEXT
