# dotfiles

Configuration for this Omarchy machine, snapshotted so a reinstall is
`git clone` + `./apply.sh`.

```
home/            mirrors $HOME exactly -- .bashrc, .config/hypr, .config/omarchy, ...
system/etc/      mirrors /etc -- the settings that are not dotfiles
packages/        pacman -Qqe / -Qqm as of the last capture
manifest.home    what capture.sh pulls out of $HOME (edit to widen the net)
excludes.txt     what never gets pulled, even inside a manifested directory
capture.sh       live machine -> repo
apply.sh         repo -> live machine
system/apply-system.sh   the root half of apply.sh
```

## One command

On a fresh Omarchy, logged in as your own user, this is the whole restore:

```bash
git clone <this-repo> ~/dotfiles && ~/dotfiles/apply.sh
```

Paste your clone URL over `<this-repo>` once and keep the line: it fetches the
repo, restores every tracked file, applies the system half through `sudo`,
re-applies the theme and reloads Hyprland and the shell. A private repo just
means git asks for credentials mid-command.

Already cloned, or re-running after more captures landed:

```bash
git -C ~/dotfiles pull && ~/dotfiles/apply.sh
```

## Restoring after a reinstall

Same thing, spelled out, plus the variants.

`apply.sh` restores `$HOME`, then runs `system/apply-system.sh` under `sudo` for
`/etc`, the sleep masks and the service enablement, then re-applies the captured
theme and reloads Hyprland and the shell. Anything it overwrites is first copied
to `~/.dotfiles-backup/<timestamp>/` (`/var/backups/dotfiles/` for system
files), so a mistake here is recoverable.

Useful variants:

```bash
~/dotfiles/apply.sh --dry-run      # show the changes, touch nothing
~/dotfiles/apply.sh --user-only    # $HOME only, no root
~/dotfiles/apply.sh --packages     # also reinstall packages/explicit.txt + foreign.txt
```

`--packages` reinstalls the full explicit list, which is mostly what Omarchy
already had. It is opt-in because it is the slow, noisy part.

If `git` is somehow missing on the fresh install:
`omarchy pkg add git` first, then run the one-liner.

## Keeping it current

The repo is a copy, not a symlink farm, so the machine keeps working normally --
and it means edits on the machine do **not** reach the repo by themselves.

```bash
~/dotfiles/capture.sh              # machine -> repo, per manifest.home
git -C ~/dotfiles diff             # read it
git -C ~/dotfiles add -A && git -C ~/dotfiles commit -m "capture $(date +%F)"
```

`capture.sh` copies directories with `--delete`, so a file you removed from
`~/.config/hypr` also disappears from the repo. Adding a path to `manifest.home`
is all it takes to start tracking something new.

## What is deliberately not captured

- **Private keys** -- `~/.ssh` is captured only as `authorized_keys` (a public
  key, safe to publish); identity keys, `~/.gnupg`, `~/.pki` stay put.
- **Browser profiles** -- `~/.config/chromium`, `zen`, `BraveSoftware`,
  `google-chrome*`, `microsoft-edge*` and `~/.config/winboat` are hundreds of
  megabytes of cache and logins. Sign in again after restoring.
- **Application logins** -- `~/.claude`, `~/.codex`, `~/.omp`, `~/.agents`,
  `~/.config/opencode` credentials and anything else you are asked to
  authenticate afresh.
- **Fonts** (`~/.local/share/fonts`, 37 MB) and application caches. If you
  installed a font by hand and want it back, add the file to the repo yourself.
- **Machine identity** -- `/etc/fstab`, `/etc/machine-id`, host keys, partition
  UUIDs. Wrong on a new install, and `sshd` regenerates its host keys.

`capture.sh` finishes with a grep for `password|token|secret|api_key|...` across
the captured trees and prints anything it finds. It is a warning, not a
guarantee: this repo goes on a remote one day, so read the diff before pushing,
and think twice before making it public.

## The system settings in here

`system/etc/systemd/sleep.conf.d/10-no-sleep.conf` and
`system/etc/systemd/logind.conf.d/30-no-sleep.conf` are the machine's
"never sleep" policy: every sleep verb is refused (`Allow*=no`) and logind
ignores the lid, the sleep/hibernate keys and the power button. `idle` is
ignored too. `apply-system.sh` masks `suspend/hibernate/hybrid-sleep/
suspend-then-hibernate.target` on top, so even a caller that bypasses logind
fails. The display still powers down on idle and on lid close -- that is the one
power action this box is allowed.

To undo any of it: delete the two drop-ins, `systemctl unmask suspend.target
hibernate.target hybrid-sleep.target suspend-then-hibernate.target`,
`systemctl daemon-reload`, `systemctl reload systemd-logind`.

## Notes

- `manifest.home` tracks `.local/state/omarchy/toggles` and
  `current/theme.name` -- omarchy stores "I turned suspend off" and "my theme is
  white" as state files, and they are configuration in every sense that matters.
- `apply.sh` re-applies the theme with `omarchy theme set` because
  `~/.local/state/omarchy/current/theme/` is generated from it, and that step is
  skipped when `$HOME` is not your real home directory (useful for testing).
- System-wide settings that belong to the Omarchy package itself (the rest of
  `/etc/systemd`, `/etc/NetworkManager/conf.d/omarchy-wifi-powersave.conf`,
  `/etc/mkinitcpio.conf.d/`) are not duplicated here -- reinstalling Omarchy
  restores those.
