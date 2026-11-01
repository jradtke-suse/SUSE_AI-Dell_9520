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
| 6 | SUSE AI stack | [docs/05-suse-ai.md](docs/05-suse-ai.md) | `ansible` role `suse_ai` | ✅ Ollama (GPU) + Open WebUI |
| – | Troubleshooting log | [docs/troubleshooting.md](docs/troubleshooting.md) | – | – |

Open items and ideas: [docs/backlog.md](docs/backlog.md) (next up: LiteLLM on SLE 16 VMs).

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
ansible-playbook site.yml --tags rke2       # also writes ~/.kube/homelab-wheatley.kubeconfig
ansible-playbook site.yml --tags suse_ai    # GPU Operator, cert-manager, Ollama, Open WebUI
```

## Resuming on another workstation

The repo has everything except the **vault password**. Bring that over yourself; it isn't stored anywhere else.

1. **Copy the vault password** from the old machine (`~/.ansible/suse_ai_vault_pass`) to the same path on the new one, mode 600. Use a password manager or `scp`, never git. Without it, `group_vars/all/vault.yml` can't be decrypted. You'd have to rebuild it from `vault.yml.example` (SCC + SUSE AI regcodes, AppCo token, WiFi PSK, Route53 key).
   ```bash
   mkdir -p ~/.ansible && chmod 700 ~/.ansible
   # paste/copy the file, then:
   chmod 600 ~/.ansible/suse_ai_vault_pass
   ansible-vault view ansible/group_vars/all/vault.yml --vault-password-file ~/.ansible/suse_ai_vault_pass >/dev/null && echo vault OK
   ```
2. **Install the tools:** `ansible-core`, `kubectl`, and the collections with `cd ansible && ansible-galaxy collection install -r requirements.yml`.
3. **SSH key:** `ssh-copy-id mansible@wheatley.homelab.kubernerdes.com` (or `@10.10.12.252`). Then `ansible all -m ping`.
4. **Kubeconfig:** `ansible-playbook site.yml --tags rke2` rewrites `~/.kube/homelab-wheatley.kubeconfig`. A no-op run otherwise.
5. **Name resolution:** on a network whose DNS doesn't know `homelab.kubernerdes.com`, add `/etc/resolver/homelab.kubernerdes.com` with `nameserver 10.10.12.10` (macOS). The inventory uses the IP, so Ansible works either way.

Current state and open items: [docs/backlog.md](docs/backlog.md). Project context, rules and gotchas: [docs/working-notes.md](docs/working-notes.md).
