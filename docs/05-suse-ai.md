# 05 - SUSE AI 1.0

## Prerequisites

- [ ] SUSE Application Collection account + access token (`dp.apps.rancher.io`), stored in the vault (or `APPCO_USERNAME`/`APPCO_TOKEN`/`REGCODE_AI` in `~/.config/SUSE/creds` on the host):
  ```bash
  cd ansible
  ansible-vault edit vault/wheatley.yml --vault-password-file ~/.ansible/suse_ai_vault_pass
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
| 4.8 | Open WebUI chart **8.19.1** (app 0.6.41), standalone-Ollama variant, ingress **traefik**, TLS from **Let's Encrypt** (Route53 DNS-01) | ✅ |

**Open WebUI:** https://wheatley.homelab.kubernerdes.com
- The first account you create becomes the admin.
- The certificate is a trusted Let's Encrypt cert, so there's no browser warning.

### Names (DNS is managed outside this repo)

One name per host. The wired address is the host.

| Name | Address | Notes |
|---|---|---|
| `wheatley.homelab.kubernerdes.com` | 10.10.12.252 (wired, DHCP reservation) | Node IP, SSH/Ansible, Kubernetes API, Open WebUI |
| `wheatley-wifi.homelab.kubernerdes.com` | 10.10.12.249 (WiFi) | WiFi sends `wheatley-wifi` as its DHCP hostname (`wifi_dhcp_hostname`), so it never claims `wheatley`. Radio currently off. |

- Off the home network, wheatley gets whatever DHCP hands out and nothing here depends on it. Back home, wired is `.252` again.
- The RKE2 API cert covers `wheatley.homelab.kubernerdes.com` and `10.10.12.252` (`rke2_tls_san`). An old `glados` name lingers there harmlessly, because RKE2 keeps SANs it has already added.
- Mac on another network: add `/etc/resolver/homelab.kubernerdes.com` with `nameserver 10.10.12.10`, or an `/etc/hosts` entry.

### TLS: Let's Encrypt via Route53 DNS-01

- **Issuers:** ClusterIssuers `letsencrypt-staging` and `letsencrypt-prod` answer the DNS-01 challenge in the public Route53 zone `kubernerdes.com` (`Z03970223DJDS89C1XW4A`). They use IAM user `ciol-route53`. The key is in the vault (`vault_route53_*`), and Ansible stores it in Secret `cert-manager/route53-credentials`.
- **Public resolvers for the self-check.** cert-manager runs with `dns01RecursiveNameservers=1.1.1.1:53,8.8.8.8:53` and `dns01RecursiveNameserversOnly=true`. The LAN DNS answers `homelab.kubernerdes.com` itself, so it never sees the public `_acme-challenge` TXT record, and without this cert-manager waits forever.
- **The certificate.** `open-webui-le` covers `wheatley.homelab.kubernerdes.com` and is stored in Secret `open-webui-le-tls`. Open WebUI uses it via `global.tls.source=secret` + `ingress.existingSecret`. cert-manager renews it automatically.
- **Testing the flow:** `ansible-playbook site.yml --tags open_webui -e open_webui_cert_issuer=letsencrypt-staging`. To go back to the chart's self-signed CA: `-e open_webui_cert_issuer=""`.
- **Security note:** the Route53 key now sits in the cluster, so anyone with cluster-admin can read it. A narrower IAM policy (only `kubernerdes.com`, only `_acme-challenge.*` TXT records) would limit that.

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

