# Troubleshooting Log

Format: date, symptom, cause, fix.

## 2026-10 Installer struggles with dual display adapters
- **Symptom:** Graphical installer has problems on Intel + NVIDIA hybrid graphics
- **Workaround:** Boot "Failsafe -- Install SUSE SLE 16" and run the installer remotely via the URL/credentials it provides
- **Cause:** _TBD_

## 2026-10 No SSH and no desktop after first reboot
- **Symptom:** After the post-install reboot, the GNOME desktop doesn't start and sshd isn't running
- **Fix (SSH):** Log in at the console and run `sudo systemctl enable sshd --now`. See [01-os-installation.md](01-os-installation.md#first-boot-enable-ssh-manual-step).
- **Desktop cause:** The failsafe installer options carry into `/etc/default/grub`: `nomodeset 3` (`3` = multi-user.target, so gdm never starts). It's **not** the NVIDIA driver: the desktop was missing before the driver was installed.
- **Desktop fix (1/2):** `ansible-playbook site.yml --tags bootloader`, then reboot. See [02 §2e](02-post-install.md#2e-bootloader-role-fix-the-failsafe-kernel-options).

## 2026-10-30 Blinking cursor, GDM fails after NVIDIA driver install
- **Symptom:** After fixing the kernel cmdline, there's a black screen with a blinking cursor. `journalctl -u gdm` shows `Session never registered, failing` and then `maximum number of X display failures reached`.
- **Cause:** `gnome-shell ... segfault ... in libgallium-24.3.3.so` after `libEGL warning: egl: failed to create dri2 screen`. `nvidia-drm` (modeset=Y) registers the dGPU as `/dev/dri/card0`, ahead of i915 `card1`. Only Mesa's EGL vendor and GBM backend were installed (compute-only NVIDIA packages), so Mesa tried the NVIDIA device and crashed.
- **Fix (2/2):** Install `nvidia-gl-G06` at the driver version (adds `10_nvidia.json` EGL vendor + `nvidia-drm_gbm.so`), then `systemctl restart gdm`. In Ansible: `nvidia_install_gl: true`.

## 2026-10-30 os-prober not available on SLES 16
- **Symptom:** `zypper in os-prober`: `No provider of 'os-prober' found`
- **Research:** os-prober is **not in the SLES 16 core repos**, but it **is in SUSE Package Hub 16.0** (`os-prober-1.81-bp160.1.12`, also in Leap 16.0 OSS). `grub2-common` still ships `/etc/grub.d/30_os-prober`, which silently skips when `os-prober`/`linux-boot-prober` aren't on the PATH. The SLES 16.0 release notes don't mention os-prober. Package Hub packages are community-maintained and not covered by SUSE support.
- **Fix:** Enabled `PackageHub/16.0/x86_64` and installed `os-prober` (`bootloader_windows_method: os-prober`). GRUB now lists `Windows Boot Manager (on /dev/nvme1n1p1)`. Fallback: `bootloader_windows_method: chainload` (a fixed `/etc/grub.d/45_windows` entry, supported packages only).
