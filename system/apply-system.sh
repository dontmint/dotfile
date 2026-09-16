#!/usr/bin/env bash
# The root half of the restore: settings that live outside $HOME.
#
#   sudo ~/dotfiles/system/apply-system.sh
#
# apply.sh calls this for you. It is idempotent -- running it twice is a no-op
# beyond rsync reporting that the files already match.

set -euo pipefail

[[ $EUID -eq 0 ]] || {
  echo "apply-system: run as root (sudo $0)" >&2
  exit 1
}

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
backup="/var/backups/dotfiles/$(date +%Y%m%d-%H%M%S)"

mkdir -p "$backup"
echo "==> /etc payload: $repo/system/etc -> /etc"

# --no-owner/--no-group because rsync -a would hand these files the repo's
# ownership, and the repo belongs to the login user: anything root reads out of
# /etc must belong to root. The loop below then heals files an earlier run left
# user-owned.
rsync -a --no-owner --no-group --itemize-changes \
  --backup --backup-dir="$backup" "$repo/system/etc/" /etc/

while IFS= read -r -d '' file; do
  chown root:root "/etc/${file#"$repo/system/etc/"}"
done < <(find "$repo/system/etc" -type f -print0)

# This machine never suspends or hibernates: only the display powers down.
#
# The two drop-ins copied above already make logind refuse every sleep verb
# (AllowSuspend/AllowHibernation/AllowSuspendThenHibernate/AllowHybridSleep=no
# plus HandleLidSwitch/HandleSuspendKey/HandleHibernateKey=ignore). Masking the
# targets underneath is the second layer: a caller that skips logind entirely --
# an old menu entry, a stray script, a package's post-install hook -- hits a
# masked unit instead of systemd-suspend.service. Shutdown and reboot go through
# reboot.target/poweroff.target and are unaffected.
echo "==> masking sleep targets"
systemctl mask suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

# Reachable by design: sshd and the network stay running. NetworkManager is
# enabled only when it isn't already -- enabling it again drags in its
# wait-online unit, which Omarchy masks on purpose.
echo "==> enabling the services that must stay up"
systemctl enable --now sshd.service
systemctl is-enabled --quiet NetworkManager.service ||
  systemctl enable --now NetworkManager.service

systemctl daemon-reload
systemctl reload-or-restart systemd-logind

echo
echo "==> state"
systemctl is-enabled sshd.service NetworkManager.service
busctl call org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager CanSuspend
