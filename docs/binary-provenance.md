# Distributed sampler provenance

The normal Linux x86_64 package includes a ready-to-run `activity-sampler`.
Users do not compile it, install a toolchain, download another executable or run
an automatic build on enablement. The native Omarchy add/update flow obtains it
with the QML and Python helpers from this public repository.

The distributed executable was rebuilt from `activity-sampler.cpp`,
`DiagnosticJournal.h` and Makefile using GCC 16.2.1 20260810 on Linux x86_64
for the isolated `fix/loadlet-laptop-review-20261030` branch based on
`be82a42af002144366fc20d0c2ffccf0a3429ccb`. This build changes journal pressure
handling, sensor recording's monotonic admission, bounded CPU policy context,
thermal discovery admission and repeated GPU process metadata reads.
`LC_ALL=C make -B activity-sampler` completed successfully.
The current 280696-byte executable has SHA256
`8e8e4c185042ab7abdaa676242bdf686ed9f481a95bbd03d400636bb42a979fb`.
The exact build-input hashes are recorded in the machine-readable provenance.
No new tests or byte-reproducibility comparison were run for this corrective
batch. Earlier post-PR1/v2.16.0 regression and CI results describe the previous
executable, not this build. This branch does not replace main, a release tag, or
Marketplace listing evidence. Source changes, installed bytes, loaded behavior
and physical hardware acceptance remain separate.

[Machine-readable provenance](binary-provenance.json) binds source, header,
Makefile and executable SHA256 values. Build hardening and source-path mapping
are in Makefile. An optional local reproduction is `make -B activity-sampler`;
that is a developer verification command, not an installation prerequisite.
Other compiler versions can legitimately produce different executable hashes.

## Runtime compatibility

The package is an ELF64 Linux x86_64 executable, with baseline x86-64 code generation
and no machine-specific `-march=native` flag. It dynamically uses glibc, libstdc++,
libm and libgcc_s. The previous package recorded symbol ceilings of glibc 2.34
and GLIBCXX_3.4.32. This branch used the same local toolchain, but its new executable
has not had a separate symbol-ceiling check; those historical values are not new
compatibility verification. Optional
NVIDIA NVML remains dynamically admitted by the existing device-state guard;
no NVIDIA package is required for ordinary CPU/RAM metrics.

Python 3 is used for existing process actions and local diagnostic exports.
There is no prebuilt ARM package, static-libc promise or arbitrary-Linux guarantee.
No root privileges, new daemon, runtime network fetch or first-run compilation.

## Actual package acceptance

`python3 -B test/package-checks.py` verifies the distributed file before any
source build, its exact ELF/permission/hash contracts and a real bounded reader
response from temporary procfs data. It protects a changed-byte negative control
and checks that normal sampling does not create a journal. CI runs it before
rebuilding the sampler; source-built tests are separate evidence.

The 2.8.1 workflow additionally has a `reproducible-package` job in the immutable
official Arch base-devel image
`archlinux@sha256:a25b54cf4b9c0de8752f5417c81810fb41bbfa5cdd6a504a9b6816a3b86b1e59`.
It checks GCC16.2.1, saves the distributed executable, rebuilds the exact checked
source, then uses `cmp` and prints both hashes. A mismatch fails the job rather
than replacing package bytes or treating source-declared hashes as proof.
Check that job on the exact release commit; the job definition alone is not a
successful remote reproduction.

Fresh native add/enable/update consumers and the existing loaded shared consumer
are checked separately in [verification](../VERIFICATION.md). Native shell IPC
stubs do not prove a fresh production Wayland window or all hardware sensors.
Reproducibility, runtime tests and maintainer-reviewed listing status are separate.
No independent review happened during this task.
