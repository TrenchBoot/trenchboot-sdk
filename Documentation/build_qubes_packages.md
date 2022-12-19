# Qubes OS Packages

[Qubes builder](https://www.qubes-os.org/doc/qubes-builder/) can be used to
prepare new ISO image but also to build customized packages. To do the latter
we will need PC with Fedora installed (may be any version as builder prepare
fc32 chroot itself).

## Build environment

This section describe steps that needs to be executed to build Qubes packages
with TrenchBoot patches.

### Prepare host machine

We will use latest stable Fedora release which is Fedora 37 at the time of
writing this manual.

* Start with downloading Fedora 37 Live ISO image from
  [getfedora](https://getfedora.org/en/workstation/download/), later the Fedora
  37 will probable be stored in
  [archive](https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/).

* Follow official
  [instruction](https://docs.fedoraproject.org/en-US/quick-docs/creating-and-using-a-live-installation-image/)
  to prepare Fedora Live ISO image on USB.

* Start Live ISO image and install it on workstation. Compiling Qubes needs some
  free storage so doing it on Live ISO image will not be possible. Make sure
  that english locale were selected, with different language there may be
  [issues](https://github.com/QubesOS/qubes-issues/issues/7949) with building.

  > Note: The full build requires some 25GB of free space, so keep that in mind
    when deciding where to place this directory.

* Reboot after installation and remove the USB with Live ISO image. Finish the
  installation process.

  > Note: e.g. create user `fedora` with password `fedora`

### Prepare default sources

Here we will describe how to initialize Qubes sources to later use them for
compilation.

* Open terminal, install dependencies.

```bash
$ sudo dnf install gnupg git createrepo rpm-build make wget rpmdevtools \
  python3-sh dialog rpm-sign dpkg-dev debootstrap python3-pyyaml devscripts \
  perl-Digest-MD5 perl-Digest-SHA
```

* Create `qubes` directory and clone there `qubes-builder` repository.

```bash
$ mkdir qubes && cd qubes
$ git clone https://github.com/QubesOS/qubes-builder.git qubes-builder
$ cd qubes-builder
```

* Now import Qubes master key and Qubes developers keys.

```bash
$ gpg --recv-keys 0xDDFA1A3E36879494
gpg: directory '/home/fedora/.gnupg' created
gpg: keybox '/home/fedora/.gnupg/pubring.kbx' created
gpg: /home/fedora/.gnupg/trustdb.gpg: trustdb created
gpg: key DDFA1A3E36879494: public key "Qubes Master Signing Key" imported
gpg: Total number processed: 1
gpg:               imported: 1
$ wget https://keys.qubes-os.org/keys/qubes-developers-keys.asc
--2022-12-16 01:44:25--  https://keys.qubes-os.org/keys/qubes-developers-keys.asc
Resolving keys.qubes-os.org (keys.qubes-os.org)... 147.75.32.1, 2604:1380:4601:1c00::1
Connecting to keys.qubes-os.org (keys.qubes-os.org)|147.75.32.1|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 6413 (6.3K) [application/octet-stream]
Saving to: ‘qubes-developers-keys.asc’

qubes-developers-keys.asc                            100%[=============>]   6.26K  --.-KB/s    in 0s

2022-12-16 01:44:25 (158 MB/s) - ‘qubes-developers-keys.asc’ saved [6413/6413]
$ gpg --import qubes-developers-keys.asc
gpg: key DDFA1A3E36879494: "Qubes Master Signing Key" not changed
gpg: key 063938BA42CFA724: public key "Marek Marczykowski-Górecki (Qubes OS signing key) <marmarek@invisiblethingslab.com>" imported
gpg: key DA0434BC706E1FCF: public key "Simon Gaiser (Qubes OS signing key) <simon@invisiblethingslab.com>" imported
gpg: Total number processed: 3
gpg:               imported: 2
gpg:              unchanged: 1
gpg: no ultimately trusted keys found
```

* Verify integrity of `qubes-builder` repository.

```bash
$ git tag -v `git describe`
object eb9100bd191b8dff2ef4695710e7d3f624347b45
type commit
tag mm_eb9100bd
tagger Marek Marczykowski-Górecki <marmarek@invisiblethingslab.com> 1671105032 +0100

Tag for commit eb9100bd191b8dff2ef4695710e7d3f624347b45
gpg: Signature made Thu 15 Dec 2022 06:50:35 AM EST
gpg:                using RSA key 0064428F455451B3EBE78A7F063938BA42CFA724
gpg: Good signature from "Marek Marczykowski-Górecki (Qubes OS signing key) <marmarek@invisiblethingslab.com>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 0064 428F 4554 51B3 EBE7  8A7F 0639 38BA 42CF A724
```

* Prepare build configuration, base on Qubes master.

```bash
$ cp example-configs/qubes-os-master.conf builder.conf
```

* Download all sources.

```bash
$ make get-sources
-> Updating sources for builder...
--> Fetching from https://github.com/QubesOS/qubes-builder.git main...
--> Verifying tags...
(...)
```

> Note: better not use to `-j` option with `get-sources` and later when building
  packages as often the build fails then.

> Note2: Fetching sources may end with errors but they does not seem to be
  relevant for us in light of the need for a GRUB and Xen compilation.

After command execution, we should have all qubes sources in `qubes-src`
directory.

```bash
$ tree -L 1 qubes-src/ | grep grub2
├── grub2
├── grub2-theme
├── linux-pvgrub2
$ tree -L 1 qubes-src/ | grep vmm-xen
├── vmm-xen
├── vmm-xen-stubdom-legacy
├── vmm-xen-stubdom-linux
```

### Prepare custom sources

Easiest way to prepare, test and push patches for Qubes packages is to create a
fork of given package. The workflow should be as follow:

* narrow down the vanilla version of given component used in Qubes,
* fetch it and apply patches from Qubes package repository,
* apply custom changes, make sure there is no conflicts,
* create git patches of custom changes,
* push them to own fork of given package.

in a similar way, forks for Xen and GRUB were prepared.

* [Xen](https://github.com/3mdeb/qubes-vmm-xen/pull/1)
* [GRUB](https://github.com/3mdeb/qubes-grub2/pull/2)

Follow steps below to use them in `qubes-builder` on Fedora.

* Navigate to `vmm-xen` sources.

```bash
$ cd ~/qubes/qubes-builder/qubes-src/vmm-xen
```

* Add your fork as new remote repository, pull code and checkout to your branch.

```bash
$ git remote add fork https://github.com/3mdeb/qubes-vmm-xen.git
$ git pull fork
remote: Enumerating objects: 21, done.
remote: Counting objects: 100% (21/21), done.
remote: Compressing objects: 100% (19/19), done.
remote: Total 21 (delta 2), reused 21 (delta 2), pack-reused 0
Unpacking objects: 100% (21/21), 36.53 KiB | 6.09 MiB/s, done.
From https://github.com/3mdeb/qubes-vmm-xen
 * [new branch]      inteltxt-support   -> fork/inteltxt-support
 * [new branch]      main               -> fork/main
 * [new branch]      release3.0         -> fork/release3.0
 * [new branch]      xen-4.1            -> fork/xen-4.1
 * [new branch]      xen-4.12           -> fork/xen-4.12
 * [new branch]      xen-4.13           -> fork/xen-4.13
 * [new branch]      xen-4.14           -> fork/xen-4.14
 * [new branch]      xen-4.4            -> fork/xen-4.4
 * [new branch]      xen-4.6            -> fork/xen-4.6
 * [new branch]      xen-4.8            -> fork/xen-4.8
 * [new branch]      xen-4.8-release3.2 -> fork/xen-4.8-release3.2
You asked to pull from the remote 'fork', but did not specify
a branch. Because this is not the default configured remote
for your current branch, you must specify a branch on the command line.
$ git checkout fork/inteltxt-support
```

* Navigate to `grub2` sources.

```bash
$ cd ~/qubes/qubes-builder/qubes-src/grub2
```

* Add your fork as new remote repository, pull code and checkout to your branch.

```bash
$ git remote add fork https://github.com/3mdeb/qubes-grub2.git
$ git pull fork
remote: Enumerating objects: 142, done.
remote: Counting objects: 100% (86/86), done.
remote: Compressing objects: 100% (45/45), done.
remote: Total 142 (delta 40), reused 77 (delta 40), pack-reused 56
Receiving objects: 100% (142/142), 6.39 MiB | 10.22 MiB/s, done.
Resolving deltas: 100% (40/40), completed with 13 local objects.
From https://github.com/3mdeb/qubes-grub2
 * [new branch]      grub-2.06          -> fork/grub-2.06
 * [new branch]      inteltxt-support   -> fork/inteltxt-support
 * [new branch]      master             -> fork/master
 * [new branch]      trenchboot_support -> fork/trenchboot_support
You asked to pull from the remote 'fork', but did not specify
a branch. Because this is not the default configured remote
for your current branch, you must specify a branch on the command line.
$ git checkout fork/inteltxt-support
```

* For GRUB we need to manually download grub-2.06.tar.xz package to provide
  sources (other way would be to change builder.conf settings to allow using
  our fork). To fetch manually run following command.

```bash
$ FETCH_CMD="curl --proto '=https' --proto-redir '=https' --tlsv1.2 --http1.1 -sSfL -o" make get-sources
```

After that `grub-2.06.tar.xz` and `grub-2.06.tar.xz.sig` should be downloaded.

## Building custom package

After preparing sources in previous [section](#prepare-custom-sources) now is
time to build the package. To do so, we need to run `make` command with package
name executed from top directory of `qubes-builder`.

* Navigate to top directory.

```bash
$ cd ~/qubes/qubes-builder/
```

* Temporarily disable SELinux (enabled on Fedora by default) as it will prevents
  rpm from working as desired when building packages with changed chroot.

```bash
$ sudo setenforce 0
```

* Run `make vmm-xen` to build Xen for Qubes with custom patches.

```bash
$ make vmm-xen
Currently installed dependencies:
(...)
--> Done:
      qubes-src/vmm-xen/pkgs/dom0-fc32/noarch/xen-doc-4.17.0-2.fc32.noarch.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/python3-xen-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/python3-xen-debuginfo-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-debuginfo-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-debugsource-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-devel-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-hypervisor-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-libs-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-libs-debuginfo-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-licenses-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-qubes-vm-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-qubes-vm-debuginfo-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-runtime-4.17.0-2.fc32.x86_64.rpm
      qubes-src/vmm-xen/pkgs/dom0-fc32/x86_64/xen-runtime-debuginfo-4.17.0-2.fc32.x86_64.rpm
```

* Run `make grub2` to build Xen for Qubes with custom patches.

```bash
$ make grub2
Currently installed dependencies:
(...)
--> Done:
      qubes-src/grub2/pkgs/dom0-fc32/noarch/grub2-common-2.06-0.1.fc32.noarch.rpm
      qubes-src/grub2/pkgs/dom0-fc32/noarch/grub2-efi-ia32-modules-2.06-0.1.fc32.noarch.rpm
      qubes-src/grub2/pkgs/dom0-fc32/noarch/grub2-efi-x64-modules-2.06-0.1.fc32.noarch.rpm
      qubes-src/grub2/pkgs/dom0-fc32/noarch/grub2-pc-modules-2.06-0.1.fc32.noarch.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-debuginfo-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-debugsource-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-efi-ia32-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-efi-ia32-cdboot-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-efi-x64-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-efi-x64-cdboot-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-pc-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-tools-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-tools-debuginfo-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-tools-efi-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-tools-efi-debuginfo-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-tools-extra-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-tools-extra-debuginfo-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-tools-minimal-2.06-0.1.fc32.x86_64.rpm
      qubes-src/grub2/pkgs/dom0-fc32/x86_64/grub2-tools-minimal-debuginfo-2.06-0.1.fc32.x86_64.rpm
```

### Troubleshooting

* Running `make PACKAGE` ends on `error: can't create transaction lock on
  /home/(...)/chroot-dom0-fc32/usr/lib/sysimage/rpm/.rpm.lock (Permission
  denied)`

This mean that probably SELinux was not disabled properly. Please run `sudo
setenforce 0`.

* Running `make grub2` ends on error: Bad source:
  /home/user/qubes-src/grub2/grub-2.06.tar.xz: No such file or directory`

It means that `grub-2.06.tar.xz` was not downloaded manually in preparing
custom sources [section](#prepare-custom-sources).
