# Troubleshooting Log

Format: date, symptom, cause, fix.

## 2026-10 Installer struggles with dual display adapters
- **Symptom:** Graphical installer has problems on Intel + NVIDIA hybrid graphics
- **Workaround:** Boot "Failsafe -- Install SUSE SLE 16" and run the installer remotely via the URL/credentials it provides
- **Cause:** _TBD_

## 2026-10 No SSH and no desktop after first reboot
- **Symptom:** After the post-install reboot, the GNOME desktop doesn't start and sshd isn't running
- **Fix (SSH):** Log in at the console and run `sudo systemctl enable sshd --now`. See [01-os-installation.md](01-os-installation.md#first-boot-enable-ssh-manual-step).
- **Desktop:** Expected at this stage. No action needed. The desktop isn't required for the SUSE AI build.
