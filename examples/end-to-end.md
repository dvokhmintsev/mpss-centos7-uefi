# Worked example: end-to-end deployment

A complete run on the reference machine (Lenovo ThinkStation D30, 2× Xeon
E5-2697v2, Intel Xeon Phi 7120A, CentOS 7.9.2009). Commands are run as root.

## Run the four stages

```sh
cd mpss-centos7-uefi/scripts

./00-prepare-host.sh           # repos, build deps, fetch kernel SRPM + MPSS
./10-build-kernel.sh           # apply the 2-line patch, build + install kernel

# Reboot into the custom kernel 3.10.0-693 (see ../config/grub-custom-entry.example),
# then continue:

./20-build-mpss-modules.sh     # build mic.ko against the custom kernel
./30-bringup-mic.sh            # install MPSS user space, start the card
```

## Expected output (abridged, from the verified reference run)

After stage 2 the module loads with no signature error:

```text
$ uname -r
3.10.0-693.el7.x86_64
$ grep EFI_SECURE_BOOT_SECURELEVEL /boot/config-$(uname -r)
# CONFIG_EFI_SECURE_BOOT_SECURELEVEL is not set
$ modprobe mic && echo OK
OK
```

After stage 3 the coprocessor is online and reachable:

```text
$ lspci | grep -i co-processor
04:00.0 Co-processor: Intel Corporation Xeon Phi coprocessor SE10/7120 series (rev 20)

$ micctrl --status
mic0: online (mode: linux image: /usr/share/mpss/boot/bzImage-knightscorner)

$ micinfo
  System Info
    OS Version              : 3.10.0-693.el7.x86_64
    Driver Version          : 3.8.6-1
    MPSS Version            : 3.8.6
  Device No: 0, Device Name: mic0
    Board SKU               : C0PRQ-7120 P/A/X/D
    ECC Mode                : Enabled
    Total No of Active Cores : 61
    Frequency               : 1238095 kHz
    GDDR Size               : 15872 MB

$ ssh mic0
[root@mic0 ~]# uname -a
Linux mic0.local 2.6.38.8+mpss3.8.6 #1 SMP ... k1om GNU/Linux
```
