# README

This will provide guidance, step-by-step, on how to deploy SUSE AI 1.0 on a Dell XPS 15 9520 (hostname `wheatley`) with an NVIDIA GeForce RTX 3050 Ti Laptop GPU

**Approach:** follow "the SUSE way" wherever possible: SUSE-packaged and SUSE-signed components first (e.g. the **open** NVIDIA kernel driver as a signed KMP rather than the proprietary `.run` installer), SUSE Rancher Prime / RKE2 for Kubernetes, and the SUSE Application Collection for SUSE AI components.

**Reference guide:** [SUSE AI 1.0 deployment guide](https://documentation.suse.com/suse-ai/1.0/html/AI-deployment/ai-deployment-kube-installing.html). It's written for SLES 15 SP6, so we follow it loosely. Every place SLES 16 differs is tracked in [docs/sles16-deltas.md](docs/sles16-deltas.md).

## Status

| # | Phase | Doc | Automation | Status |
|---|-------|-----|-----------|--------|
| 0 | Hardware / BIOS prep | [docs/00-hardware.md](docs/00-hardware.md) | n/a | ⬜ |
| 1 | OS installation (SLES 16) | [docs/01-os-installation.md](docs/01-os-installation.md) | n/a (manual, Agama remote install) | ✅ |
| 2 | Post-install bootstrap | [docs/02-post-install.md](docs/02-post-install.md) | `scripts/00-bootstrap.sh` | ⬜ |
| 3a | Passwordless sudo | [docs/02-post-install.md](docs/02-post-install.md) | `ansible` role `sudo` | ✅ |
| 3b | SCC registration | [docs/02-post-install.md](docs/02-post-install.md) | `ansible` role `registration` | ✅ |
| 3c | Repos + patching | [docs/02-post-install.md](docs/02-post-install.md) | `ansible` role `repos` | ✅ |
| 3d | Bootloader: failsafe options cleanup + Windows entry | [docs/02-post-install.md](docs/02-post-install.md) | `ansible` role `bootloader` | ✅ |
| 3 | Base OS config | [docs/02-post-install.md](docs/02-post-install.md) | `ansible` role `base` | ⬜ |
| 4 | NVIDIA open driver + compute utils | [docs/03-nvidia-driver.md](docs/03-nvidia-driver.md) | `ansible` role `nvidia` | ✅ 580.178.04 |
| 5 | Kubernetes (RKE2, single node) | [docs/04-kubernetes-rke2.md](docs/04-kubernetes-rke2.md) | `ansible` role `rke2` | ✅ v1.36.5+rke2r1 |
| 6 | SUSE AI stack | [docs/05-suse-ai.md](docs/05-suse-ai.md) | `ansible` role `suse_ai` | 🟡 ch.3 done (GPU Operator, storage); ch.4 next |
| – | Troubleshooting log | [docs/troubleshooting.md](docs/troubleshooting.md) | – | – |

## Repo layout

```
.
├── README.md
├── docs/                    # Step-by-step narrative, one file per phase
├── scripts/
│   └── 00-bootstrap.sh      # First run on the fresh host: register, update, install Ansible
└── ansible/
    ├── ansible.cfg
    ├── requirements.yml     # Ansible collections
    ├── inventory/hosts.yml
    ├── group_vars/all/
    │   ├── main.yml         # Central knobs (hostname, driver flavor, versions, toggles)
    │   └── vault.yml        # ansible-vault encrypted regcodes
    ├── site.yml             # Runs all roles in order (use --tags to run one phase)
    └── roles/
        ├── sudo/            # Passwordless sudo for the Ansible user
        ├── registration/    # SUSEConnect to SCC (regcode from vault)
        ├── repos/           # Install-media cleanup, extra repos, zypper patch
        ├── bootloader/      # Strip failsafe installer kernel options (nomodeset, 3)
        ├── base/            # Repos, packages, firewall, users, etc.
        ├── nvidia/          # Open G06 driver (signed KMP) + nvidia-compute-utils
        ├── rke2/            # Single-node RKE2
        └── suse_ai/         # GPU Operator + SUSE AI components (stub)
```

## Quick start (from your workstation)

```bash
# On the host console after first boot: sudo systemctl enable sshd --now
ssh-copy-id mansible@10.10.12.252
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml --tags sudo -K     # ROOT password (SLES targetpw); one time only
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/suse_ai_vault_pass
ansible-playbook site.yml --tags registration,repos,bootloader   # then reboot
ansible-playbook site.yml --tags base
ansible-playbook site.yml --tags nvidia     # reboot when prompted, then verify with nvidia-smi
ansible-playbook site.yml --tags rke2
```
