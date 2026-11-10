#!/usr/bin/env bash
# One entry point for the RantAI engineering guidelines. Run it from a clone, or straight from the web:
#
#   curl -fsSL https://raw.githubusercontent.com/RantAI-dev/guidelines/main/install.sh | bash -s -- <command> [dir]
#
#   new <dir>     create <dir> if needed, make it a git repository, install the project template
#   adopt [dir]   audit an existing repository and install the template beside its code (default: .)
#   skill         install the `rantai-guidelines` skill on this machine, so an agent in any project
#                 can do all of this when asked ("use the RantAI guidelines here")
#   update        refresh the local copy of the guidelines
#   where         print where the local copy is
#
# Nothing that already exists in a project is overwritten.
set -euo pipefail
REPO="${RANTAI_GUIDELINES_REPO:-https://github.com/RantAI-dev/guidelines.git}"
COPY="${RANTAI_GUIDELINES_HOME:-$HOME/.rantai/guidelines}"

self="${BASH_SOURCE[0]:-}"
src=""
if [ -n "$self" ] && [ -f "$self" ]; then
  d="$(cd "$(dirname "$self")" && pwd)"
  [ -d "$d/template" ] && [ -x "$d/scripts/new-project.sh" ] && src="$d"
fi
fetch() {  # make sure a local copy exists; refresh it when asked
  if [ ! -d "$COPY/.git" ]; then
    mkdir -p "$(dirname "$COPY")"
    git clone --quiet --depth 1 "${src:-$REPO}" "$COPY" 2>/dev/null || git clone --quiet --depth 1 "$REPO" "$COPY"
    [ -n "$src" ] && git -C "$COPY" remote set-url origin "$REPO"
  elif [ "${1:-}" = refresh ]; then
    git -C "$COPY" pull --quiet --ff-only 2>/dev/null || echo "guidelines: could not refresh $COPY (offline?). Using the copy that is there." >&2
  fi
}
[ -n "$src" ] || { fetch refresh; src="$COPY"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  new)
    dir="${1:?usage: install.sh new <dir>}"
    mkdir -p "$dir"
    git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || git -C "$dir" init --quiet -b main
    "$src/scripts/new-project.sh" "$dir" ;;
  adopt)
    "$src/scripts/adopt.sh" "${1:-.}" ;;
  skill)
    fetch
    for home in "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.gemini/config/skills"; do
      mkdir -p "$home"; rm -rf "$home/rantai-guidelines"
      cp -r "$src/skill/rantai-guidelines" "$home/rantai-guidelines"
    done
    echo "installed the rantai-guidelines skill for Claude Code, OpenCode and Antigravity"
    echo "local copy of the guidelines: $COPY"
    echo 'In any project, tell your agent:  "Use the RantAI guidelines here."' ;;
  update) fetch refresh; echo "guidelines: $COPY is at $(git -C "$COPY" log -1 --format='%h %cd' --date=short)" ;;
  where)  fetch; echo "$COPY" ;;
  *) sed -n '2,13p' "$src/install.sh" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
