# 01 - OS Installation (SLES 16)


I have installed a new/separate NVME drive.

burn the SLES 16 ISO image to a USB device
I insert the USB in the right-hand side
Power on the system and when the Dell Logo appears, hit 'Enter' then 'F12'.
Select your UEFI USB device

When the boot selection screen appears, select 
"Failsafe -- Install SUSE SLE 16 (x86_64)"
* the reason for this: the installer (apparently) struggles with the 2 display adapters present in the system.  Using the failsafe, as you will see, provides an option to run the installer from a separate/remote machine - which is pretty rad, actually.

The installation will provide a URL and login credentials for you to access the host remotely.

Software: 
- Gnome Desktop Environment (Wayland)
- KVM Virtualization Host (optional - I do this so it will create the bridge, etc...)

I tend to keep the installation itself fairly generic/vanilla and then deal with the OS stuff afterwards.




## First boot: enable SSH (manual step)

After the first reboot, it is **expected** that the graphical desktop does not start and sshd is **not** running. This is normal for this hardware/install method and is not a problem. The desktop is missing because the failsafe kernel options (`nomodeset 3`) carry over into the installed system. The `bootloader` Ansible role fixes that later (see [02 §2e](02-post-install.md#2e-bootloader-role-fix-the-failsafe-kernel-options)). You need to log in at the console (try **Ctrl+Alt+F3** if the screen is blank) and enable sshd by hand:

```bash
sudo systemctl enable sshd --now
```

If you still can't connect, make sure the firewall allows SSH:

```bash
sudo firewall-cmd --list-services
sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload
```

From then on, you can do everything else (bootstrap script, Ansible) over SSH.
