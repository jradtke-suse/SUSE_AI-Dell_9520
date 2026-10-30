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

## Notes

- SELinux: install `rke2-selinux` (the role does this when `rke2_selinux: true`)
- Firewall: 6443/tcp, 9345/tcp, 10250/tcp (single node). Or disable firewalld for the lab and record that decision here.
