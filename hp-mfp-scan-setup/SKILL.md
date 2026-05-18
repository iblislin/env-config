---
name: hp-mfp-scan-setup
description: Use when setting up a network-attached HP LaserJet MFP as a scanner on Linux — covers BOTH PC-pull (sane-airscan via eSCL) AND printer-push (SMB Scan-to-Network-Folder, dedicated scanuser + force-user pattern, AppArmor local override for shares outside /home). Also covers shared-LAN scenarios where other people's printers must NOT be auto-probed, and an optional inotify-driven rename of incoming scans.
---

# HP MFP scan setup

## Overview

HP LaserJet MFPs (M479fdw verified; other HP eSCL-capable models follow the same path) expose two independent scan flows that you almost always want both of:

- **Pull (PC initiates)** — `scanimage` / Simple Scan over **eSCL** (HP's AirScan). PC drives, no printer config needed.
- **Push (printer initiates)** — operator taps **Scan → Network Folder** at the printer's front panel; printer uploads a multi-page PDF to an SMB share on the PC.

This skill walks through both, plus the two non-obvious gotchas that swallow hours:

1. On a **shared LAN** (other people's MFPs visible), pin one device + `discovery = disable`. Otherwise sane will list every nearby scanner and `simple-scan` defaults to the wrong one.
2. AppArmor's default `usr.sbin.smbd` profile only covers `@{HOMEDIRS}` etc. **Adding an SMB share outside that scope (e.g. `/srv/scans`) silently 403s on writes** — POSIX perms look fine, smbd hands back `NT_STATUS_ACCESS_DENIED`. You need an explicit `/etc/apparmor.d/local/usr.sbin.smbd-shares` rule.

## When to use

- New Linux box, HP MFP already on the LAN at a known IP.
- Want both `scanimage`-style ad-hoc scans AND "press button on printer, file appears in `~/Scans/`".
- Shared LAN where other people's printers must stay untouched.

**When NOT to use:**
- USB-attached HP printer — use `hplip` + `hp-setup` directly, this skill is wrong.
- Non-HP scanner — eSCL works for any AirScan-compliant device but EWS panel layout differs.

## Prerequisites

| Item | How to check |
|---|---|
| Printer reachable | `ping <ip>`, plus `curl http://<ip>/eSCL/ScannerCapabilities` returns XML |
| eSCL endpoint works | `MakeAndModel` should appear in the XML |
| Sudo / root | `sudo -n true` |
| AppArmor in enforce mode? | `sudo aa-status` — if yes, the AppArmor override step is mandatory |

```bash
# One-shot reachability probe — adjust IP
IP=10.65.51.71
ping -c2 -W1 $IP
curl -s --max-time 5 http://$IP/eSCL/ScannerCapabilities | head -5
```

## Flow A: PC-pull via sane-airscan

### Install

Arch:
```bash
paru -S --needed sane sane-airscan simple-scan
```

Debian/Ubuntu: `apt install sane-utils sane-airscan simple-scan`

### Pin the device, disable autodiscovery

Append to `/etc/sane.d/airscan.conf`:

```ini
# Manual entry pinned to the printer you own. discovery=disable keeps
# sane from finding (and offering) other LAN MFPs you do NOT own.
[devices]
"HP M479fdw (mine)" = http://10.65.51.71/eSCL

[options]
discovery = disable
```

Use the same string in `[devices]` as your scanner's friendly name — it appears in `scanimage -L` and in Simple Scan's device dropdown.

### Verify

```bash
scanimage -L
# device `airscan:e0:HP M479fdw (mine)' is a eSCL HP M479fdw (mine) ip=10.65.51.71

# Smoke-test scan (blank platen is fine — just verifies the pipeline)
mkdir -p ~/Scans
scanimage -d 'airscan:e0:HP M479fdw (mine)' --format=png --resolution 150 \
    -x 210 -y 297 > ~/Scans/test.png
```

Flow A is done — `scanimage` works, Simple Scan GUI sees the device.

## Flow B: Printer-push via SMB Scan-to-Network-Folder

The printer authenticates to your PC as a dedicated SMB user, but files land owned by **you** thanks to Samba's `force user` directive. This way you never give your real login to the printer's EWS (which stores it in plaintext on the device).

### B.1 — Drop directory

`/home/<you>` is mode 0700 by default — Samba can't traverse it without weakening home perms. Cleanest: drop scans to `/srv/scans` and symlink from your home.

```bash
sudo install -d -o $USER -g $USER -m 2775 /srv/scans
ln -s /srv/scans ~/Scans     # if ~/Scans didn't exist; otherwise migrate first
```

The `2775` setgid bit makes any file dropped in inherit the directory's group.

### B.2 — Dedicated SMB principal (no shell, random password)

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin scanuser

# 24-char random password, stored OUTSIDE the share for safekeeping
PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
echo "$PASS" | sudo tee /srv/scanuser-smb.password >/dev/null
sudo chmod 600 /srv/scanuser-smb.password
sudo chown root:root /srv/scanuser-smb.password
echo "Password (paste this into printer EWS): $PASS"
```

**Important:** the password file must NOT live inside the share — anything in `/srv/scans` is fetchable by any SMB client that authenticates. `/srv/scanuser-smb.password` (mode 600 root) is the right spot.

### B.3 — smb.conf

`/etc/samba/smb.conf`:

```ini
[global]
   workgroup = WORKGROUP
   server string = scan target
   server role = standalone server
   security = user
   passdb backend = tdbsam
   server min protocol = SMB2_10
   client min protocol = SMB2_10
   local master = no
   preferred master = no
   domain master = no
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes
   log file = /var/log/samba/%m.log
   max log size = 1000
   log level = 1

[scans]
   path = /srv/scans
   comment = Scans from HP MFP
   browsable = yes
   read only = no
   guest ok = no
   valid users = scanuser
   force user = <your-user>
   force group = <your-user>
   create mask = 0644
   directory mask = 0755
```

Replace `<your-user>` with your username (the `force user` line is what makes incoming files end up owned by you, not by scanuser).

Validate before starting smbd:
```bash
sudo testparm -s /etc/samba/smb.conf
```

### B.4 — Add SMB password (smb.conf MUST exist first!)

```bash
printf '%s\n%s\n' "$PASS" "$PASS" | sudo smbpasswd -s -a scanuser
sudo pdbedit -L                              # verify: should list 'scanuser:NNN:'
```

**Gotcha:** running `smbpasswd -a` BEFORE `smb.conf` exists writes the entry into a default tdb that doesn't match where the configured `passdb backend = tdbsam` will look later. Always create smb.conf first.

### B.5 — AppArmor local override (the silent-failure trap)

If `sudo aa-status` says enforce mode is on and `usr.sbin.smbd` is in the list, you MUST grant the share path explicitly, or every write returns `NT_STATUS_ACCESS_DENIED` while POSIX perms look fine.

```bash
sudo install -d /etc/apparmor.d/local
sudo tee /etc/apparmor.d/local/usr.sbin.smbd-shares > /dev/null <<'EOF'
# Allow smbd to serve /srv/scans (HP MFP Scan-to-Network-Folder target).
/srv/scans/ rwk,
/srv/scans/** rwk,
EOF
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.smbd
```

The local override file is auto-included next reboot via the profile's `include if exists <local/usr.sbin.smbd-shares>` line, so this persists.

**How to recognize this failing:**
- `smbclient -L //localhost -U scanuser%<pass>` lists the share fine
- `smbclient //localhost/scans -U scanuser%<pass> -c 'put /tmp/x.txt'` → `NT_STATUS_ACCESS_DENIED`
- `sudo dmesg | grep -i apparmor` shows `DENIED operation="mknod" ... profile="smbd" name="/srv/scans/..."`

### B.6 — Start smbd and verify

```bash
sudo systemctl enable --now smb.service
systemctl is-active smb.service               # → active
ss -tlnp | grep :445                          # smbd listening

# Local smoke test — should print a directory listing, no NT_STATUS errors
echo "probe $(date)" > /tmp/probe.txt
smbclient //localhost/scans -U "scanuser%$PASS" -c 'put /tmp/probe.txt probe.txt; ls'
rm /tmp/probe.txt
ls -la /srv/scans/probe.txt                   # owner should be <your-user>, not scanuser
rm /srv/scans/probe.txt
```

If the file owner is `<your-user>` rather than `scanuser`, the `force user` directive is correctly wired.

### B.7 — Printer EWS profile

Browse to `https://<printer-ip>/` (accept the self-signed cert), log in as admin, then:

**Scan → Scan to Network Folder → New / Add → Quick Set or Profile**

| Field | Value |
|---|---|
| Network Path | `\\<your-pc-ip>\scans` |
| Username | `scanuser` |
| Password | `<contents of /srv/scanuser-smb.password>` |
| Domain | `WORKGROUP` (or leave blank) |
| Authentication mode | Windows credentials / SMB |

Find your PC's IP on the printer's subnet:
```bash
ip -4 route get <printer-ip> | awk '{print $7; exit}'
```

Most HP EWSs offer a **Test Access** button — use it; it'll write a small probe file and report success/failure. After it passes, the front-panel **Scan → Network Folder → <profile name>** flow is live.

**HP quirk to ignore:** smbd's per-host log may show `parse_dfs_path_strict: Hostname X.internal-domain.example is not ours` when the printer first probes for a DFS root. Harmless — it falls back to direct SMB. Don't chase it.

## Optional: auto-rename incoming scans

Printers usually let you set a filename prefix, but the format options (timestamp inclusion, separators) are firmware-limited. Easier and 100% controllable: rename on the PC the moment a file arrives.

`/usr/local/sbin/scan-rename.sh`:

```bash
#!/bin/bash
# Watch the SMB scan drop directory and rename freshly-arrived files to
# scan-YYYY-MM-DD-HHMMSS.<ext>. Timestamp is taken from the file's own
# mtime so it reflects when the printer actually wrote it.
set -euo pipefail
WATCH=/srv/scans
exec inotifywait -m -e close_write -e moved_to --format '%f' "$WATCH" |
while read -r fname; do
    src="$WATCH/$fname"
    [[ -f "$src" ]] || continue
    [[ "$fname" =~ ^scan-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}\. ]] && continue
    ext="${fname##*.}"
    [[ "$ext" == "$fname" ]] && ext=bin
    ts=$(date -r "$src" +%Y-%m-%d-%H%M%S)
    dst="$WATCH/scan-$ts.$ext"
    n=1
    while [[ -e "$dst" ]]; do
        dst="$WATCH/scan-${ts}_$n.$ext"
        ((n++))
    done
    mv -n -- "$src" "$dst" && logger -t scan-rename "$fname -> $(basename "$dst")"
done
```

`/etc/systemd/system/scan-rename.service`:

```ini
[Unit]
Description=Rename SMB-pushed scans to scan-YYYY-MM-DD-HHMMSS.ext
After=smb.service
Wants=smb.service

[Service]
Type=simple
User=<your-user>
Group=<your-user>
ExecStart=/usr/local/sbin/scan-rename.sh
Restart=on-failure
RestartSec=2
ProtectSystem=strict
ReadWritePaths=/srv/scans
ProtectHome=true
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```bash
sudo chmod 755 /usr/local/sbin/scan-rename.sh
sudo systemctl daemon-reload
sudo systemctl enable --now scan-rename.service
journalctl -t scan-rename -f               # tail rename activity
```

**Why mtime, not `date` at rename time:** `inotifywait` wakes up shortly after `close_write`, but file mtime is set by the SMB write itself. Using mtime gives you the actual upload moment, robust against batched closes or service restarts.

## Verification checklist

After both flows are wired, run through this to confirm green:

```bash
# Flow A
scanimage -L | grep -i "$(your friendly name)"
scanimage -d "$DEV" --format=png --resolution 150 -x 210 -y 297 \
    > /tmp/pull-test.png && file /tmp/pull-test.png

# Flow B (push) — drive it from the front panel; afterwards:
ls -la /srv/scans/ | head        # the new scan should be there
journalctl -u smb.service --since '5 min ago' | grep -i deny  # should be empty
journalctl -t scan-rename -n 5   # rename event for the new file
```

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `scanimage -L` shows your printer AND neighbours' | autodiscovery on | `discovery = disable` + manual `[devices]` entry |
| `smbclient` login OK, but `put` → `NT_STATUS_ACCESS_DENIED` | AppArmor profile doesn't cover share path | Add `/etc/apparmor.d/local/usr.sbin.smbd-shares` |
| `Username not found` in `pdbedit -L` despite running smbpasswd | smbpasswd ran before smb.conf existed; wrote to wrong tdb | Create smb.conf first, then `smbpasswd -a` again |
| Printer EWS "Test Access" times out | PC firewall (ufw/firewalld) blocking 445/tcp | Open 445 to the printer IP only (or whole LAN if internal) |
| File arrives owned by `scanuser`, not you | `force user` missing or typo | Re-check `[scans]` block, restart smb.service |
| Auto-rename service won't start | systemd service running as `<your-user>` can't write `/srv/scans` | Either `force user = <you>` is wrong, or the `ReadWritePaths` line is missing |
| AppArmor parser fails on the local override | Syntax error in the rule | Rules must end with `,` — `/srv/scans/** rwk,` not `/srv/scans/** rwk` |

## Quick-reference values

When porting to a new printer / new PC, the only host-specific values are:

| Variable | Source |
|---|---|
| `<printer-ip>` | DHCP reservation / static |
| `<your-user>` | `id -un` |
| `<pc-ip>` | `ip -4 route get <printer-ip> \| awk '{print $7; exit}'` |
| eSCL device name in `[devices]` | Free-form, but reused in `scanimage -d` |
| `WORKGROUP` | Default; only change if you have an AD environment |
