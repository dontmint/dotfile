#!/usr/bin/env bash
# Restore this Omarchy instance from the repo onto the machine.
#
#   ./apply.sh               # $HOME config + system settings (sudo for the latter)
#   ./apply.sh --user-only   # only $HOME, no root needed
#   ./apply.sh --packages    # also reinstall the captured package lists
#   ./apply.sh --dry-run     # report what would change, change nothing
#
# Files that are about to be overwritten are kept under
# ~/.dotfiles-backup/<timestamp>/ (system files under /var/backups/dotfiles/),
# so a wrong direction is recoverable.

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
real_home=$(getent passwd "$(id -u)" | cut -d: -f6)

dry_run=0
user_only=0
with_packages=0

for arg in "$@"; do
  case $arg in
  --dry-run) dry_run=1 ;;
  --user-only) user_only=1 ;;
  --packages) with_packages=1 ;;
  -h | --help) sed -n '2,12p' "${BASH_SOURCE[0]}" | cut -c3-; exit 0 ;;
  *)
    echo "apply: unknown option '$arg' -- try --help" >&2
    exit 2
    ;;
  esac
done

backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

rsync_flags=(-a --itemize-changes --backup --backup-dir="$backup/home")
((dry_run)) && rsync_flags+=(--dry-run)

echo "==> home: $repo/home -> $HOME"
rsync "${rsync_flags[@]}" "$repo/home/" "$HOME/"

if ((!user_only)); then
  echo
  echo "==> system: $repo/system -> /"
  if ((dry_run)); then
    echo "dry-run: would run: sudo $repo/system/apply-system.sh"
  elif [[ -t 0 || -t 1 ]]; then
    # A terminal is in front of this script, so sudo can ask for a password.
    sudo "$repo/system/apply-system.sh"
  elif sudo -n true 2>/dev/null; then
    sudo -n "$repo/system/apply-system.sh"
  else
    echo "no terminal for a sudo prompt; elevating through pkexec"
    pkexec "$repo/system/apply-system.sh"
  fi
fi

# Restoring the files is not enough for the pieces that are rendered from them:
# the theme is materialised into ~/.local/state/omarchy/current/theme by
# `omarchy theme set`, and Hyprland/the shell cache what they read at startup.
# Only when this is the machine's real $HOME -- a scratch HOME must stay a
# sandbox -- and never during a dry run.
if ((!dry_run)) && [[ $HOME == "$real_home" ]] && command -v omarchy >/dev/null 2>&1; then
  theme_file="$HOME/.local/state/omarchy/current/theme.name"
  if [[ -r $theme_file ]] && [[ -n $(<"$theme_file") ]]; then
    echo
    echo "==> re-applying theme: $(<"$theme_file")"
    if ! omarchy theme set "$(<"$theme_file")"; then
      echo "apply: 'omarchy theme set' failed; pick a theme from the menu" >&2
    fi
  fi

  echo "==> reloading desktop config"
  omarchy restart hyprctl || echo "apply: hyprctl reload failed" >&2
  omarchy restart shell || echo "apply: shell restart failed" >&2
fi

if ((with_packages)); then
  echo
  if ((dry_run)); then
    echo "dry-run: would run: omarchy pkg add \$(cat $repo/packages/explicit.txt)"
    echo "dry-run: would run: omarchy pkg aur add \$(cat $repo/packages/foreign.txt)"
  elif ! command -v omarchy >/dev/null 2>&1; then
    echo "apply: omarchy is not on PATH; install Omarchy first" >&2
  else
    mapfile -t explicit <"$repo/packages/explicit.txt"
    mapfile -t foreign <"$repo/packages/foreign.txt"
    echo "==> packages: ${#explicit[@]} explicit, ${#foreign[@]} foreign"
    omarchy pkg add "${explicit[@]}"
    ((${#foreign[@]})) && omarchy pkg aur add "${foreign[@]}"
  fi
fi

echo
if [[ -d $backup ]]; then
  echo "Previous versions of anything overwritten are in $backup"
else
  echo "Nothing had to be backed up."
fi
