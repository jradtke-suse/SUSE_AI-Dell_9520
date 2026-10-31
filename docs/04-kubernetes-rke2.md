# 04 - Kubernetes: RKE2 (single node)

SUSE AI runs on a Rancher-managed Kubernetes cluster. On a single laptop, the plan is:

- [x] Single-node RKE2 server (`ansible-playbook site.yml --tags rke2`)
- [x] `kubectl` on the host (`/etc/profile.d/rke2.sh` adds `/var/lib/rancher/rke2/bin` to PATH and sets `KUBECONFIG`)
- [ ] `helm` (needed for chapter 4)
- [ ] Rancher Prime: **skipped for now.** Guide §3.1 wants it on a separate cluster. Revisit if we want the UI.

## Verify

Log in again (or `source /etc/profile.d/rke2.sh`) to pick up PATH and KUBECONFIG.

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

## Results (2026-10-30)

```
NAME       STATUS   ROLES                VERSION          INTERNAL-IP     OS-IMAGE                            KERNEL-VERSION             CONTAINER-RUNTIME
wheatley   Ready    control-plane,etcd   v1.36.5+rke2r1   192.168.0.103   SUSE Linux Enterprise Server 16.0   6.12.0-160000.40-default   containerd://2.3.4-k3s1
```

- `stable` channel resolved to **v1.36.5+rke2r1**, installed under `/opt/rke2`
- All `kube-system` pods Running. Default ingress class is **traefik** (not ingress-nginx), so use `traefik` for any ingress in chapter 4.
- `rke2` and `containerd` run as `container_runtime_t`. SELinux is enforcing with **0 AVC denials**.
- Pod DNS resolves `kubernetes.default.svc.cluster.local` to `10.43.0.1`
- There is **no storage class** yet. Chapter 4 needs one (we plan `local-path`).

## SLES 16 notes (see [sles16-deltas.md](sles16-deltas.md))

- Installs from the **Prime artifacts URL** (`rke2_artifact_url`) with `system-default-registry: registry.rancher.com`, per guide §2.3
- NetworkManager is told to ignore CNI interfaces (`/etc/NetworkManager/conf.d/rke2-canal.conf`)
- SELinux is **Enforcing** on SLES 16 (the guide assumes AppArmor). **Decision: keep SELinux.** The role adds Rancher's `sle` RPM repo, installs `rke2-selinux`, sets `selinux: true` in `config.yaml`, and runs `restorecon` on the tarball-installed binaries.
- Prime artifacts URL `https://prime.ribs.rancher.io` needs no login
- **Install prefix is `/opt/rke2`, not `/usr/local`.** SLES 16 makes `/usr/local` its own btrfs subvolume, and the installer avoids mount points. The role sets `INSTALL_RKE2_TAR_PREFIX=/opt/rke2` explicitly. The systemd units are in `/etc/systemd/system`.

## Notes

- **firewalld stays on.** Opened 6443/tcp, 9345/tcp, 10250/tcp, and added the pod CIDR `10.42.0.0/16` and the service CIDR `10.43.0.0/16` to the `trusted` zone so in-cluster traffic isn't dropped.
- Node IP is the wired NIC (192.168.0.103, the default route). If the laptop moves to WiFi-only, the node IP changes and RKE2 will need `node-ip` set or a reinstall.
