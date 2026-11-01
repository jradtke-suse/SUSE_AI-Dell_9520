# Backlog

Paused 2026-11-01 with SUSE AI running (Ollama on GPU + Open WebUI at https://wheatley.homelab.kubernerdes.com). Resuming on another workstation: see the README section "Resuming on another workstation".

## Next up

- [ ] **LiteLLM on SLE 16 virtual machines.** Figure out running LiteLLM (an OpenAI-compatible proxy/gateway in front of Ollama and other model backends) on SLES 16 VMs.
  - Guide reference: SUSE AI 1.0 §4.13 "Installing LiteLLM" (Application Collection chart `oci://dp.apps.rancher.io/charts/litellm`). The guide assumes Kubernetes, so a plain VM deployment is a deviation to document.
  - Open questions: KVM on wheatley itself (BIOS VT-x/VT-d are on) or another host? Container (podman) or package install in the VM? Point it at Ollama on wheatley (`ollama.suse-ai.svc` isn't reachable from outside, so it needs an ingress or NodePort) and hook it into Open WebUI (`OPENAI_API_BASE_URLS`).

## Optional (from the guide)

- [ ] Vector DB for RAG: OpenSearch single-node (§4.5, needs `vm.max_map_count=262144`) or Milvus (§4.6, heavier)
- [ ] SUSE Security / NeuVector (§3.5), via Rancher Manager

## Housekeeping

- [ ] Rotate the Application Collection token (it was pasted in a chat session). Update `vault_appco_token`, rerun `--tags registry`.
- [ ] Narrow Route53 access: a dedicated IAM user limited to `_acme-challenge.*` TXT records in `kubernerdes.com` (policy in [05](05-suse-ai.md)). Deferred; it's a lab.
- [ ] Unplug the USB installer stick (`sda`)
- [ ] Secure Boot: currently disabled, firmware in Setup Mode. The SUSE-signed KMP is ready for it.
- [ ] Run the `base` role in full (only the `wifi` / `gnome_power` tags have run)
- [ ] Lid-close behaviour on AC
