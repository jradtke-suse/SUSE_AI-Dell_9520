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
ssh-copy-id mansible@192.168.0.103          # key-based login first
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
- Extensions go in `scc_extensions` in `group_vars/all/main.yml`. On SLES 16.0 the available ones are `sle-ha/16.0/x86_64` (needs its own regcode) and `PackageHub/16.0/x86_64`.
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

### 2e. `base` role

```bash
ansible-playbook site.yml --tags base
```

Covers (edit `group_vars/all/main.yml`):
- Hostname
- Base packages
- Services (sshd, firewalld, chronyd)
- Firewall ports

## Notes / Decisions

- SLES 16 uses **SELinux** by default (not AppArmor like SLES 15). Keep this in mind for RKE2 (`rke2-selinux` package).
- SLES 16 uses **NetworkManager**. The KVM host pattern should have created a bridge. Check with `nmcli con show`.
