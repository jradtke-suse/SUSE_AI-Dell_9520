# 02 - Post-Install Configuration

Two stages:

1. **Shell bootstrap** (`scripts/00-bootstrap.sh`): the minimum needed to get to a point where Ansible can run.
2. **Ansible** (`ansible/site.yml`): everything else, idempotent and repeatable.

## 1. Bootstrap

Run on the host as root:

```bash
sudo REGCODE=XXXX-XXXX EMAIL=you@example.com ./scripts/00-bootstrap.sh
```

What it does:
- Verifies it is running on SLES 16
- Registers with SCC via `SUSEConnect` (skipped if already registered or `REGCODE` unset). _Optional: the `registration` Ansible role does this from your workstation._
- `zypper refresh && zypper update`
- Installs `git`, `ansible`, `python3`
- Prints next steps

## 2. Ansible: run from your workstation

Ansible runs from your workstation (e.g. a Mac: `brew install ansible`) against the host listed in `ansible/inventory/hosts.yml`.

```bash
ssh-copy-id mansible@10.10.12.252          # key-based login first
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### 2a. `sudo` role (first run only needs a password)

SLES 16 ships `Defaults targetpw` in `/usr/etc/sudoers`, so `sudo` asks for **root's** password, not your user's. The first run gives the user passwordless sudo via `/etc/sudoers.d/90-nopasswd-<user>`:

```bash
ansible-playbook site.yml --tags sudo -K     # enter the ROOT password
```

Later runs need no password.

### 2b. Vault (SCC regcodes)

Regcodes are kept in `ansible/group_vars/all/vault.yml`, which is encrypted with Ansible Vault and committed to the repo. The vault password is **not** in the repo. It lives at `~/.ansible/suse_ai_vault_pass` (mode 600).

```bash
cd ansible
ansible-vault create group_vars/all/vault.yml --vault-password-file ~/.ansible/suse_ai_vault_pass   # first time, see vault.yml.example
ansible-vault edit   group_vars/all/vault.yml --vault-password-file ~/.ansible/suse_ai_vault_pass
```

Every playbook run needs `--vault-password-file ~/.ansible/suse_ai_vault_pass` (or `--ask-vault-pass`).

### 2c. `registration` role (SCC direct)

```bash
ansible-playbook site.yml --tags registration --vault-password-file ~/.ansible/suse_ai_vault_pass
```

- Reads `SUSEConnect -s` and registers only if `SLES` isn't already `Registered`. The regcode is never logged.
- Extensions go in `scc_extensions` in `group_vars/all/main.yml`. On SLES 16.0 the available ones are `sle-ha/16.0/x86_64` (needs its own regcode) and `PackageHub/16.0/x86_64`. **PackageHub is enabled** on wheatley (for `os-prober`). It adds the `Backports-16.0` and `PackageHub-16.0` repos.
- **SUSE AI is not an SCC extension on SLES.** Its regcode (`vault_suse_ai_regcode`) is for the Kubernetes/Application Collection side later.

### 2d. `repos` role

```bash
ansible-playbook site.yml --tags repos --vault-password-file ~/.ansible/suse_ai_vault_pass
```

- Removes the install-media repo the installer leaves behind (`hd:/install?device=...USB...`)
- Adds anything listed in `repos_extra`
- Refreshes, then runs `zypper patch --with-interactive`. Without `--with-interactive`, `-n` silently skips every reboot-flagged patch (kernel, systemd, ucode). The task also re-runs if zypper updates itself first (exit code 103).
- Prints a reboot notice if `zypper needs-rebooting` says so

> First run on wheatley (2026-10-30): 540 patches, then 26 reboot-flagged ones. Kernel 6.12.0-160000.5 → 160000.40.

### 2e. `bootloader` role (fix the failsafe kernel options)

Installing from the **Failsafe** boot entry (see [01](01-os-installation.md)) carries the failsafe kernel options into the installed system's `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX_DEFAULT="ide=nodma apm=off noresume edd=off nomodeset 3 mitigations=auto quiet security=selinux selinux=1 rd.driver.blacklist=nouveau rd.driver.blacklist=nova-core"
```

- `3` boots to **multi-user.target**, so GDM never starts. This is why there's no desktop after install.
- `nomodeset` disables kernel modesetting, which GNOME on Wayland needs (i915 and nvidia-drm)
- `ide=nodma apm=off noresume edd=off` are legacy failsafe options with no use here

The role removes those options (listed in `bootloader_cmdline_remove`), keeps everything else, backs up `/etc/default/grub`, and regenerates `/boot/grub2/grub.cfg`:

```bash
ansible-playbook site.yml --tags bootloader
ssh mansible@10.10.12.252 sudo reboot
```

Result on wheatley (2026-10-30):
```
GRUB_CMDLINE_LINUX_DEFAULT="mitigations=auto quiet security=selinux selinux=1 rd.driver.blacklist=nouveau rd.driver.blacklist=nova-core"
```

Manual equivalent:
```bash
sudo vi /etc/default/grub        # remove: ide=nodma apm=off noresume edd=off nomodeset 3
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo reboot
```

**Dual boot (Windows on the second NVMe):** `os-prober` isn't in the SLES 16 core repos. It's only in **SUSE Package Hub 16.0** (community-maintained, not SUSE-supported). `bootloader_windows_method` selects how Windows gets into the GRUB menu:

| Method | What it does |
|---|---|
| `os-prober` (**current**) | Installs `os-prober` from Package Hub (`PackageHub/16.0/x86_64` in `scc_extensions`), sets `GRUB_DISABLE_OS_PROBER="false"`, and removes the fixed entry |
| `chainload` | Fixed `/etc/grub.d/45_windows` entry that chainloads `/EFI/Microsoft/Boot/bootmgfw.efi` from `bootloader_windows_esp_uuid`. Supported packages only. |
| `none` | No Windows entry (use the firmware F12 menu) |

Result on wheatley: `menuentry 'Windows Boot Manager (on /dev/nvme1n1p1)'`.

> os-prober scans every disk each time `grub2-mkconfig` runs (each kernel update). Remove the USB installer stick so it isn't picked up.

### 2f. `base` role

```bash
ansible-playbook site.yml --tags base
```

Covers (edit `group_vars/all/main.yml`):
- Hostname
- Base packages
- Services (sshd, firewalld, chronyd)
- Firewall ports
- **WiFi** (`--tags wifi`): NetworkManager connections from `wifi_networks`. PSKs live in the vault (`vault_wifi_*_psk`). Stored by NM in `/etc/NetworkManager/system-connections/<ssid>.nmconnection` (0600 root).
  - wheatley: `KUBERNERDES` on `wlp0s20f3` gets `10.10.12.0/22`. Wired (`192.168.0.0/24`, metric 100) stays the preferred default route over WiFi (metric 20600).
- **GNOME power** (`--tags gnome_power`): for each user in `gnome_no_sleep_on_ac_users`, sets `org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` to `'nothing'` (no idle suspend on AC). Battery behaviour and lid-close (logind) are unchanged.

## Notes / Decisions

- SLES 16 uses **SELinux** by default (not AppArmor like SLES 15). Keep this in mind for RKE2 (`rke2-selinux` package).
- SLES 16 uses **NetworkManager**. The KVM host pattern should have created a bridge. Check with `nmcli con show`.
