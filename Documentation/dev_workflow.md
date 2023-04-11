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

What follows describes the use of `aem.sh` script from [../scripts/aem/]
directory. It's assumed to be in current directory, but putting it in `$PATH`
will work the same. The script already has a `README`, look there for more
details. The description here will be a bit more streamlined.

## Configuration

Start by creating a directory where you'll be working and copy `aem.sh` there.
Create configuration file called `aem-cfg.sh`. It's a bash script which `aem.sh`
sources on startup. You want to adjust the following:
 * branches and maybe URLs to projects if not working on default ones
 * IP address of your machine (**don't miss this**)
 * port to use when starting a local HTTP server in case `8080` is in use
 * disk and partition devices on DUT (**checking this twice won't hurt**, don't
   put in device of your USB stick instead of the target disk!)
 * list of files to send to DUT in case you want to use different names or
   location on DUT (don't forget to adjust `grub.cfg` accordingly)

```bash
grub_repo=https://github.com/TrenchBoot/grub.git
xen_repo=https://github.com/3mdeb/xen.git

grub_branch=intel-txt-aem-2.06
xen_branch=aem/develop

server_prefix=http://10.0.2.2
server_port=8080
server_url=$server_prefix:$server_port

boot_disk=/dev/vda
boot_part=/dev/vda1

# format: {local file under webroot/}:{destination prefix}
files_to_send=(
    grub.cfg:/grub
    bzImage:/grub
    initramfs.cpio:/grub
    xen/xen.gz:/grub
)
```

Sample `grub.cfg` is at [/scripts/aem/grub.cfg]. Mind that it uses serial port
for output, which might need to be changed for VGA.

## Initialization on host

Run:
```bash
./aem.sh init
./aem.sh build
```

Also put `grub.cfg`, `bzImage` and `initramfs.cpio` files to `webroot/`
subdirectory at this point. The latter two can be found in
<http://boot.3mdeb.com/tb/mb2/>.

## Setup on DUT

Start serving HTTP data on your host:
```bash
./aem.sh serve
```

Run this on DUT, but with IP and port number of your host machine:
```bash
wget -O - 10.0.2.2:8080 | bash -
```

## Updates

Run `build` subcommand with optional `grub` or `xen` parameter (depending on
where you've made your edits):
```bash
./aem.sh build
```

In case of changes to the list of GRUB submodules, also do:
```bash
./aem.sh serve update
```
This will regenerate related files provided by the HTTP server.

On the DUT side, run the `wget` command from again to apply changes.
