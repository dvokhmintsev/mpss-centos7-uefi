#!/usr/bin/env bash
# Stage 1 -- reconfigure and rebuild the CentOS 7.4 kernel.
#
# The entire host-side fix is two configuration changes that decouple the
# kernel "securelevel" from the (mis-reported) UEFI Secure Boot state, so that
# unsigned modules such as mic.ko load normally. CONFIG_MODULE_SIG=y is kept:
# disabling it breaks the kernel build.
#
# The kernel rebuild is the only computationally heavy step; a multi-core CPU helps.

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

require_root
require_centos7

# Advisory (non-fatal): the rebuild is only needed when the firmware mis-reports
# Secure Boot. Warn early so a long kernel build is not spent on a host that is fine.
# NOTE: on a long-uptime host the early-boot "Secure boot enabled" line may have
# rotated out of the dmesg ring buffer, giving a false "may not need it" warning;
# confirm via /boot/config-$(uname -r) or journalctl -b if unsure.
if dmesg 2>/dev/null | grep -qi "secure boot enabled"; then
  log "Confirmed: firmware reports 'Secure boot enabled' -- this host needs the fix."
else
  log "WARNING: 'Secure boot enabled' not seen in dmesg; this host may not need the rebuild. Continuing."
fi

CONFIG="${RPMBUILD_DIR}/SOURCES/kernel-3.10.0-${KERNEL_ARCH}.config"
[[ -f "${CONFIG}" ]] \
  || die "Kernel config not found: ${CONFIG}. Run 00-prepare-host.sh first."

log "Patching kernel config: ${CONFIG}"
# (1) Root-cause fix: do not raise securelevel from a Secure Boot report.
sed -i 's/CONFIG_EFI_SECURE_BOOT_SECURELEVEL=y/# CONFIG_EFI_SECURE_BOOT_SECURELEVEL is not set/' "${CONFIG}"
# (2) Defence in depth: do not require UEFI-trusted keys for module signatures.
sed -i 's/CONFIG_MODULE_SIG_UEFI=y/# CONFIG_MODULE_SIG_UEFI is not set/' "${CONFIG}"

log "Security-relevant options after patching:"
grep -E "MODULE_SIG|SECURELEVEL" "${CONFIG}" >&2 || true

# --- Sanity checks: fail fast if the patch did not take ---------------------
grep -q '^CONFIG_MODULE_SIG=y' "${CONFIG}" \
  || die "CONFIG_MODULE_SIG=y missing -- do NOT disable it (breaks the build)."
grep -q '^# CONFIG_EFI_SECURE_BOOT_SECURELEVEL is not set' "${CONFIG}" \
  || die "Securelevel option was not disabled -- the sed patch failed."

log "Building kernel RPMs (this is the slow step)"
cd "${RPMBUILD_DIR}/SPECS" || die "Cannot enter ${RPMBUILD_DIR}/SPECS"
rpmbuild -bb --target="${KERNEL_ARCH}" \
  --with baseonly \
  --without debug --without debuginfo \
  --without doc --without perf --without tools \
  kernel.spec 2>&1 | tee "${WORKDIR}/kernel-build.log"

RPMS="${RPMBUILD_DIR}/RPMS/${KERNEL_ARCH}"
KERNEL_RPM="${RPMS}/kernel-${KERNEL_FULL}.rpm"
KERNEL_DEVEL_RPM="${RPMS}/kernel-devel-${KERNEL_FULL}.rpm"

# Assert the build actually produced the RPMs before trying to install them,
# so a changed build layout fails with a clear message rather than an obscure
# rpm error.
[[ -f "${KERNEL_RPM}" && -f "${KERNEL_DEVEL_RPM}" ]] \
  || die "Expected built RPMs not found in ${RPMS} (kernel + kernel-devel for ${KERNEL_FULL})."

# Install WITHOUT --force. The kernel is multi-install by design, so this ADDS
# the custom kernel alongside the existing one (which stays as a boot fallback)
# rather than overwriting it; --force would mask downgrade/conflict warnings and
# risk an unbootable system. Skip cleanly if already installed (idempotent).
log "Installing custom kernel + kernel-devel (kept alongside the existing kernel)"
if rpm -q "kernel-${KERNEL_FULL}" >/dev/null 2>&1; then
  log "  kernel-${KERNEL_FULL} already installed -- skipping"
else
  rpm -ivh "${KERNEL_RPM}" "${KERNEL_DEVEL_RPM}"
fi

log "Stage 1 complete."
log "REBOOT into ${KERNEL_FULL}, then run ./20-build-mpss-modules.sh."
log "  The previous kernel remains installed -- keep it as the GRUB fallback"
log "  in case the custom kernel fails to boot."
log "  (See config/grub-custom-entry.example for a persistent GRUB entry.)"
log "Verify after reboot:"
log "  uname -r                                              # ${KERNEL_FULL}"
log "  grep EFI_SECURE_BOOT_SECURELEVEL /boot/config-\$(uname -r)"
