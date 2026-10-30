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

## Steps (to flesh out)

1. **NVIDIA GPU Operator** with `driver.enabled=false`, because the host already has the SUSE driver. Point the toolkit at RKE2's containerd paths.
2. Verify GPU is schedulable: `kubectl describe node | grep nvidia.com/gpu`
3. Log in to the Application Collection registry and create the pull secret. Creds are `appco_username` / `appco_token` from the vault. The AppCo login (`jamradtke@suse.com`) is **not** the SCC email.
   ```bash
   helm registry login dp.apps.rancher.io -u <appco_username> -p <appco_token>
   kubectl create secret docker-registry application-collection \
     --docker-server=dp.apps.rancher.io \
     --docker-username=<appco_username> --docker-password=<appco_token> -n <namespace>
   ```
4. Deploy SUSE AI components: Ollama, Open WebUI, Milvus (optional)
5. (Optional) SUSE Security (NeuVector) and SUSE Observability

> With 4 GB VRAM, stick to small models (e.g. ~3B–8B quantized).

## Results

_record versions, values files, screenshots_
