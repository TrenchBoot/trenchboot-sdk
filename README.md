# trenchboot-sdk

SDK for building and maintaining TrenchBoot patches fro GRUB2, Xen and Linux kernel.

## How to compile most recent TrenchBoot patches

### GRUB2

Clone GRUB2 repository:

```shell
git clone https://github.com/TrenchBoot/grub.git -b intel-txt-mb2
```

Run TrenchBoot SDK container:

```shell
docker run --rm -it -v $PWD/grub:/home/trenchboot/grub \
-w /home/trenchboot/grub \
ghcr.io/trenchboot/trenchboot-sdk:master /bin/bash
```

Prepare GRUB2 compilation:

```shell
./bootstrap && ./autogen.sh
```

Create build directory:

```shell
mkdir -p build && cd build
```

Configure:

```shell
../configure --disable-werror --prefix=$PWD/local
```

Compile:

```shell
make
```

### Xen

Clone Xen repository:

```shell
git clone https://github.com/3mdeb/xen.git -b tb-xen-txt
```

Run TrenchBoot SDK container:

```shell
docker run --rm -it -v $PWD/xen:/home/trenchboot/xen \
-w /home/trenchboot/xen \
ghcr.io/trenchboot/trenchboot-sdk:master /bin/bash
```

Compile:

```shell
make build-xen
```
