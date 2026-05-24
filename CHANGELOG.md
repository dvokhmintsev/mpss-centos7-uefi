# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-24

Initial public release.

### Added
- `scripts/00-prepare-host.sh` - repoint EOL repos to the CentOS Vault, install
  build dependencies, fetch the kernel SRPM and Intel MPSS 3.8.6.
- `scripts/10-build-kernel.sh` - apply the two-option kernel configuration patch
  and rebuild the CentOS 7.4 (3.10.0-693) kernel.
- `scripts/20-build-mpss-modules.sh` - build `mic.ko` against the custom kernel.
- `scripts/30-bringup-mic.sh` - install MPSS user space and bring the card online.
- `scripts/lib/common.sh` - shared version pins, helpers, and fail-fast guards.
- Fail-closed integrity verification of downloads: SHA-256 pinning for the
  kernel SRPM and MPSS tarball, plus CentOS GPG-signature verification of the
  kernel SRPM, before anything is unpacked, built, or installed.
- `patches/disable-efi-securelevel.sh` - the complete fix as a standalone patch.
- `config/` - GRUB and SSH configuration examples.
- Documentation of ten failed approaches in `README.md`.

[1.0.0]: https://github.com/dvokhmintsev/mpss-centos7-uefi/releases/tag/v1.0.0
