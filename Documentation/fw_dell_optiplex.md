## Firmware preparation

### Configuring firmware for the Dell OptiPlex 7010/9010

This step prepares the firmware with TXT firmware for the Dell OptiPlex
7010/9010 computer. Do note that some of the binary blobs necessary for building
functional firmware are not publically available and we cannot share them here.
You may need to extract them yourself, but these steps are not covered in this
tutorial.

These instructions require that you have Docker installed and configured
correctly.

- Clone the coreboot repository:

    ```bash
    git clone https://review.coreboot.org/coreboot.git
    cd coreboot
    git checkout fa78ecacec2694753068a9e769a3d68d5dad2b62
    git submodule update --init --checkout --recursive
    ```

- Copy the default board config from the trenchboot-sdk repository:

    ```bash
    cp ../trenchboot-sdk/Documentation/coreboot_config.dell_optiplex_7010_txt .config
    ```

- Launch the coreboot-sdk Docker container:

    ```bash
    docker run --rm -it \
        -v $PWD:/home/coreboot/coreboot \
        -w /home/coreboot/coreboot \
        coreboot/coreboot-sdk:2023-06-04_44f676afc9
    ```

- Build coreboot firmware:

    ```bash
    make olddefconfig && make
    ```

The resulting firmware binary will be placed in `build/coreboot.rom`. You can
now flash it to the machine using your preferred method. You can refer to the
[Dasharo documentation](https://docs.dasharo.com/variants/dell_optiplex/initial-deployment/)
for more details.
