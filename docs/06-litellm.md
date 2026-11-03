# 06 - LiteLLM gateway (SL Micro 6.2 VM)

LiteLLM is an OpenAI-compatible gateway in front of Ollama (and other model backends). It adds API keys, per-key budgets and usage tracking.

The SUSE AI 1.0 guide (§4.13) installs LiteLLM on Kubernetes with a Helm chart. Here it runs on a small **SL Micro 6.2** VM instead, as two Podman containers managed by systemd. Automation: `ansible/litellm.yml`, role `litellm`.

| | |
|---|---|
| VM | `litellm` on nuc-00 (KVM), 2 vCPU, 4 GB RAM, 32 GB, UEFI + Secure Boot |
| Address | `litellm.homelab.kubernerdes.com` = 10.10.12.13 (static), MAC `52:54:00:a3:cc:a2` |
| OS | SL Micro 6.2 (`/etc/os-release` says `NAME="SLES" VARIANT="Micro" VERSION="16.0"`, it's the same code base) |
| LiteLLM | `registry.suse.com/ai/containers/litellm:v1.106.6`, https://litellm.homelab.kubernerdes.com (port 4000 on 127.0.0.1 only) |
| HTTPS | Traefik `registry.rancher.com/rancher/hardened-traefik:v3.7.16` (same image as RKE2) on 443, Let's Encrypt via Route53 DNS-01, auto-renewed |
| Database | `dp.apps.rancher.io/containers/postgresql:17`, volume `litellm-db` |
| Backend | Ollama on jarvis: https://ollama.jarvis.homelab.kubernerdes.com |

## 1. Build the VM (manual)

On nuc-00 (log in as `root`): the SL Micro 6.2 **Default** qcow2 image, already 32 GB virtual, at `/var/lib/libvirt/images/litellm/litellm.qcow2`.

```bash
virt-install --import --name litellm \
  --memory 4096 --vcpus 2 --cpu host-passthrough \
  --os-variant slem6.2 --boot uefi \
  --disk path=/var/lib/libvirt/images/litellm/litellm.qcow2,format=qcow2,bus=virtio \
  --network network=virbr0,model=virtio \
  --graphics spice,listen=127.0.0.1 --serial pty --console pty,target_type=serial \
  --autostart --noautoconsole
```

`virbr0` is bridged to the LAN (`eth0`), so the VM gets a LAN address.

First boot runs **JeOS Firstboot** on the console (virt-manager / `virt-viewer -c qemu+ssh://root@10.10.12.10/system litellm`). Then, as root on the console:

```bash
# Static IP (connection name from: nmcli -t -f NAME,DEVICE connection show)
nmcli connection modify "<name>" ipv4.method manual \
  ipv4.addresses 10.10.12.13/22 ipv4.gateway 10.10.12.1 \
  ipv4.dns 10.10.12.10 ipv4.dns-search homelab.kubernerdes.com
nmcli connection up "<name>"
hostnamectl set-hostname litellm

# Ansible user (matches ~/.ssh/config for 10.10.12.*)
useradd -m mansible && passwd mansible
echo 'mansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-mansible
chmod 440 /etc/sudoers.d/90-mansible

# Register (SL Micro regcode, not the SLES one), then reboot into the new snapshot
transactional-update register -r <REGCODE> -e <email>
reboot
```

`/etc` is writable on SL Micro, so network, users and sudoers apply right away. Package changes need `transactional-update` + reboot.

From the workstation: `ssh-copy-id -i ~/.ssh/id_rsa-kubernerdes.pub mansible@10.10.12.13`

## 2. Credentials on the VM

`~/.config/SUSE/creds` for `mansible`, mode 600 (same format as jarvis):

```bash
APPCO_USERNAME=...     # Application Collection (PostgreSQL image)
APPCO_TOKEN=...
REGCODE_AI=...         # SUSE AI regcode: registry.suse.com (LiteLLM image)
```

For HTTPS: `~/.config/aws/creds` (AWS shared credentials format, `[default]` profile, mode 600) with the `homelab-acme` key (ACME-only, see [docs/aws/homelab-acme-policy.json](aws/homelab-acme-policy.json)). Without it, LiteLLM stays on plain HTTP port 4000.

**LiteLLM is not in Application Collection** for this account (no image, no chart, checked 2026-11-03). It's in the SUSE AI registry: `registry.suse.com/ai/containers/litellm`.

## 3. Deploy

```bash
cd ansible
ansible-playbook litellm.yml
```

The role:
- logs in to both registries with a persistent authfile (`/etc/litellm/auth.json`; Podman's default is under `/run`, lost on reboot) and pulls the images
- generates the DB password and the LiteLLM **master key** once, into `/etc/litellm/db.env` and `/etc/litellm/litellm.env` (root, 0600). They never leave the VM.
- writes `/etc/litellm/config.yaml` (models from `litellm_models`) and the Quadlet units in `/etc/containers/systemd/` (`litellm.network`, `litellm-db.volume`, `litellm-db.container`, `litellm.container`)
- with Route53 creds: writes `/etc/litellm/route53.env` (0600) and `/etc/litellm/traefik-dynamic.yaml`, adds the `litellm-proxy` Traefik container on 443 (cert stored in volume `litellm-proxy`), and publishes 4000 on 127.0.0.1 only
- starts `litellm-db`, `litellm` (and `litellm-proxy`), waits for `/health/liveliness` and, with HTTPS, for a verified `https://litellm.homelab.kubernerdes.com`

## 4. Use it

```bash
# Master key (admin). Use it to create per-app keys; don't hand it out.
ssh 10.10.12.13 sudo grep LITELLM_MASTER_KEY /etc/litellm/litellm.env

curl https://litellm.homelab.kubernerdes.com/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"hello"}]}'
```

Admin UI: https://litellm.homelab.kubernerdes.com/ui (user `admin`, password = master key).

Models: `llama3.1:8b`, `llama3.2:3b`, `gemma:2b` (all on jarvis). Change `litellm_models` in `roles/litellm/defaults/main.yml` (or `host_vars/litellm.yml`) and rerun.

## Gotchas

- **Never restart LiteLLM during its first start.** It runs ~200 database migrations on first boot. Killing it mid-way leaves the DB in a failed state (Prisma `P3009`, "migration ... failed"), and LiteLLM refuses to start. The role only restarts LiteLLM if it was already running, and the container gets 120 s to stop. Recovery on a fresh install: `systemctl stop litellm litellm-db; podman volume rm litellm-db`, rerun the playbook.
- DNS-01 self-check uses public resolvers (1.1.1.1, 8.8.8.8): the Pi-hole answers `homelab.kubernerdes.com` itself and never sees the public `_acme-challenge` TXT record. Same reason as cert-manager on jarvis.
- Updates: `transactional-update` runs on a timer (`transactional-update.timer`). Containers keep running across OS updates; a reboot restarts them.

## Not done yet

- Hook LiteLLM into Open WebUI (`OPENAI_API_BASE_URLS`)
- Restrict Ollama on jarvis to LiteLLM only
