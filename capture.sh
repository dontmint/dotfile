#!/usr/bin/env bash
# Snapshot this machine's configuration into the repo.
#
#   ./capture.sh
#
# Copies every path in manifest.home out of $HOME into home/, refreshes the
# system payload under system/, and rewrites the package lists. Nothing is
# committed: review with `git status` / `git diff` first, then commit.

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
manifest="$repo/manifest.home"
excludes="$repo/excludes.txt"

[[ -r $manifest ]] || {
  echo "capture: $manifest is missing" >&2
  exit 1
}

# Paths outside $HOME that belong to this instance rather than to the omarchy
# package. Keep this list in step with system/apply-system.sh.
system_paths=(
  etc/systemd/sleep.conf.d/10-no-sleep.conf
  etc/systemd/logind.conf.d/30-no-sleep.conf
)

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  printf '%s' "${value%"${value##*[![:space:]]}"}"
}

# ------------------------------------------------------------------ $HOME ---

while IFS= read -r line || [[ -n $line ]]; do
  entry=$(trim "$line")
  [[ -z $entry || $entry == \#* ]] && continue

  src="$HOME/$entry"
  dst="$repo/home/$entry"

  if [[ -d $src ]]; then
    mkdir -p "$dst"
    rsync -a --delete --delete-excluded --exclude-from="$excludes" "$src/" "$dst/"
    printf 'dir   %s\n' "$entry"
  elif [[ -e $src || -L $src ]]; then
    mkdir -p "$(dirname -- "$dst")"
    rsync -a "$src" "$dst"
    printf 'file  %s\n' "$entry"
  else
    printf 'skip  %s (not on this machine)\n' "$entry" >&2
  fi
done <"$manifest"

# ------------------------------------------------------------------ /etc ----

for path in "${system_paths[@]}"; do
  src="/$path"
  dst="$repo/system/$path"

  if [[ -e $src ]]; then
    install -D -m 0644 "$src" "$dst"
    printf 'etc   /%s\n' "$path"
  else
    printf 'skip  /%s (not on this machine)\n' "$path" >&2
  fi
done

# ------------------------------------------------------------- packages -----

mkdir -p "$repo/packages"
pacman -Qqe >"$repo/packages/explicit.txt"
pacman -Qqm >"$repo/packages/foreign.txt"
printf 'pkgs  %s explicit, %s foreign\n' \
  "$(wc -l <"$repo/packages/explicit.txt")" \
  "$(wc -l <"$repo/packages/foreign.txt")"

# ---------------------------------------------------------- secret check ----
#
# capture.sh only copies manifested paths, but a token pasted into an alias or
# a config is exactly the kind of thing that leaks. Warn, do not fail: the
# verdict belongs to whoever is about to push this repo somewhere.

if hits=$(grep -rIniE \
  '(passphrase|password|passwd|secret|token|api[_-]?key|access[_-]?key|private[_-]?key|bearer)[[:space:]]*[:=]' \
  "$repo/home" "$repo/system" 2>/dev/null); then
  echo
  echo "!! possible secrets -- read these before committing:" >&2
  printf '%s\n' "$hits" >&2
fi

cat <<EOF

Captured into $repo.
Next:
  git -C $repo status
  git -C $repo diff
  git -C $repo add -A && git -C $repo commit -m "capture $(date +%F)"
EOF
