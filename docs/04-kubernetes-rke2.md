# 04 - Kubernetes: RKE2 (single node)

SUSE AI runs on a Rancher-managed Kubernetes cluster. On a single laptop, the plan is:

- [ ] Single-node RKE2 server (`ansible-playbook site.yml --tags rke2`)
- [ ] `kubectl` + `helm` on the host
- [ ] (Decide) Rancher Prime on this same node, or import into an existing Rancher

## Verify

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes -o wide
kubectl get pods -A
```

## SLES 16 notes (see [sles16-deltas.md](sles16-deltas.md))

- Installs from the **Prime artifacts URL** (`rke2_artifact_url`) with `system-default-registry: registry.rancher.com`, per guide §2.3
- NetworkManager is told to ignore CNI interfaces (`/etc/NetworkManager/conf.d/rke2-canal.conf`)
- SELinux is **Enforcing** on SLES 16 (the guide assumes AppArmor). **Decision: keep SELinux.** The role adds Rancher's `sle` RPM repo, installs `rke2-selinux`, sets `selinux: true` in `config.yaml`, and runs `restorecon` on the tarball-installed binaries.
- Prime artifacts URL `https://prime.ribs.rancher.io` needs no login

## Notes

- Firewall: 6443/tcp, 9345/tcp, 10250/tcp (single node). Or disable firewalld for the lab and record that decision here.
