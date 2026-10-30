# 03 - NVIDIA Driver (the SUSE way)

Follows [SUSE AI guide §2.2.1](https://documentation.suse.com/suse-ai/1.0/html/AI-deployment/ai-deployment-kube-installing.html), adjusted for SLES 16. See [sles16-deltas.md](sles16-deltas.md).

## Decision: open driver, SUSE-signed

| Item | Choice | Why |
|------|--------|-----|
| Kernel driver | `nv-prefer-signed-open-driver` (SLES 16 product repo) | Same as the guide. SUSE-signed open G06 modules, so Secure Boot works with no MOK enrollment. The RTX 3050 Ti is Ampere, which the open modules support. |
| Userspace | `nvidia-compute-utils-G06` + `nvidia-persistenced` from NVIDIA's **sles15** CUDA repo | NVIDIA's sles16 repo has no driver userspace yet. Pinned to the driver version. |
| Vulkan | `nvidia-gl-G06`, off by default (`nvidia_install_gl`) | Only needed for Vulkan apps |
| Display | The Intel iGPU drives the display | NVIDIA is used for compute only |

## Automated

```bash
ansible-playbook site.yml --tags nvidia
ssh mansible@192.168.0.103 sudo reboot
```

## Manual equivalent (as on SLES 16)

```bash
zypper in -y --auto-agree-with-licenses nv-prefer-signed-open-driver
version=$(rpm -qa --queryformat '%{VERSION}\n' nv-prefer-signed-open-driver | cut -d_ -f1 | sort -u | tail -n1)
zypper ar https://developer.download.nvidia.com/compute/cuda/repos/sles15/x86_64/ cuda-sle15
zypper --gpg-auto-import-keys refresh
zypper in -y --auto-agree-with-licenses nvidia-compute-utils-G06=${version} nvidia-persistenced=${version}
reboot
```

## Verify

```bash
nvidia-smi
lsmod | grep nvidia
modinfo nvidia | grep -E 'license|signer'   # expect Dual MIT/GPL and a SUSE signer
mokutil --sb-state
```

## Results

_record driver version, nvidia-smi output, any issues here_
