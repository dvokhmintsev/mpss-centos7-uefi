#!/usr/bin/env bash
# Shared configuration and helpers for mpss-centos7-uefi.
# Sourced by the numbered stage scripts; not meant to be run directly.
#
# Procedure verified on a Lenovo ThinkStation D30 (Type 4354) with
# 2x Xeon E5-2697v2, CentOS 7.9.2009, Intel Xeon Phi 7120A (Knights Corner).
#
# Variables below are consumed by the scripts that source this library, so
# ShellCheck's per-file "unused" check (SC2034) does not apply here.
# shellcheck disable=SC2034

# -E (errtrace) makes the ERR trap fire inside functions and subshells too.
set -Eeuo pipefail

# --- Version pins (single source of truth) ---------------------------------
KERNEL_NVR="3.10.0-693.el7"                       # CentOS 7.4 kernel
KERNEL_ARCH="x86_64"
KERNEL_FULL="${KERNEL_NVR}.${KERNEL_ARCH}"        # 3.10.0-693.el7.x86_64
MPSS_VERSION="3.8.6"                              # final MPSS release for KNC

# --- Upstream sources -------------------------------------------------------
KERNEL_SRPM_URL="https://vault.centos.org/7.4.1708/os/Source/SPackages/kernel-${KERNEL_NVR}.src.rpm"
MPSS_TARBALL_URL="https://archive.org/download/intel-mpss-${MPSS_VERSION}/mpss-${MPSS_VERSION}-linux.tar"

# --- Pinned integrity checksums (SHA-256) -----------------------------------
# These pin the exact upstream bytes the procedure was verified against. The
# scripts FAIL CLOSED if a download does not match (tampering, mirror change,
# truncation). vault.centos.org is immutable; the archive.org item is stable.
# Recompute with: sha256sum <file>
KERNEL_SRPM_SHA256="fdd264018be896564c59d7414ac3c1230b98576cf7737bfcce055f491b7b0687"
MPSS_TARBALL_SHA256="3ce960db4c225f6e27ed6aa51c9dcb158fd93fe682d435ebd245849110b77a1b"

# CentOS 7 GPG key, used to verify the kernel SRPM signature.
CENTOS7_GPG_KEY="/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7"

# --- Working locations ------------------------------------------------------
WORKDIR="${MPSS_WORKDIR:-/root/mpss-build}"
RPMBUILD_DIR="${HOME}/rpmbuild"
MPSS_DIR="${WORKDIR}/mpss-${MPSS_VERSION}"

# --- Logging / guards -------------------------------------------------------
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

# Report which command/line aborted a long build. BASH_SOURCE[1] points at the
# calling stage script rather than this library, when available.
trap 'die "aborted (exit $?) at ${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}:${LINENO}"' ERR

# Fail closed if WORKDIR was overridden to an empty or non-absolute value.
[[ -n "${WORKDIR}" && "${WORKDIR}" == /* ]] \
  || die "MPSS_WORKDIR must be a non-empty absolute path (got: '${WORKDIR}')."

require_root() {
  [[ ${EUID} -eq 0 ]] || die "This script must be run as root."
}

require_centos7() {
  [[ -r /etc/redhat-release ]] || die "Not a Red Hat / CentOS system."
  grep -qE "release 7\." /etc/redhat-release \
    || die "This toolkit targets CentOS/RHEL 7 (found: $(cat /etc/redhat-release))."
}

require_custom_kernel() {
  local running; running="$(uname -r)"
  [[ "${running}" == "${KERNEL_FULL}" ]] \
    || die "Running kernel is ${running}, expected ${KERNEL_FULL}. Reboot into the custom kernel first (see config/grub-custom-entry.example)."
}

# verify_sha256 <file> <expected-hex> -- fail closed on mismatch.
verify_sha256() {
  local file="$1" want="$2" got
  [[ -f "${file}" ]] || die "File to verify not found: ${file}"
  got="$(sha256sum -- "${file}" | awk '{print $1}')"
  [[ "${got}" == "${want}" ]] \
    || die "SHA-256 mismatch for ${file}: got ${got}, expected ${want}. Refusing to use a tampered or corrupted file."
  log "  sha256 OK: ${file##*/}"
}

# fetch_and_verify <url> <output-file> <expected-sha256>
# Downloads only if absent, then ALWAYS verifies (covers cached files too).
fetch_and_verify() {
  local url="$1" out="$2" want="$3"
  [[ -f "${out}" ]] || wget -nv -O "${out}" "${url}"
  verify_sha256 "${out}" "${want}"
}

# verify_rpm_sig <rpm-file> -- verify the RPM's GPG signature (fail closed).
verify_rpm_sig() {
  local rpmfile="$1"
  [[ -f "${CENTOS7_GPG_KEY}" ]] || die "CentOS GPG key not found: ${CENTOS7_GPG_KEY}"
  rpm --import "${CENTOS7_GPG_KEY}"
  LC_ALL=C rpmkeys --checksig -- "${rpmfile}" >/dev/null 2>&1 \
    || die "RPM signature verification failed for ${rpmfile}"
  log "  GPG signature OK: ${rpmfile##*/}"
}
