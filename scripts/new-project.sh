#!/usr/bin/env bash
# Copies the template into a project. Existing files are never overwritten: they are listed, and
# you merge them by hand.
#
#   scripts/new-project.sh /path/to/project
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:?usage: scripts/new-project.sh /path/to/project}"
[ -d "$target" ] || { echo "no such directory: $target" >&2; exit 1; }
git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || { echo "$target is not a git repository (run git init first)" >&2; exit 1; }

copied=0; skipped=()
while IFS= read -r -d '' src; do
  rel="${src#"$here/template/"}"
  dest="$target/$rel"
  if [ -e "$dest" ] || [ -L "$dest" ]; then skipped+=("$rel"); continue; fi
  mkdir -p "$(dirname "$dest")"
  cp -P "$src" "$dest"
  copied=$((copied + 1))
done < <(find "$here/template" \( -type f -o -type l \) -print0)

git -C "$target" config core.hooksPath .githooks

echo "copied $copied files into $target"
if [ "${#skipped[@]}" -gt 0 ]; then
  echo "already there, left alone (merge by hand from $here/template):"
  printf '  %s\n' "${skipped[@]}"
fi
cat <<'NEXT'

Next, in this order:
  1. AGENTS.md            replace every TODO(fill) line with facts you checked. No overview of the code.
  2. scripts/check.sh     edit the CONFIGURE block: delete the stacks you do not have, fix the commands.
  3. .agents/protected-paths   add this repo's contract tests, applied migrations and lint configs.
     .agents/risky-paths       add auth, money, tenancy, migrations, deploy. Empty means nothing needs a person.
     .agents/error-codes.tsv   if this repo serves an API: add an @emit line, run scripts/error-codes.sh --write.
                               New endpoints, errors and logs follow docs/conventions.md.
  4. CODEOWNERS           replace @TODO-owner.
  5. Run scripts/check.sh until it prints "check: PASS".
  6. Protect the main branch on the git host: require the ci check, block force pushes.

Or hand all six to your agent: "Use the RantAI guidelines here." (install the skill once with
./install.sh skill). For a repository that already has code, also say "then load the
adopt-guidelines skill and start at step 1".
NEXT
