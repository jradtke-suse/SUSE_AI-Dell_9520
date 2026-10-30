# 03 - NVIDIA Driver (the SUSE way)

## Decision: open driver, SUSE-signed KMP

| Option | Choice | Why |
|--------|--------|-----|
| Open vs proprietary kernel modules | **Open (G06)** | SUSE's recommended path for Turing+ GPUs. The RTX 3050 Ti is Ampere. |
| Packaging | **SUSE signed KMP** (`nvidia-open-driver-G06-signed-kmp-*`) | Prebuilt and signed by SUSE, so it works with Secure Boot and needs no MOK enrollment or DKMS |
| Userspace / compute | `nvidia-compute-utils-G06` (and `nvidia-compute-G06`) from NVIDIA's repo | Gives you `nvidia-smi` and CUDA libraries. Version **must match** the KMP version. |
| Display | Intel iGPU drives the display. NVIDIA is used for compute/offload | Avoids hybrid-graphics headaches on the desktop |

> ⚠️ Verify package names and the repo URL against the current SUSE AI 1.0 docs and the SLES 16 repos (`zypper se nvidia`). They are variables in `ansible/roles/nvidia/defaults/main.yml`.

## Automated

```bash
ansible-playbook site.yml --tags nvidia
sudo reboot
```

## Manual equivalent (for reference)

```bash
zypper se -s nvidia-open-driver            # see available KMP versions
# add NVIDIA repo for compute utils (verify URL for SLES 16)
zypper ar -f <nvidia_repo_url> nvidia-cuda
zypper --gpg-auto-import-keys refresh
VER=$(rpm -qa --queryformat '%{VERSION}\n' nvidia-open-driver-G06-signed-*kmp-default | cut -d_ -f1 | sort -u | tail -1)
zypper in -y --auto-agree-with-licenses nvidia-compute-utils-G06=${VER} nvidia-compute-G06=${VER}
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
