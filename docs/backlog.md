# Backlog

Updated 2026-11-03. **jarvis** is the long-running node and the primary host for new work (SUSE AI running: Ollama on GPU + Open WebUI at https://jarvis.homelab.kubernerdes.com). wheatley still runs the same stack at https://wheatley.homelab.kubernerdes.com. Resuming on another workstation: see the README section "Resuming on another workstation".

## Next up

- [x] **LiteLLM gateway** on an SL Micro 6.2 VM on nuc-00 (2026-11-03). See [06](06-litellm.md).
- [ ] **LiteLLM follow-ups**
  - HTTPS in front of port 4000 (e.g. Caddy/Traefik container with a Route53 DNS-01 cert for `litellm.homelab.kubernerdes.com`)
  - Hook into Open WebUI on jarvis (`OPENAI_API_BASE_URLS` + a LiteLLM virtual key)
  - Restrict Ollama on jarvis to LiteLLM only (Traefik IP allow-list for 10.10.12.13)
- [ ] **Bigger models on jarvis.** 16 GB VRAM fits 12-14B models (e.g. `qwen2.5:14b`, `gemma2:9b`). Change `ollama_models_*` in `ansible/host_vars/jarvis.yml`, rerun `--tags ollama`.

## Optional (from the guide)

- [ ] Vector DB for RAG on jarvis: OpenSearch single-node (§4.5, needs `vm.max_map_count=262144`) or Milvus (§4.6, heavier)
- [ ] SUSE Security / NeuVector (§3.5), via Rancher Manager

## Housekeeping

### Both hosts

- [ ] **Rotate the Application Collection token.** Exposed in chat sessions twice (2026-11-01 and 2026-11-03). Update `APPCO_TOKEN` in `~/.config/SUSE/creds` on jarvis and `vault_appco_token` in `vault/wheatley.yml`, then rerun `--tags registry` on each host.
- [ ] **Narrow Route53 access.** jarvis and its cluster now hold the `ciol-route53` key (`~/.config/aws/creds`, plus the `route53-credentials` secret). Create one IAM user per host, limited to `_acme-challenge.*` TXT records in `kubernerdes.com` (policy in [05](05-suse-ai.md)).

### jarvis

- [ ] Unplug the USB installer stick (`sdb`)
- [ ] Secure Boot: currently disabled. The SUSE-signed KMP is ready for it.
- [ ] Import into Rancher Manager (as wheatley is)

### wheatley

- [ ] Decide its role now that jarvis is primary: secondary/test box, or retire
- [ ] Unplug the USB installer stick (`sda`)
- [ ] Secure Boot: currently disabled, firmware in Setup Mode. The SUSE-signed KMP is ready for it.
- [ ] Run the `base` role in full (only the `wifi` / `gnome_power` tags have run)
- [ ] Lid-close behaviour on AC
