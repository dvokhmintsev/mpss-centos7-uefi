# Upstream components and licenses

This repository contains **only original work** (deployment scripts + a kernel configuration patch) under the Apache License 2.0. It does **not** redistribute the Linux kernel or the Intel MPSS stack: the scripts *fetch and build* those on the user's machine at deployment time. This document records the licenses of the upstream components the toolkit touches, so the redistribution boundary is transparent.

## Verification

Licenses below were verified on 2026-05-24 by **extracting the MPSS 3.8.6 RPMs** (`rpm2cpio | cpio -idm`) and **reading the actual embedded license files** — not merely the RPM `License:` metadata tag. Source bundle: `mpss-3.8.6-linux.tar`.

Structural note observed during the audit: the binary RPMs ship **no per-package license files**; the only standalone license document in the bundle is the master `docs/license.txt` (the Intel MPSS EULA, installed by the `mpss-license` package). Open-source licenses are evidenced by the source/headers (`mpss-modules` `COPYING` and `.c` headers, the `-dev` headers, the SDK `src/legal/*.cpp`).

## Component licenses

### Open source — redistribution permitted under the component's own license (verified from actual file text)

| Component | License | Evidence read |
|---|---|---|
| `mpss-modules` (all kernel variants), `-headers` | **GPL-2.0** | `COPYING` (verbatim GPLv2) + per-`.c` GPL headers; source `mpss-modules-3.8.6-1.src.rpm` |
| `libscif` / SCIF user library | **LGPL-2.1** | `scif.h` header grant |
| `mpss-coi`, `mpss-myo` | **LGPL-2.1** + BSD-2/3-Clause | COI/MYO headers (LGPL); COI `src/legal/*.cpp` (BSD) |
| Linux kernel source (CentOS SRPM) | **GPL-2.0** | kernel `COPYING` |

### Proprietary — NOT redistributable (verified from the Intel MPSS EULA text)

`glibc2.12pkg-mpss-flash` (flash/firmware tooling and images), `libmicaccesssdk0`, `libsettings0`, `libodmdebug0`, `mpss-rasmm-kernel`, `mpss-memdiag-kernel`, `mpss-micsmc-gui`, `mpss-sysmgmt-{micras,micdiagnostic,python}`, `mpss-mpm`, `mpss-license` — all tagged `Intel-MPSS-License` and governed by `docs/license.txt`.

### Uncertain — treat as non-redistributable until clarified

- `intel-composerxe-compat-k1om`: tagged MIT, but the only license-bearing files are GCC's GPL-with-exception headers — the MIT tag is not corroborated by any file.
- `mpss-core`, `mpss-offload`: empty meta-packages (no files); the MIT tag describes nothing concrete.
- `mpss-sciftutorials`: tagged `Intel-Sample-Code-License`, but no license text ships in the bundle.
- `mpss-micmgmt` (+`-python`), `mpss-miccheck`, `libmicmgmt0`, `mpss-daemon`: LGPL-2.1 / GPL-2.0 tags are plausible but no per-package license file is present to confirm.

## The Intel MPSS redistribution clause

From the master EULA `docs/license.txt` (also installed as `/usr/share/doc/mpss-3.8.6/license.txt`), "INTEL SOFTWARE LICENSE AGREEMENT … MPSS (Internal Use and Object Code Distribution)":

> §2.1(A): "distribute the Software or modified versions of the Software only in Object Code, only under Intel's EULA attached as Attachment B, and only for use with Intel Products."

> Attachment B: "You have a license under Intel's copyrights to reproduce Intel's Software in binary form … for your organization's internal use only … You may not disclose, distribute or transfer any part of the Software except as provided in this Agreement."

In short: the proprietary components may be copied for internal use only, and any distribution is restricted to object code, under Intel's EULA, and only for use with Intel products. They cannot be re-hosted as a public download. The EULA's open-source carve-out preserves the separate (redistributable) terms of the GPL/LGPL/BSD components.

## Redistribution policy of this project

This package bundles **no upstream sources at all** — neither the GPL components nor the Intel MPSS bundle. Both the GitHub repository and the archived (Zenodo) snapshot contain only the original deployment scripts, the kernel configuration patch, and documentation. Everything else is **fetched at build time** by the scripts on the user's own machine:

- The CentOS kernel source RPM (from the CentOS Vault) and the Intel MPSS tarball (from an archived mirror) are downloaded at deployment time. Integrity is enforced fail-closed: both are checked against SHA-256 values pinned in `scripts/lib/common.sh`, and the kernel SRPM is additionally verified against the CentOS 7 GPG key, before anything is unpacked, built, or installed.
- For reference only: the GPL-2.0 sources (`mpss-modules-3.8.6-1.src.rpm` and the CentOS kernel SRPM) *would be* permissible to redistribute under their own licenses, whereas the Intel MPSS user-space bundle, firmware/flash images, and on-card OS image are **not** (Intel EULA, see above). This toolkit redistributes neither — it only fetches them.

This is why this repository can be Apache-2.0: it ships no GPL or Intel-licensed payload, only the instructions to obtain and build them.

## MPSS 4.4.1 (Knights Landing)

For reference, the KNL stack (out of scope for this KNC toolkit) follows the same structure: `kmod-mic` / `mpss-modules` GPL-2.0, `mpss-firmware` `CLOSED` (card BIOS/ME/SMC blob), `mpss-systools` `Intel-MPSS-License`, under the same MPSS EULA family.
