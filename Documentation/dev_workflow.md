# Manual GRUB and Xen installation

This document shows an example of development process for Xen and GRUB installed
on remote machine.

Assumptions:

- during development, you may and probably at some point will break booting on
  target device, so don't test on host
- you should have a way of booting another Linux distribution on target, even if
  main disk's bootloader isn't working
  - this can be either another drive with another bootloader or iPXE
  - bootable USB stick with live Debian should be good
- there is network connection between target and host
  - target obtains its IP through DHCP or is set manually (not shown below)

# Workflow

## Cloning and starting Docker container

If you're testing or working on specific changes, use appropriate branches
instead of main development ones.

```shell
git clone git@github.com:TrenchBoot/grub.git
cd grub
git checkout intel-txt-mb2
cd ..
git clone git@github.com:3mdeb/xen.git
cd xen
git checkout aem/develop
cd ..
docker run --rm -it -v $PWD/grub:/home/trenchboot/grub \
-v $PWD/xen:/home/trenchboot/xen -w /home/trenchboot \
ghcr.io/trenchboot/trenchboot-sdk:master /bin/bash
```

## Building

These steps are done in Docker. There are some redundant `cd`s which can be
optimized, they are listed to make each step more or less standalone.

### GRUB - one time configuration

```shell
cd grub
./bootstrap
./autogen.sh
mkdir -p build && cd build
../configure --disable-werror --prefix=$PWD/local
cd ../..
```

### GRUB - (re)build

```shell
cd grub/build
make -j $(nproc)
make install
cd ../..
```

### Xen

```shell
cd xen
make build-xen -j $(nproc)
cd ..
```

## Installation

### Host side, outside of Docker

This step prepares a list of files that must be copied to target and starts a
simple HTTP server. Substitute `<<hostIP>>` with your address.

```shell
export HOST_IP="<<hostIP>>"
ls -1 grub/build/local/lib/grub/i386-pc/ | \
  sed "s#\(.*\)#http://$HOST_IP:8080/grub/build/local/lib/grub/i386-pc/\1#" \
  > list
echo http://$HOST_IP:8080/grub/build/local/sbin/grub-install >> list
echo http://$HOST_IP:8080/xen/xen/xen.gz >> list
python -m http.server 8080
```

### Debian on target - GRUB and Xen installation

In this step we will download all of files from previously prepared list and
install GRUB on target partition. Substitute `sdX` with your test drive. Double
check that it is correct so you won't end up overwriting your USB stick instead
of target disk!

```shell
mkdir -p /mnt/hdd
mount /dev/sdX1 /mnt/hdd/
cd /mnt/hdd
mkdir -p dl
cd dl
# Remove existing old files, if any
rm -rf *
wget http://<<hostIP>>:8080/list
wget -i list -q
chmod +x grub-install
./grub-install --boot-directory=/mnt/hdd -d . /dev/sdX
cp xen.gz ..
```

### Debian on target - GRUB configuration

This step consists of creating `/grub/grub.cfg` file on target's boot partition.
It is normally created by tools like `grub-probe` and `grub-mkconfig`, but for
this simple case it can be created manually. This file isn't overwritten by GRUB
(re)installation, so unless there is something that needs to be changed, this
can be a one-time operation.

We also need some dom0 kernel and initramfs. As this isn't directly related to
TrenchBoot, we're using Qubes OS in example below. For different kernels, change
command line accordingly. Also, file below uses serial port for output, which
should be changed for VGA.

Example content of `grub.cfg`:

```
set debug=linux,relocator,multiboot_loader,slaunch

# Skip following 3 lines if you don't need serial output
serial --speed=115200 --word=8 --parity=no --stop=1
terminal_input  serial
terminal_output serial

insmod part_msdos
insmod ext2
set root='hd0,msdos1'

menuentry 'Qubes, with Xen hypervisor' {
	echo    'Loading Xen ...'
	multiboot2      /xen.gz placeholder  console=tty0 console=ttyS0,115200 dom0_mem=min:1024M dom0_mem=max:4096M ucode=scan smt=off gnttab_max_frames=2048 gnttab_max_maptrack_frames=4096 loglvl=all guest_loglvl=all com1=115200,8n1 console=com1 ${xen_rm_opts}
	echo    'Loading Linux 5.15.52-1.fc32.qubes.x86_64 ...'
	module2 /vmlinuz-5.15.52-1.fc32.qubes.x86_64 placeholder root=/dev/mapper/qubes_dom0-root ro rd.luks.uuid=luks-6afecd3a-6611-4e9b-82ab-5501176798c2 rd.lvm.lv=qubes_dom0/root rd.lvm.lv=qubes_dom0/swap i915.alpha_support=1 rd.driver.pre=btrfs rhgb quiet console=tty0 console=ttyS0,115200
	echo    'Loading initial ramdisk ...'
	module2 --nounzip   /initramfs-5.15.52-1.fc32.qubes.x86_64.img
}

menuentry 'Qubes, with Xen hypervisor and TrenchBoot' {
	echo    'Enabling slaunch ...'
	slaunch
	slaunch_state
	echo    'Loading Xen ...'
	multiboot2      /xen.gz placeholder  console=tty0 console=ttyS0,115200 dom0_mem=min:1024M dom0_mem=max:4096M ucode=scan smt=off gnttab_max_frames=2048 gnttab_max_maptrack_frames=4096 loglvl=all guest_loglvl=all com1=115200,8n1 console=com1 ${xen_rm_opts}
	echo    'Loading Linux 5.15.52-1.fc32.qubes.x86_64 ...'
	module2 /vmlinuz-5.15.52-1.fc32.qubes.x86_64 placeholder root=/dev/mapper/qubes_dom0-root ro rd.luks.uuid=luks-6afecd3a-6611-4e9b-82ab-5501176798c2 rd.lvm.lv=qubes_dom0/root rd.lvm.lv=qubes_dom0/swap i915.alpha_support=1 rd.driver.pre=btrfs rhgb quiet console=tty0 console=ttyS0,115200
	echo    'Loading initial ramdisk ...'
	module2 --nounzip   /initramfs-5.15.52-1.fc32.qubes.x86_64.img
	slaunch_state
}
```
