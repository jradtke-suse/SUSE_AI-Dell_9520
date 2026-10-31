# SLES 16 vs the SUSE AI 1.0 guide (SLES 15 SP6)

Reference: [SUSE AI 1.0: Installing the Linux and Kubernetes distribution](https://documentation.suse.com/suse-ai/1.0/html/AI-deployment/ai-deployment-kube-installing.html)

The guide targets SLES 15 SP6 (or SL Micro 6.1). We're on **SLES 16.0**. Each difference below was checked on `wheatley` on 2026-10-30 unless it's marked _verify_.

| Area | Guide (15 SP6) | SLES 16.0 reality | What we do |
|------|----------------|-------------------|------------|
| Installer | YaST, pick modules (Basesystem, Server Apps, Python 3) | Agama installer, no module selection. Extensions are only HA and PackageHub. | Default install. Register after install with the `registration` role. PackageHub enabled (for os-prober). |
| sudo | n/a | `Defaults targetpw` (asks for root's password) | `sudo` role adds NOPASSWD. First run uses `-K` with the root password. |
| Kernel cmdline | n/a | Failsafe install leaves `ide=nodma apm=off noresume edd=off nomodeset 3` in `/etc/default/grub`, so there's no desktop | `bootloader` role strips them and regenerates grub.cfg |
| sshd | enabled | Not running after first boot | Enable manually at the console (see 01) |
| Open driver package | `nv-prefer-signed-open-driver` from SUSE repos | **Same package exists** in `SLE-Product-SLES-16.0` (580.178.04 latest) | Same as the guide |
| NVIDIA CUDA repo | `.../cuda/repos/sles15/x86_64/` | `.../repos/sles16/x86_64/` exists but has **no driver userspace** (only cuVS). SLES 16 repos have no `nvidia-compute-utils-G06` either. | **Use the `sles15` repo** for `nvidia-compute-utils-G06` + `nvidia-persistenced`, pinned to the KMP version. _Revisit when NVIDIA fills the sles16 repo._ |
| Version pinning | `rpm -qa ... nv-prefer-signed-open-driver \| cut -d_ -f1` | Same. The sles15 repo has newer versions (e.g. 580.196.07) than the SUSE KMP. Pinning at install time is **not enough**: `zypper up` upgrades the userspace and pulls NVIDIA's unsigned DKMS driver. | Ansible pins `=<kmp version>` **and adds zypper locks**. `nvidia-open-driver-G06` and `dkms` are locked out. |
| KMP kernel | n/a | Latest KMP is built against `k6.12.0_160000.37`. Running kernel after patching is `160000.40`. | Relies on kABI compatibility. _Verify `nvidia-smi` after reboot._ |
| NVIDIA GL | `nvidia-gl-G06` "only if Vulkan is needed" | Hybrid laptop + GNOME: **required**, or gnome-shell crashes in Mesa on the NVIDIA DRM device | `nvidia_install_gl: true` |
| os-prober | n/a | Not in SLES 16 core repos. Only in Package Hub 16.0 (`1.81-bp160.1.12`, community, unsupported). `30_os-prober` is still shipped by grub2-common and no-ops without the binary. | **Enabled Package Hub + installed os-prober** (`bootloader_windows_method: os-prober`). Fallback: a fixed chainload entry. |
| MAC framework | AppArmor (`apparmor-parser`) | **SELinux, Enforcing**. AppArmor not installed. `container-selinux` is in SLES 16, but `rke2-selinux` isn't. | Keep SELinux. Add Rancher repo `rpm.rancher.io/rke2/stable/common/sle/noarch` (the `sle` build, not `slemicro`: it needs policy ≥ 20230523, SLES 16 has 20250627), install `rke2-selinux`, set `selinux: true` |
| NetworkManager | "configure it to ignore CNI interfaces" | NM is active | Drop `/etc/NetworkManager/conf.d/rke2-canal.conf` (`unmanaged-devices=interface-name:flannel*;interface-name:cali*`) |
| RKE2 source | get.rke2.io with `INSTALL_RKE2_ARTIFACT_URL=<PRIME-ARTIFACTS-URL>/rke2` | Same. `https://prime.ribs.rancher.io` is public (no credentials) but has no directory listing, so only real versions return 200. | `rke2_artifact_url`, `INSTALL_RKE2_METHOD=tar`, then `restorecon` on the binaries |
| RKE2 install path | `/usr/local/bin/rke2` | `/usr/local` is its own btrfs subvolume, so the installer falls back to `/opt/rke2` | `rke2_install_prefix: /opt/rke2` (explicit). `restorecon` on that. |
| Firewall | Not covered | firewalld active | Open 6443, 9345, 10250 and trust `10.42.0.0/16` + `10.43.0.0/16` |
| Ingress | Docs and charts often assume ingress-nginx | RKE2 v1.36 ships **traefik** as the default IngressClass | Use `traefik` in chart values |
| RKE2 registry | `system-default-registry: registry.rancher.com` | Same | Written to `/etc/rancher/rke2/config.yaml` |
| CPU governor | `performance` | Laptop: a trade-off with heat and battery | Optional, off by default |
| Helm | Helm 3 | SLES 16 ships 3.21.x **and** 4.3.x; `zypper up` moves to 4 | Install 3.x (`--oldpackage`) and lock `helm`, `helm-bash-completion` |
| Storage | Examples use `local-path` | Not part of RKE2 | local-path-provisioner v0.0.37 from `registry.rancher.com`. Default path is already SELinux-labeled. |
| GPU Operator | v25.3.4, `DEVICE_LIST_STRATEGY=volume-mounts` | v25.3.4 predates RKE2 v1.36 / containerd 2.3. v26 uses CDI by default, and volume-mounts then breaks GPU pods. | v26.7.2, guide values minus the device-plugin override |
| Pod DNS | n/a | Pods inherit host search domains. A wildcard LAN domain plus `ndots:5` hijacked external names. | RKE2 `resolv-conf` with nameservers only |
