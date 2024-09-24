# Tested TrenchBoot use cases

## AEM (Anti Evil Maid) on OptiPlex 9010

### Hardware

* Dell OptiPlex 7010
* CPU: Intel(R) Core(TM) i5-3470 CPU @ 3.20GHz

### Software

* coreboot revision: coreboot-4.17-287-g4dba71fd25-v0.1.0
    - build instructions: [Build firmware with TXT for Dell OptiPlex](fw_dell_optiplex.md)
    - flash instructions: [Dasharo documentation](https://docs.dasharo.com/variants/dell_optiplex/initial-deployment/)
* GRUB revision: [intel-txt-aem](https://github.com/TrenchBoot/grub/tree/intel-txt-aem)
    - [build and installation instruction](./dev_workflow.md)
* Xen revision: [aem/develop](https://github.com/3mdeb/xen/tree/aem/develop)
    - [build and installation instruction](./dev_workflow.md)
* Qubes OS 4.1
