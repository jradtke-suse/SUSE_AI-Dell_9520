# 05 - SUSE AI 1.0

## Prerequisites

- [ ] SUSE Application Collection account + access token (`dp.apps.rancher.io`), stored in the vault:
  ```bash
  cd ansible
  ansible-vault edit group_vars/all/vault.yml --vault-password-file ~/.ansible/suse_ai_vault_pass
  # vault_appco_username, vault_appco_token, vault_suse_ai_regcode
  ```
- [ ] RKE2 running ([04](04-kubernetes-rke2.md))
- [ ] Host NVIDIA driver working ([03](03-nvidia-driver.md))

## Done: guide chapter 3 (single node)

Run with `ansible-playbook site.yml --tags suse_ai` (or `--tags helm`, `storage`, `gpu_operator`).

| Guide § | What | Status |
|---|---|---|
| 3.1 Rancher Prime | Skipped. The guide wants a separate cluster; not needed on one laptop. | ⏭ |
| (gap) | **Helm 3.21.3** from the SLES 16 product repo, **locked**. `zypper up` would move it to 4.x. | ✅ |
| (gap) | **local-path-provisioner v0.0.37** via the RKE2 manifests dir. Images from `registry.rancher.com`. Default StorageClass `local-path`. `/opt/local-path-provisioner` is already `container_file_t`. | ✅ |
| 3.2 NVIDIA GPU Operator | **v26.7.2** (guide: v25.3.4) via a `HelmChart` in the RKE2 manifests dir. `driver.enabled=false`, toolkit dir added to RKE2's PATH (`/etc/default/rke2-server`). | ✅ |
| 3.3 Register clusters | Skipped (no Rancher) | ⏭ |
| 3.4 Assign GPU nodes | Skipped (one node) | ⏭ |
| 3.5 SUSE Security / 3.6 Observability | Optional, not yet | ⬜ |

### GPU Operator: differences from the guide

- **Chart version v26.7.2.** v25.3.4 predates RKE2 v1.36 / containerd 2.3.
- **Dropped `devicePlugin.env DEVICE_LIST_STRATEGY=volume-mounts`.** v26 enables CDI by default (`cdi.enabled: true`). With volume-mounts, the runtime asks for a per-GPU CDI device that nothing generates:
  `failed to inject CDI devices: unresolvable CDI devices management.nvidia.com/gpu=GPU-...`.
  Without the override, the device plugin writes `/var/run/cdi/k8s.device-plugin.nvidia.com-gpu.json` and the guide's test pod works **as written** (no `runtimeClassName`).
- The toolkit `env` values (`CONTAINERD_SOCKET=/run/k3s/containerd/containerd.sock`, `ACCEPT_*`) are kept. That socket path is correct for RKE2.

### Results (2026-10-30)

Guide 3.2 checks: `nvidia.com/gpu.deploy.driver=true`, `nvidia.com/gpu.product=NVIDIA-GeForce-RTX-3050-Ti-Laptop-GPU`, allocatable `nvidia.com/gpu: 1`, `/usr/local/nvidia/toolkit/nvidia-container-runtime` present, `nvidia` runtimes in containerd's config.

Guide nbody test pod:
```
> Compute 8.6 CUDA device: [NVIDIA GeForce RTX 3050 Ti Laptop GPU]
20480 bodies, total time for 10 iterations: 28.514 ms
= 147.095 billion interactions per second
= 2941.895 single-precision GFLOP/s at 20 flops per interaction
```

## Done: guide chapter 4 (single node)

Run with `ansible-playbook site.yml --tags suse_ai` (or `--tags registry`, `cert_manager`, `ollama`, `open_webui`).

| Guide § | What | Result |
|---|---|---|
| 4.3 | Namespaces `suse-ai` + `cert-manager`. Pull secrets `application-collection` (dp.apps.rancher.io) and `suse-ai-registry` (registry.suse.com, user `regcode`, **SUSE AI regcode**) in both. `helm registry login` to both. All creds from the vault, `no_log`. | ✅ |
| 4.4 | cert-manager **1.21.3** (`oci://dp.apps.rancher.io/charts/cert-manager`, `crds.enabled=true`) | ✅ |
| 4.5/4.6 | OpenSearch / Milvus | ⏭ not yet. Open WebUI uses its built-in vector store. |
| 4.7 | Ollama chart **1.93.0** (app 0.40.12), GPU on, 30Gi `local-path` PV. Models `gemma:2b`, `llama3.2:3b`. | ✅ 100% GPU |
| 4.8 | Open WebUI chart **8.19.1** (app 0.6.41), standalone-Ollama variant, ingress **traefik**, TLS from cert-manager's `suse-private-ai` self-signed CA | ✅ |

**Open WebUI:** https://wheatley.homelab.kubernerdes.com
- The first account you create becomes the admin.
- The cert is self-signed (issuer `CN=suse-private-ai-selfsigned-ca`), so expect a browser warning.
- That name resolves to the WiFi IP (`.249`). Traefik listens on all host interfaces, so it works either way.

**kubectl from the workstation:** `KUBECONFIG=~/.kube/homelab-wheatley.kubeconfig kubectl get pods -n suse-ai` (written by the `rke2` role).

### Differences from the guide

- **Models:** the guide's example pulls `llama3.1` (8B, ~4.9 GB), which won't fit in 4 GB VRAM. We use `gemma:2b` (preloaded) + `llama3.2:3b`. Ollama swaps them on demand.
- **Ingress class `traefik`**, not nginx. The chart still adds the `nginx.ingress.kubernetes.io/ssl-redirect` annotation, which traefik ignores, so plain HTTP isn't redirected.
- **`enableOpenaiApi: false`.** The chart default points Open WebUI at `api.openai.com`.
- **No pipelines / Milvus / OTEL** env vars yet.
- **local-path dir SELinux label.** The policy maps `/opt/local-path-provisioner` to `container_file_t`, but the kubelet created it as `usr_t`. The first PVC then failed (`mkdir: Permission denied`, helper "create process timeout"). The `storage` tasks now create the dir and `restorecon` it.
- Helm logins run as root (Ansible `become`). To use the charts by hand: `sudo -H helm ...`.

### Results (2026-10-31)

```
$ kubectl exec -n suse-ai deploy/ollama -- ollama ps
NAME        SIZE      PROCESSOR    CONTEXT
gemma:2b    1.9 GB    100% GPU     4096
```

| Model | Speed (RTX 3050 Ti, 4 GB) |
|---|---|
| gemma:2b | ~86 tokens/s |
| llama3.2:3b | ~66 tokens/s |

### Next (optional)

- Vector DB for RAG (Milvus or OpenSearch, guide 4.5/4.6)
- SUSE Security (NeuVector, guide 3.5)
- DNS name for `.252`, or a trusted cert

