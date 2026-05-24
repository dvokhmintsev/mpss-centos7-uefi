#!/usr/bin/env bash
# Stage 2 -- build the mpss-modules (mic.ko) against the custom kernel.
#
# Run this AFTER rebooting into the custom kernel (3.10.0-693): the module is
# compiled against the running kernel, so the running kernel must be the
# reconfigured one. This is the step where the original deadlock disappears.

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

require_root
require_centos7
require_custom_kernel        # running kernel must be the reconfigured 3.10.0-693

# The module is compiled against /usr/src/kernels/$(uname -r); that tree comes
# from the custom kernel-devel installed in stage 1.
[[ -d "/usr/src/kernels/${KERNEL_FULL}" ]] \
  || die "Missing /usr/src/kernels/${KERNEL_FULL}. Did stage 1 install the custom kernel-devel?"

MODULE_SRPM="${MPSS_DIR}/src/mpss-modules-${MPSS_VERSION}-1.src.rpm"
[[ -f "${MODULE_SRPM}" ]] \
  || die "MPSS module SRPM not found: ${MODULE_SRPM}. Run 00-prepare-host.sh first."

log "Installing mpss-modules SRPM"
# Idempotent: skip if already unpacked (see stage 0 for the same pattern).
if [[ -f "${RPMBUILD_DIR}/SPECS/mpss-modules.spec" ]]; then
  log "  mpss-modules.spec already present -- skipping SRPM install"
else
  rpm -ivh "${MODULE_SRPM}"
fi

log "Building mpss-modules against $(uname -r)"
rpmbuild -bb "${RPMBUILD_DIR}/SPECS/mpss-modules.spec" 2>&1 \
  | tee "${WORKDIR}/mpss-modules-build.log"

# Resolve the built RPM explicitly and assert exactly one match, so a no-match
# or a stale leftover fails loudly instead of feeding a literal glob to rpm.
shopt -s nullglob
mapfile -t MODULE_RPMS < <(printf '%s\n' \
  "${RPMBUILD_DIR}/RPMS/${KERNEL_ARCH}"/mpss-modules-${KERNEL_FULL}-*.rpm)
shopt -u nullglob
(( ${#MODULE_RPMS[@]} == 1 )) \
  || die "Expected exactly one built mpss-modules RPM, found ${#MODULE_RPMS[@]}: ${MODULE_RPMS[*]:-<none>}"

log "Installing built mpss-modules: ${MODULE_RPMS[0]##*/}"
# --force here only re-installs our OWN freshly built, same-version module on a
# re-run (it is not a kernel package and cannot trigger a downgrade); this keeps
# the stage idempotent.
rpm -ivh --force "${MODULE_RPMS[0]}"
depmod -a

log "Verifying that mic.ko loads"
if modprobe mic; then
  log "SUCCESS: 'mic' module loaded -- no 'Required key not available' error."
else
  die "modprobe mic failed. Check that securelevel is off: dmesg | grep -i secure"
fi

log "Stage 2 complete. Next: ./30-bringup-mic.sh"
