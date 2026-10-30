# README

This will provide guidance, step-by-step, on how to deploy SUSE AI 1.0 on a Dell XPS 15 9520 with an NVIDIA GeForce RTX 3050 Ti Laptop GPU

**Approach:** follow "the SUSE way" wherever possible: SUSE-packaged and SUSE-signed components first (e.g. the **open** NVIDIA kernel driver as a signed KMP rather than the proprietary `.run` installer), SUSE Rancher Prime / RKE2 for Kubernetes, and the SUSE Application Collection for SUSE AI components.

## Status

| # | Phase | Doc | Automation | Status |
|---|-------|-----|-----------|--------|
| 0 | Hardware / BIOS prep | [docs/00-hardware.md](docs/00-hardware.md) | n/a | ⬜ |
| 1 | OS installation (SLES 16) | [docs/01-os-installation.md](docs/01-os-installation.md) | n/a (manual, Agama remote install) | 🟨 in progress |
| 2 | Post-install bootstrap | [docs/02-post-install.md](docs/02-post-install.md) | `scripts/00-bootstrap.sh` | ⬜ |
| 3 | Base OS config | [docs/02-post-install.md](docs/02-post-install.md) | `ansible` role `base` | ⬜ |
| 4 | NVIDIA open driver + compute utils | [docs/03-nvidia-driver.md](docs/03-nvidia-driver.md) | `ansible` role `nvidia` | ⬜ |
| 5 | Kubernetes (RKE2, single node) | [docs/04-kubernetes-rke2.md](docs/04-kubernetes-rke2.md) | `ansible` role `rke2` | ⬜ |
| 6 | SUSE AI stack | [docs/05-suse-ai.md](docs/05-suse-ai.md) | `ansible` role `suse_ai` (stub) | ⬜ |
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
    ├── group_vars/all.yml   # Central knobs (driver flavor, versions, toggles)
    ├── site.yml             # Runs all roles in order (use --tags to run one phase)
    └── roles/
        ├── base/            # Repos, packages, firewall, users, etc.
        ├── nvidia/          # Open G06 driver (signed KMP) + nvidia-compute-utils
        ├── rke2/            # Single-node RKE2
        └── suse_ai/         # GPU Operator + SUSE AI components (stub)
```

## Quick start (on the freshly installed host)

```bash
git clone <this repo> && cd SUSE_AI-Dell_9520
sudo REGCODE=<your-SLES-regcode> ./scripts/00-bootstrap.sh
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml --tags base
ansible-playbook site.yml --tags nvidia     # reboot when prompted, then verify with nvidia-smi
ansible-playbook site.yml --tags rke2
```
