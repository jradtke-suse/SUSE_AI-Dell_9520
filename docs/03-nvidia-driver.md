# 03 - NVIDIA Driver (the SUSE way)

Follows [SUSE AI guide §2.2.1](https://documentation.suse.com/suse-ai/1.0/html/AI-deployment/ai-deployment-kube-installing.html), adjusted for SLES 16. See [sles16-deltas.md](sles16-deltas.md).

## Decision: open driver, SUSE-signed

| Item | Choice | Why |
|------|--------|-----|
| Kernel driver | `nv-prefer-signed-open-driver` (SLES 16 product repo) | Same as the guide. SUSE-signed open G06 modules, so Secure Boot works with no MOK enrollment. The RTX 3050 Ti is Ampere, which the open modules support. |
| Userspace | `nvidia-compute-utils-G06` + `nvidia-persistenced` from NVIDIA's **sles15** CUDA repo | NVIDIA's sles16 repo has no driver userspace yet. Pinned to the driver version. |
| GL/EGL/GBM | `nvidia-gl-G06`, **on** (`nvidia_install_gl: true`) | The guide says "only for Vulkan", but on a **hybrid laptop with GNOME it's required**. `nvidia-drm` exposes the dGPU as `card0`. Without NVIDIA's EGL/GBM, gnome-shell crashes in Mesa `libgallium` and GDM gives up (blinking cursor). |
| Display | The Intel iGPU drives the display | NVIDIA is used for compute only |

## Automated

```bash
ansible-playbook site.yml --tags nvidia
ssh mansible@10.10.12.252 sudo reboot
```

## Manual equivalent (as on SLES 16)

```bash
zypper in -y --auto-agree-with-licenses nv-prefer-signed-open-driver
version=$(rpm -qa --queryformat '%{VERSION}\n' nv-prefer-signed-open-driver | cut -d_ -f1 | sort -u | tail -n1)
zypper ar https://developer.download.nvidia.com/compute/cuda/repos/sles15/x86_64/ cuda-sle15
zypper --gpg-auto-import-keys refresh
zypper in -y --auto-agree-with-licenses nvidia-compute-utils-G06=${version} nvidia-persistenced=${version} nvidia-gl-G06=${version}
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

**2026-10-30, wheatley**
- Driver **580.178.04**: `nv-prefer-signed-open-driver` pulled in `nvidia-open-driver-G06-signed-cuda-kmp-default-580.178.04_k6.12.0_160000.37`
- Running kernel `6.12.0-160000.40`: the module is picked up through `weak-updates/` (kABI), so no rebuild is needed
- `modinfo nvidia`: license `Dual MIT/GPL`, signer `SUSE Linux Enterprise Secure Boot CA`
- nouveau blacklisted by `/usr/lib/modprobe.d/50-nvidia.conf`. GSP firmware (`gsp_ga10x.bin`) is present.
- Userspace from the NVIDIA sles15 repo: `nvidia-compute-utils-G06`, `nvidia-compute-G06`, `nvidia-persistenced` (all 580.178.04)
- ✅ `nvidia-smi` after reboot: **NVIDIA GeForce RTX 3050 Ti Laptop GPU**, 4096 MiB, Driver 580.178.04, CUDA 13.0, Persistence-M On
- Modules loaded: `nvidia`, `nvidia_uvm`, `nvidia_modeset`, `nvidia_drm`. No nouveau. `nvidia-persistenced` is active.
- ⚠️ `mokutil --sb-state`: **SecureBoot disabled, Platform is in Setup Mode**. The SUSE-signed module would load with Secure Boot on, but it hasn't been tested that way yet. See 00-hardware.

## zypper locks (added 2026-10-30)

A plain `zypper up` upgraded the userspace to NVIDIA's 580.196.07 from the CUDA repo. To match, it then installed NVIDIA's **DKMS** `nvidia-open-driver-G06` (built locally, unsigned) plus gcc and kernel-devel. The result was `Failed to initialize NVML: Driver/library version mismatch` against SUSE's signed 580.178.04 module.

Fix (the `nvidia` role does all of this):
- Downgrade the userspace to the KMP version (`zypper in --oldpackage ...=580.178.04`). Remove `nvidia-open-driver-G06`, `dkms`.
- `zypper addlock` on the userspace packages (`nvidia_locked_packages`) and on `nvidia-open-driver-G06` + `dkms` (blocks the DKMS path).
- When SUSE ships a newer signed KMP, the role sees the version difference, unlocks, installs the matching userspace and re-locks.

```bash
sudo zypper locks          # 11 nvidia/dkms locks
zypper up --dry-run        # NVIDIA packages are held back
```
