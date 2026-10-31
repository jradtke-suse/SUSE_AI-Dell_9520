# 05 - SUSE AI 1.0

## Prerequisites

- [ ] SUSE Application Collection account + access token (`dp.apps.rancher.io`), stored in the vault:
  ```bash
  cd ansible
  ansible-vault edit group_vars/all/vault.yml --vault-password-file ~/.ansible/suse_ai_vault_pass
  # set vault_appco_username and vault_appco_token (currently CHANGE_ME)
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

## Next: guide chapter 4 (to flesh out)

1. Namespace + pull secrets: `application-collection` (dp.apps.rancher.io) and `suse-ai-registry` (registry.suse.com, user `regcode`, SUSE AI regcode from the vault)
2. Log in to the Application Collection registry and create the pull secret. Creds are `appco_username` / `appco_token` from the vault. The AppCo login (`jamradtke@suse.com`) is **not** the SCC email.
   ```bash
   helm registry login dp.apps.rancher.io -u <appco_username> -p <appco_token>
   kubectl create secret docker-registry application-collection \
     --docker-server=dp.apps.rancher.io \
     --docker-username=<appco_username> --docker-password=<appco_token> -n <namespace>
   ```
3. cert-manager (`oci://dp.apps.rancher.io/charts/cert-manager`, `crds.enabled=true`)
4. Ollama (`gpu.enabled: true`) and Open WebUI (ingress class **traefik**, storage `local-path`). Vector DB (Milvus/OpenSearch) later.
5. (Optional) SUSE Security (NeuVector)

> With 4 GB VRAM, stick to small models (e.g. ~3B–8B quantized).

## Results

_record versions, values files, screenshots_
