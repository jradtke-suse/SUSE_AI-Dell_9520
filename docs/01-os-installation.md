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



