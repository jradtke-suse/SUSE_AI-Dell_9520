# Working notes: SUSE AI on SLES 16 ("jarvis", "wheatley")

Project context, rules and gotchas for whoever picks this up next (including Claude Code sessions). Read [README.md](../README.md) (status table, quick start) and [docs/backlog.md](backlog.md) (open items) first.

## What this is

James Radtke (SUSE) documents and automates **SUSE AI 1.0** on single SLES 16.0 + NVIDIA nodes. **jarvis** (custom desktop, RTX 4060 Ti 16 GB) is the long-running node and the **primary host for development**; **wheatley** (Dell XPS 15 9520, RTX 3050 Ti 4 GB) was the first build. Both run **SLES 16.0**, "the SUSE way" (SUSE-signed open NVIDIA KMP, RKE2 from Rancher Prime, charts from SUSE Application Collection).
- Reference guide: https://documentation.suse.com/suse-ai/1.0/html/AI-deployment/ (written for SLES 15 SP6). Follow it loosely and record **every** SLES 16 / version difference in [docs/sles16-deltas.md](sles16-deltas.md) and the relevant doc.
- Ansible runs **from the workstation** (`ansible/inventory/hosts.yml`): `jradtke@10.10.12.250` (jarvis), `mansible@10.10.12.252` (wheatley). **Always `--limit <host>`.** Per-host settings in `ansible/host_vars/`. Secrets: `ansible/vault/<host>.yml` if present (wheatley), else read from the host: `~/.config/SUSE/creds` (shell KEY=value) and the AWS shared credentials file `~/.config/aws/creds` (jarvis). When inspecting creds files, print key names only. Roles in `ansible/site.yml` order: sudo, registration, repos, bootloader, base, nvidia, rke2, suse_ai. Each role has its own tag; sub-tags include wifi, gnome_power, helm, storage, gpu_operator, registry, cert_manager, ollama, open_webui.
- Docs live in `docs/00-...05-*.md`, plus troubleshooting, deltas, backlog.

## Current state: jarvis (2026-11-03)

- SLES 16.0, registered to SCC (internal subscription) with Package Hub. Windows on `sda` (os-prober). Secure Boot off. NVIDIA drives the display (no iGPU), so `nvidia-gl-G06` is required for GNOME.
- Same stack as wheatley below: NVIDIA 580.178.04 (locked), RKE2 v1.36.5+rke2r1, GPU Operator v26.7.2, cert-manager, Ollama with **llama3.1:8b** (default, 100% GPU), llama3.2:3b, gemma:2b.
- Open WebUI at **https://jarvis.homelab.kubernerdes.com**, Let's Encrypt via Route53 DNS-01 (IAM user `ciol-route53`, key in `~/.config/aws/creds` on jarvis).
- Ollama API exposed at **https://ollama.jarvis.homelab.kubernerdes.com** (Traefik ingress, Let's Encrypt; `ollama_ingress_host`) for LiteLLM on nuc-00. No auth on Ollama: LAN-reachable. DNS: Pi-hole wildcard `*.jarvis.homelab.kubernerdes.com` -> 10.10.12.250.
- Workstation kubeconfig: `~/.kube/homelab-jarvis.kubeconfig`.
- **LiteLLM gateway**: SL Micro 6.2 VM `litellm` (10.10.12.13) on nuc-00, `ansible-playbook litellm.yml` (group `litellm_gateways`; `site.yml` only targets `suse_ai_nodes`). LiteLLM v1.106.6 + PostgreSQL 17 as Podman quadlets; master key in `/etc/litellm/litellm.env` on the VM. See [06](06-litellm.md).

## Current state: wheatley (2026-11-01)

- SLES 16.0, kernel 6.12.0-160000.40. Registered to SCC with Package Hub (repo name `Backports-16.0`).
- NVIDIA: SUSE-signed open KMP **580.178.04**. Userspace from NVIDIA's sles15 CUDA repo, pinned **and zypper-locked**. NVIDIA DKMS driver + dkms are locked out.
- RKE2 **v1.36.5+rke2r1**, single node, SELinux enforcing, installed to `/opt/rke2`, ingress = **traefik**. Pods get `/etc/rancher/rke2/resolv.conf` (no search domains).
- suse_ai role: Helm 3.21.3 (locked), local-path storage, GPU Operator v26.7.2 (CDI), cert-manager 1.21.3, Ollama (gemma:2b, llama3.2:3b, 100% GPU), Open WebUI at **https://wheatley.homelab.kubernerdes.com** with a Let's Encrypt cert via Route53 DNS-01.
- Host is imported into the user's Rancher Manager (fleet/cattle agents present; leave them alone).
- Names: `wheatley.homelab.kubernerdes.com` = 10.10.12.252 (wired, DHCP reservation). `wheatley-wifi` = .249 (WiFi radio currently off). DNS is a Pi-hole at 10.10.12.10, managed by the user.
- Workstation kubeconfig: `~/.kube/homelab-wheatley.kubeconfig` (written by the rke2 role).

## Rules the user has set

- **Commit and push only when the user approves, each time.** End commit messages with the Co-Authored-By line from the session's attribution guidance.
- **Secrets never go in plaintext in the repo.** They live in the encrypted `ansible/vault/wheatley.yml` (password file `~/.ansible/suse_ai_vault_pass`, outside the repo; never commit it). Use `no_log: true` on tasks that handle secrets. Scratch plaintext only in the session scratchpad with `umask 077`, deleted right after.
- **Before every commit, scan for secrets.** This checks the working tree for every value stored in the vault, plus AWS key IDs, without writing the secrets anywhere (run from the repo root):
  ```bash
  grep -rnF --exclude-dir=.git -f <(ansible-vault view ansible/vault/wheatley.yml \
      --vault-password-file ~/.ansible/suse_ai_vault_pass | sed -nE 's/^vault_[a-z0-9_]+: "(.+)"$/\1/p') . \
    && echo "SECRET FOUND" || echo "clean"
  grep -rnE "AKIA[A-Z0-9]{12,}" . --exclude-dir=.git | grep -v AKIAXXXX
  ```
  Also never commit host account passwords (the `mansible` login, root), which aren't in the vault.
- Prefer SUSE-packaged/signed components. When deviating from the guide, say why in the docs.
- Keep roles idempotent: a second run should report `changed=0`.

## Gotchas learned the hard way

- SLES 16 sudo uses `Defaults targetpw` (root's password) until the sudo role runs.
- `zypper patch` returns 103 when zypper updated itself (re-run it). Use `--with-interactive` for reboot-flagged patches.
- A plain `zypper up` on the host will try to move NVIDIA userspace and Helm. Locks prevent this; the roles unlock, pin and re-lock.
- Ansible handler names are global across roles. Don't define the same handler twice (`restart rke2-server` lives in the rke2 role).
- `ansible.builtin.command` with a plain string strips backslashes (e.g. `nvidia\.com`). Use `argv:`.
- SELinux: kubelet-created hostPath dirs can get `usr_t`. `restorecon` them (`/opt/local-path-provisioner`). Never `restorecon -F` under `/var/lib/rancher` on a running node.
- Helm registry logins are root's. For manual chart commands on the host use `sudo -H helm ...`.
- The LAN DNS is split-horizon for `homelab.kubernerdes.com`, so cert-manager uses public resolvers for the DNS-01 self-check.
- Changing the node IP needs `rke2 server --cluster-reset` (see docs/04).
- The Ollama image has no curl. Test the API from the open-webui pod.

## Next up

LiteLLM follow-ups (HTTPS, Open WebUI). See [docs/backlog.md](backlog.md).
