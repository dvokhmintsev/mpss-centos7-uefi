#!/usr/bin/env bash
# Stage 0 -- prepare a CentOS 7.9 host for the build.
#   * repoint end-of-life CentOS 7 repositories to the CentOS Vault
#   * install kernel build dependencies
#   * fetch and install the kernel-3.10.0-693 source RPM
#   * fetch and extract Intel MPSS 3.8.6
#
# Idempotent: re-running re-uses already downloaded archives.

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

require_root
require_centos7

log "Repointing EOL CentOS 7 repositories to vault.centos.org"
# CentOS 7 reached end of life; the mirrorlist hosts are gone. Switch the
# base repo to the immutable vault. A timestamped backup is kept first so the
# change is reversible. The baseurl rewrite is anchored to mirror.centos.org so
# a custom/local mirror that merely contains the substring "mirror" is untouched.
REPO_FILE="/etc/yum.repos.d/CentOS-Base.repo"
BACKUP="${REPO_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp -a "${REPO_FILE}" "${BACKUP}"
log "  backed up ${REPO_FILE} -> ${BACKUP}"
sed -i -e '/^mirrorlist/d' \
       -e 's,^#baseurl=http://mirror\.centos\.org,baseurl=http://vault.centos.org,' \
       "${REPO_FILE}"
yum clean all
yum makecache
# NOTE: the manual procedure also ran `yum update -y` here. We deliberately
# omit it: a full update can pull a newer stock kernel that is irrelevant to
# this fix (we build and boot our own 3.10.0-693), and keeps the run faster
# and more deterministic.

log "Installing kernel build dependencies"
yum install -y \
  rpm-build redhat-rpm-macros asciidoc hmaccalc perl-ExtUtils-Embed \
  pesign xmlto audit-libs-devel binutils-devel elfutils-devel \
  elfutils-libelf-devel newt-devel numactl-devel pciutils-devel \
  python-devel zlib-devel ncurses-devel bison flex openssl-devel bc \
  net-tools keyutils kernel-headers kernel-devel gcc make wget perl \
  openssh-server

log "Ensuring sshd is enabled (remote bring-up convenience)"
systemctl enable --now sshd

mkdir -p "${WORKDIR}"
cd "${WORKDIR}" || die "Cannot enter ${WORKDIR}"

log "Fetching and verifying kernel source RPM"
# Download (if absent) then verify SHA-256 AND the CentOS GPG signature before
# the SRPM is ever unpacked. Fail closed on any mismatch.
KERNEL_SRPM="kernel-${KERNEL_NVR}.src.rpm"
fetch_and_verify "${KERNEL_SRPM_URL}" "${KERNEL_SRPM}" "${KERNEL_SRPM_SHA256}"
verify_rpm_sig "${KERNEL_SRPM}"
log "Installing kernel SRPM into ${RPMBUILD_DIR}"
# Idempotent: skip if the SRPM has already been unpacked (re-installing an
# installed SRPM returns non-zero and would abort under `set -e`).
if [[ -f "${RPMBUILD_DIR}/SPECS/kernel.spec" ]]; then
  log "  kernel.spec already present -- skipping SRPM install"
else
  rpm -ivh "${KERNEL_SRPM}"
fi

log "Fetching and verifying Intel MPSS ${MPSS_VERSION}"
# MPSS RPMs are not CentOS-signed, so SHA-256 pinning is the integrity control.
MPSS_TARBALL="mpss-${MPSS_VERSION}-linux.tar"
fetch_and_verify "${MPSS_TARBALL_URL}" "${MPSS_TARBALL}" "${MPSS_TARBALL_SHA256}"
log "Extracting MPSS tarball"
tar --no-same-owner -xf "${MPSS_TARBALL}"

log "Stage 0 complete."
log "  Sources fetched into : ${WORKDIR}"
log "  Kernel SRPM unpacked  : ${RPMBUILD_DIR}/{SOURCES,SPECS}"
log "Next: ./10-build-kernel.sh"
