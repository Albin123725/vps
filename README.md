# QEMU-freeroot
## QEMU-freeroot is a script to create an isolated ubuntu system (Same as freeroot)

## ✨ New 24/7 VPS Feature & Interactive Menu
Now with **24/7 background operation** and **interactive ALBIN banner menu**!
- Keep VM running even when you close laptop/browser
- Beautiful menu with customization options
- Systemd service for automatic startup

## How to use
1. Install QEMU

Arch: `sudo pacman -S qemu`

Debian/Ubuntu: `sudo apt install qemu qemu-kvm`

Fedora: `sudo dnf install @virtualization`

Gentoo: `sudo emerge --ask app-emulation/qemu`

RHEL/CentOS: `sudo yum install qemu-kvm`

SUSE: `sudo zypper install qemu`

Google Firebase Studio: copy the `googlefirebasestudio/dev.nix` file and paste it

2. Clone the repo

`git clone https://github.com/BlackCatOfficialytb/QEMU-freeroot.git`

3. Run vm.sh (Traditional way)

```bash
cd QEMU-freeroot
sh vm.sh
# or
bash vm.sh
