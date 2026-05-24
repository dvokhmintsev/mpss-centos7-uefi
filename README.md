# mpss-centos7-uefi

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![shellcheck](https://github.com/dvokhmintsev/mpss-centos7-uefi/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/dvokhmintsev/mpss-centos7-uefi/actions/workflows/shellcheck.yml)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20367667.svg)](https://doi.org/10.5281/zenodo.20367667)

Reproducible deployment of Intel Xeon Phi **Knights Corner (KNC)** coprocessors on **UEFI-based CentOS 7.9 / RHEL 7** hosts, by resolving an undocumented kernel module-signature deadlock.

Intel discontinued the Manycore Platform Software Stack (MPSS) in 2019; the final release (3.8.6) officially supports CentOS/RHEL kernels only up to 7.3. Community patches ([jjkeijser/mpss](https://github.com/jjkeijser/mpss)) make the `mic.ko` driver *compile* against modern kernels, but they do not address module **signature enforcement**, which blocks loading on UEFI hosts. This toolkit closes that gap with a minimal, auditable kernel reconfiguration and four automated scripts.

## The problem in one paragraph

CentOS/RHEL 7 kernels ship with `CONFIG_EFI_SECURE_BOOT_SECURELEVEL=y`. When the firmware reports that UEFI Secure Boot is active, the kernel raises an internal *securelevel* that refuses any module without a signature chained to a trusted key. The decisive finding behind this work is that **some UEFI firmware reports Secure Boot as *enabled* to the OS even when it is *disabled* in BIOS** (confirmed on a Lenovo ThinkStation D30, BIOS A3KT70AUS). The unsigned `mic.ko` then fails with `Required key not available`, and every standard workaround is defeated (see [What does not work](#what-does-not-work)). The fix is to rebuild the kernel with two configuration options unset, decoupling securelevel from the spurious Secure Boot report while keeping the module-signing facility intact.

## The fix, in full

The entire host-side change is two lines applied to the CentOS 7.4 kernel config before the build (`patches/disable-efi-securelevel.sh`):

```sh
# (1) Decouple the kernel securelevel from UEFI Secure Boot state
sed -i 's/CONFIG_EFI_SECURE_BOOT_SECURELEVEL=y/# CONFIG_EFI_SECURE_BOOT_SECURELEVEL is not set/' \
  kernel-3.10.0-x86_64.config
# (2) Do not require UEFI-trusted keys for module signatures
sed -i 's/CONFIG_MODULE_SIG_UEFI=y/# CONFIG_MODULE_SIG_UEFI is not set/' \
  kernel-3.10.0-x86_64.config
```

`CONFIG_MODULE_SIG=y` is deliberately **kept** — removing it breaks the kernel build (symbol-dependency failures).

## Verified reference hardware

| | |
|---|---|
| Workstation | Lenovo ThinkStation D30 (Type 4354, MTM 43545V2), BIOS A3KT70AUS, UEFI |
| CPU | 2× Intel Xeon E5-2697v2 (24C/48T total) |
| Memory | 128 GB DDR3-1866 ECC |
| Coprocessor | Intel Xeon Phi 7120A (KNC, C0PRQ-7120, 61 cores, 16 GB GDDR5) |
| Host OS | CentOS 7.9.2009 Minimal |
| Stock kernel | 3.10.0-1160.119.1.el7.x86_64 |
| Custom kernel | 3.10.0-693.el7.x86_64 (reconfigured) |
| MPSS | 3.8.6 |

## Requirements

- A UEFI host with a PCIe x16 slot, adequate power/cooling for the card (the 7120A draws 300 W), and a KNC coprocessor installed.
- CentOS 7.9 / RHEL 7 (x86_64). A multi-core CPU is recommended for the one computationally heavy step (the kernel build).
- Network access to `vault.centos.org` (kernel SRPM) and the MPSS 3.8.6 archive.
- Root access. All scripts must be run as root (e.g. via `sudo`). Establish root and, if deploying remotely, SSH access to the host *before* starting; stage 0 enables `sshd` but you need a way in first.

## Security notes

Read these before running, since the scripts run as root and deliberately change a kernel security setting.

- **What this weakens.** The fix unsets `CONFIG_EFI_SECURE_BOOT_SECURELEVEL` so the kernel no longer escalates to *securelevel* on a (mis-reported) Secure Boot signal. Module-signature *signing* is otherwise preserved (`CONFIG_MODULE_SIG=y` is kept). Understand and accept this trade-off before proceeding; it is the intended behaviour, not a side effect.
- **Download integrity (fail-closed).** Stage 0 verifies every downloaded artifact before using it: the kernel SRPM and the MPSS tarball are checked against SHA-256 values pinned in `scripts/lib/common.sh`, and the kernel SRPM is additionally verified against the CentOS 7 GPG key. A mismatch aborts. The pinned hashes are:
  - kernel SRPM `kernel-3.10.0-693.el7.src.rpm`: `fdd264018be896564c59d7414ac3c1230b98576cf7737bfcce055f491b7b0687`
  - `mpss-3.8.6-linux.tar`: `3ce960db4c225f6e27ed6aa51c9dcb158fd93fe682d435ebd245849110b77a1b`
- **The custom kernel is added, not replacing.** Your existing kernel stays installed; keep it as the GRUB fallback so you can boot back if the custom kernel misbehaves.
- **A passphraseless root SSH key** is created during bring-up (stage 3) if root has none, because the `mpss` service must reach the card non-interactively. To use your own key policy, pre-provision `/root/.ssh/id_ed25519` before stage 3.

## Quick start

```sh
git clone https://github.com/dvokhmintsev/mpss-centos7-uefi.git
cd mpss-centos7-uefi/scripts

sudo ./00-prepare-host.sh          # repos, build deps, fetch kernel SRPM + MPSS
sudo ./10-build-kernel.sh          # apply the 2-line patch, build + install kernel

# --- reboot into the custom kernel 3.10.0-693 ---
# (see ../config/grub-custom-entry.example)

sudo ./20-build-mpss-modules.sh    # build mic.ko against the custom kernel
sudo ./30-bringup-mic.sh           # install MPSS user space, start the card
```

The reboot between stages 1 and 2 is required: the module is compiled against the *running* kernel, which must be the reconfigured one.

## Verification

After stage 2, the module loads with no error:

```text
$ uname -r
3.10.0-693.el7.x86_64
$ grep EFI_SECURE_BOOT_SECURELEVEL /boot/config-$(uname -r)
# CONFIG_EFI_SECURE_BOOT_SECURELEVEL is not set
$ modprobe mic && echo OK
OK
```

After stage 3 the card comes online and is reachable. The following is the verified output from the reference deployment (abridged):

```text
$ lspci | grep -i co-processor
04:00.0 Co-processor: Intel Corporation Xeon Phi coprocessor SE10/7120 series (rev 20)

$ micctrl --status
mic0: online (mode: linux image: /usr/share/mpss/boot/bzImage-knightscorner)

$ micinfo
  System Info
    HOST OS                 : Linux
    OS Version              : 3.10.0-693.el7.x86_64
    Driver Version          : 3.8.6-1
    MPSS Version            : 3.8.6
  Device No: 0, Device Name: mic0
    Coprocessor OS Version  : 2.6.38.8+mpss3.8.6
    Board SKU               : C0PRQ-7120 P/A/X/D
    ECC Mode                : Enabled
    Total No of Active Cores : 61
    Frequency               : 1238095 kHz
    GDDR Size               : 15872 MB
    Die Temp                : 56 C

$ ssh mic0
[root@mic0 ~]# uname -a
Linux mic0.local 2.6.38.8+mpss3.8.6 #1 SMP ... k1om GNU/Linux
```

## What does not work

These ten approaches were attempted before the working solution. They are recorded in full so others can match a symptom to a known dead end without re-running it. All produce the same practical outcome — the card cannot be used — for different underlying reasons.

### 1. Pre-built modules from jjkeijser/mpss

```sh
rpm -ivh https://github.com/jjkeijser/mpss/releases/download/RHEL7.9/mpss-modules-3.10.0-1160.el7.x86_64-3.8.6-4.x86_64.rpm
depmod -a
modprobe mic
# modprobe: ERROR: could not insert 'mic': Required key not available
```

They compile cleanly, but are unsigned — so securelevel still rejects them.

### 2. Manual signing with a self-generated key

```sh
openssl req -new -x509 -newkey rsa:2048 -keyout /root/MOK.priv \
  -outform DER -out /root/MOK.der -nodes -days 36500 -subj "/CN=Xeon Phi/"
yum install -y kernel-devel-$(uname -r)
/usr/src/kernels/$(uname -r)/scripts/sign-file sha256 \
  /root/MOK.priv /root/MOK.der /lib/modules/$(uname -r)/extra/mic.ko
modprobe mic
# Required key not available  (the key is not in any trusted keyring)
```

### 3. MOK enrollment

```sh
mokutil --import /root/MOK.der    # set a one-time password, reboot
```

MOK Manager needs a working Secure Boot chain. Enabling Secure Boot on the D30 yields, at boot:

```text
Secure Boot Violation: Invalid signature detected
error: bad shim signature        (when selecting CentOS in GRUB)
```

The shim loader is not signed for this firmware, so the MOK path is blocked.

### 4. `module.sig_enforce=0` kernel parameter

Added to the `linux` line via GRUB editing. Result: a kernel-panic **boot loop**.

### 5. `echo 0 > /proc/sys/kernel/module_sig_enforce`

```sh
echo 0 > /proc/sys/kernel/module_sig_enforce
# No such file or directory   (the control does not exist on this kernel)
```

### 6. `keyctl` injection into the kernel keyrings

```sh
keyctl padd asymmetric "" %:.platform < /root/MOK.der
# Can't find 'keyring:.platform'
keyctl padd asymmetric "" %:.system_keyring < /root/MOK.der
# add_key: Permission denied   (the runtime keyring is read-only)
```

### 7. `strip` / `objcopy` to drop the signature

```sh
strip --strip-debug /lib/modules/$(uname -r)/extra/mic.ko          # no effect
objcopy --remove-section=.note.gnu.build-id mic.ko mic_unsigned.ko # no effect
```

A Linux module signature is an appended block, not an ELF section, so neither tool removes it.

### 8. Full `CONFIG_MODULE_SIG=n` rebuild

```sh
sed -i 's/CONFIG_MODULE_SIG=y/# CONFIG_MODULE_SIG is not set/' kernel-3.10.0-x86_64.config
# (plus disabling MODULE_SIG_ALL, SHA256, HASH)
rpmbuild -bb ... kernel.spec
# build error: symbol-dependency failures
```

`CONFIG_MODULE_SIG` cannot be disabled wholesale; this is why the working fix keeps it `=y`.

### 9. Booting the stock old kernel 3.10.0-693 RPM

```sh
rpm -ivh --oldpackage https://vault.centos.org/7.4.1708/os/x86_64/Packages/kernel-3.10.0-693.el7.x86_64.rpm
rpm -ivh /root/mpss-3.8.6/modules/mpss-modules-3.10.0-693.17.1.el7.x86_64-3.8.6-1.x86_64.rpm
depmod -a
modprobe mic
# Required key not available   (the STOCK 693 kernel still ships SECURELEVEL=y)
```

This is the key diagnostic: **every** stock CentOS 7 kernel enforces it, old or new — confirming the problem is the kernel config, not the kernel version. (In the original attempt this step also required copying `mic.ko` between `/lib/modules/3.10.0-693.17.1.el7.x86_64/extra/` and `/lib/modules/3.10.0-693.el7.x86_64/extra/`, because the shipped module RPM targets a different `uname -r` than the stock 693 kernel — an additional dead end on top of the signature error.)

### 10. ELRepo alternative kernels

```sh
yum --enablerepo=elrepo-kernel install -y kernel-ml kernel-ml-devel
# Package not found   (ELRepo dropped CentOS 7 kernel-ml/kernel-lt)
```

### The diagnostic that pinned the root cause

```sh
dmesg | grep -iE "secure|lockdown|module.*sig"
# [    0.000000] Secure boot enabled        <-- but Secure Boot is OFF in BIOS

grep -E "MODULE_SIG|SECURELEVEL" /boot/config-$(uname -r)
# CONFIG_EFI_SECURE_BOOT_SECURELEVEL=y       <-- the root cause
```

## Autostart, SSH, and shutdown

Stage 3 already arranges autoload (`/etc/modules-load.d/mic.conf`) and enables the `mpss` service, so the card comes online automatically after boot. See `config/ssh-config.example` for reaching the host and `mic0`. Clean shutdown:

```sh
micctrl --shutdown mic0 && systemctl stop mpss && shutdown -h now
```

## Repository layout

```text
mpss-centos7-uefi/
├── README.md
├── LICENSE                        # Apache License 2.0
├── NOTICE                         # attribution + citation request (Apache-2.0)
├── CITATION.cff                   # machine-readable citation
├── .zenodo.json                   # drives auto-DOI on each GitHub release
├── CHANGELOG.md
├── CONTRIBUTING.md
├── scripts/
│   ├── lib/common.sh              # shared version pins, URLs, helpers
│   ├── 00-prepare-host.sh         # repos, deps, fetch kernel SRPM + MPSS
│   ├── 10-build-kernel.sh         # apply 2-line patch, build + install kernel
│   ├── 20-build-mpss-modules.sh   # build mic.ko against the custom kernel
│   └── 30-bringup-mic.sh          # install MPSS user space, start the card
├── patches/
│   └── disable-efi-securelevel.sh # the complete fix as a standalone patch
├── config/
│   ├── grub-custom-entry.example  # persistent boot entry for the custom kernel
│   └── ssh-config.example         # workstation ~/.ssh/config for host + mic0
├── examples/
│   └── end-to-end.md              # worked run + expected output
├── docs/
│   └── UPSTREAM-LICENSES.md       # verified per-component license audit + policy
└── .github/workflows/shellcheck.yml
```

## Status and scope

The procedure is the one verified on the reference machine documented above. The scripts automate exactly those steps; they have not been re-validated on every RHEL 7 point release or firmware. Pull requests reporting results on other affected firmware are welcome.

## License

[Apache License 2.0](LICENSE). The scripts and the kernel configuration patch are original work; the upstream Linux kernel and Intel `mpss-modules` that they build remain under their own licenses (GPL-2.0). This repository distributes only the deployment scripts and patch, not those upstream sources. See `NOTICE` for the attribution that Apache-2.0 carries forward into derivatives, and [`docs/UPSTREAM-LICENSES.md`](docs/UPSTREAM-LICENSES.md) for a per-component license audit (verified by reading the actual license files) and the redistribution boundary.

## How to cite

If this toolkit helps your work, please cite the archived software by its concept DOI (which always resolves to the latest version). Machine-readable metadata is in [`CITATION.cff`](CITATION.cff), from which GitHub renders a "Cite this repository" button.

> D. Vokhmintsev, *mpss-centos7-uefi: Reproducible deployment of Intel Xeon Phi (Knights Corner) coprocessors on UEFI CentOS 7*, Zenodo, 2026. doi:10.5281/zenodo.20367667

## Acknowledgements

This work builds on [jjkeijser/mpss](https://github.com/jjkeijser/mpss), which makes MPSS 3.8.6 compile against modern CentOS 7 kernels, and on the [CentOS Vault](https://vault.centos.org/) for keeping the archived kernel sources available.
