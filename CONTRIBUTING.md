# Contributing

Contributions are welcome, especially **reports of results on other affected
hardware and firmware**. The toolkit was verified on one reference machine
(see `README.md`); confirmations or fixes for other UEFI workstations, Xeon Phi
KNC models, or RHEL 7 point releases are the most valuable contributions.

## Reporting a problem or a result

Open an issue with:
- host model and BIOS/UEFI version,
- `cat /etc/redhat-release` and `uname -r` (stock kernel),
- the relevant `dmesg | grep -i "secure boot"` line,
- the exact command and full error output.

## Submitting changes

- Keep shell scripts POSIX-friendly Bash, `set -Eeuo pipefail`, fail fast.
- **`shellcheck` must pass with no warnings** (`shellcheck -S warning scripts/*.sh`);
  this is enforced by CI.
- Quote all variable expansions and prefer `[[ ]]` over `[ ]`.
- Update `CHANGELOG.md` under an `## [Unreleased]` heading.

## License of contributions

By contributing you agree that your contributions are licensed under the
project's Apache License 2.0 (see `LICENSE`).
