#!/usr/bin/env bash
# Stage 3 -- install MPSS user space and bring the coprocessor online.
#   * install the MPSS 3.8.6 user-space RPMs
#   * load the mic module
#   * generate the default card configuration and provision SSH keys
#   * start and enable the mpss service, and arrange autoload at boot

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

require_root
require_centos7
require_custom_kernel        # a reboot into the stock kernel here reintroduces the deadlock

[[ -d "${MPSS_DIR}" ]] \
  || die "MPSS directory not found: ${MPSS_DIR}. Run 00-prepare-host.sh first."

log "Installing MPSS ${MPSS_VERSION} user-space packages"
cd "${MPSS_DIR}" || die "Cannot enter ${MPSS_DIR}"
# Assert the expected MPSS RPMs are present before installing, so a changed or
# wrong bundle fails with a clear message instead of yum erroring on a glob that
# expanded to nothing. (The bundle's contents are SHA-256-pinned in stage 0.)
shopt -s nullglob
mpss_core_rpms=( mpss-core-*.rpm mpss-daemon-*.rpm libscif0-*.rpm )
shopt -u nullglob
(( ${#mpss_core_rpms[@]} >= 3 )) \
  || die "Expected MPSS ${MPSS_VERSION} user-space RPMs not found in ${MPSS_DIR}; is this the right bundle?"
yum localinstall -y \
  mpss-daemon-*.rpm mpss-core-*.rpm mpss-boot-files-*.rpm \
  mpss-miccheck-*.rpm mpss-miccheck-bin-*.rpm \
  mpss-micmgmt-*.rpm mpss-micmgmt-python-*.rpm \
  mpss-license-*.rpm mpss-myo-*.rpm \
  glibc2.12pkg-mpss-flash-*.rpm glibc2.12pkg-mpss-rasmm-kernel-*.rpm \
  glibc2.12pkg-libmicaccesssdk0-*.rpm glibc2.12pkg-libmicmgmt0-*.rpm \
  glibc2.12pkg-libsettings0-*.rpm libscif0-*.rpm

log "Loading mic module"
modprobe mic \
  || die "mic failed to load -- is the custom kernel running and stage 2 done?"

log "Generating default coprocessor configuration"
# Idempotent / non-destructive: --initdefaults regenerates the card config and
# would overwrite an existing (possibly customized) one, so only run it when no
# MPSS config is present. Remove /etc/mpss to deliberately regenerate.
if [[ -f /etc/mpss/default.conf || -f /etc/mpss/mic0.conf ]]; then
  log "  existing MPSS configuration found in /etc/mpss -- keeping it (not re-running --initdefaults)"
else
  micctrl --initdefaults
fi
# micctrl --sshkeys pushes root's public key to the card, so root needs a key
# pair. If none exists we create one; this is a PASSPHRASELESS root key, since
# the card must be reachable non-interactively by the mpss service. If you
# prefer to control root's key policy (e.g. a hardened host), pre-provision
# /root/.ssh/id_ed25519 yourself before running this stage.
if [[ -f /root/.ssh/id_ed25519.pub || -f /root/.ssh/id_rsa.pub ]]; then
  log "  root already has an SSH key -- using it"
else
  log "  creating a passphraseless ed25519 key for root (needed for ssh mic0)"
  ssh-keygen -t ed25519 -N '' -C "mpss-mic0 $(hostname -s)" -f /root/.ssh/id_ed25519
fi
micctrl --sshkeys=root mic0

log "Starting and enabling the mpss service"
systemctl start mpss
systemctl enable mpss

log "Arranging autoload of mic at boot"
echo mic > /etc/modules-load.d/mic.conf

log "Coprocessor status:"
micctrl --status || true

log "Stage 3 complete."
log "Wait for the card to reach 'online' (micctrl --status), then:  ssh mic0"
log "Full board info:  micinfo"
