# 00 - Hardware & BIOS Prep

## Hardware

| Item | Detail |
|------|--------|
| Model | Dell XPS 15 9520 |
| CPU | 12th Gen Intel Core (Alder Lake-H) — _fill in exact SKU_ |
| iGPU | Intel Iris Xe |
| dGPU | NVIDIA GeForce RTX 3050 Ti Laptop (Ampere, GA107, 4 GB) |
| RAM | _fill in_ |
| Disk (OS) | Additional/separate NVMe drive dedicated to SLES 16 |
| BIOS version | _fill in_ |

> The RTX 3050 Ti is Ampere, so the NVIDIA **open** kernel modules (Turing+) are supported. This lets us use SUSE's signed open-driver KMP.

## Gather info (fill in after install)

```bash
sudo dmidecode -s system-product-name -s bios-version
lscpu | grep 'Model name'
lspci -nnk | grep -A3 -Ei 'vga|3d'
lsblk -o NAME,SIZE,MODEL
free -h
```

## BIOS settings (F2 at the Dell logo)

- [ ] Update BIOS to the latest version (Dell support / fwupd) before you start
- [ ] Storage: AHCI/NVMe mode (not RAID/Intel RST) so Linux can see the NVMe drive
- [ ] Secure Boot: **leave enabled**. SUSE-signed shim + SUSE-signed NVIDIA KMP means you don't need to enroll a MOK key.
- [ ] Virtualization (VT-x / VT-d): enabled (needed for the KVM host pattern)
- [ ] Boot order / one-time boot: F12
