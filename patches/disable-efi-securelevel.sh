#!/usr/bin/env bash
# The complete kernel-side fix, as a standalone two-line patch.
#
# This is exactly what 10-build-kernel.sh applies; it is provided separately so
# the change can be inspected, reviewed, or applied to a different kernel config.
#
# Usage:  disable-efi-securelevel.sh <path-to-kernel-.config>
#
# Rationale:
#   On some UEFI firmware (confirmed: Lenovo ThinkStation D30, BIOS A3KT70AUS),
#   the firmware reports Secure Boot as ENABLED to the OS even when Secure Boot
#   is DISABLED in BIOS setup. CONFIG_EFI_SECURE_BOOT_SECURELEVEL=y then raises
#   the kernel securelevel, which refuses every unsigned module (mic.ko fails
#   with "Required key not available"). Unsetting the option breaks that link
#   while leaving the module-signing facility (CONFIG_MODULE_SIG=y) intact.

set -euo pipefail

CONFIG="${1:?usage: $0 <path-to-kernel-.config>}"
[[ -f "${CONFIG}" ]] || { echo "No such file: ${CONFIG}" >&2; exit 1; }

# (1) Decouple kernel securelevel from UEFI Secure Boot state.
sed -i 's/CONFIG_EFI_SECURE_BOOT_SECURELEVEL=y/# CONFIG_EFI_SECURE_BOOT_SECURELEVEL is not set/' "${CONFIG}"
# (2) Do not require UEFI-trusted keys for module signatures.
sed -i 's/CONFIG_MODULE_SIG_UEFI=y/# CONFIG_MODULE_SIG_UEFI is not set/' "${CONFIG}"

echo "Patched ${CONFIG}. Security-relevant options now:"
grep -E "MODULE_SIG|SECURELEVEL" "${CONFIG}"
