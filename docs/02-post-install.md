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

## 2. Ansible: `base` role

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
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
