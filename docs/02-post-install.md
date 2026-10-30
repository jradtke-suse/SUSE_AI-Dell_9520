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
- Registers with SCC via `SUSEConnect` (skipped if already registered or `REGCODE` unset)
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

### 2b. `base` role

```bash
ansible-playbook site.yml --tags base
```

Covers (edit `group_vars/all.yml`):
- Hostname
- Base packages
- Services (sshd, firewalld, chronyd)
- Firewall ports

## Notes / Decisions

- SLES 16 uses **SELinux** by default (not AppArmor like SLES 15). Keep this in mind for RKE2 (`rke2-selinux` package).
- SLES 16 uses **NetworkManager**. The KVM host pattern should have created a bridge. Check with `nmcli con show`.
