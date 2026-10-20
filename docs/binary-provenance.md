# Distributed sampler provenance

The normal Linux x86_64 package includes a ready-to-run `activity-sampler`.
Users do not compile it, install a toolchain, download another executable or run
an automatic build on enablement. The native Omarchy add/update flow obtains it
with the QML and Python helpers from this public repository.

The distributed executable is not accepted merely as an inherited opaque file.
On 2026-10-16 the current `activity-sampler.cpp`, `DiagnosticJournal.h` and Makefile
were rebuilt using GCC 16.2.1 20260810 on Linux x86_64. The output was byte-identical
to the existing 239736-byte package, SHA256
`48041c660e8fbc8eaced1b312ac9baf73e2303bdcb0957dcd3e5f4c8f6a4169d`.
The runtime and binary bytes did not change in this installation repair.

[Machine-readable provenance](binary-provenance.json) binds source, header,
Makefile and executable SHA256 values. Build hardening and source-path mapping
are in Makefile. An optional local reproduction is `make -B activity-sampler`;
that is a developer verification command, not an installation prerequisite.
Other compiler versions can legitimately produce different executable hashes.

## Runtime compatibility

The package is an ELF64 Linux x86_64 executable, with baseline x86-64 code generation
and no machine-specific `-march=native` flag. It dynamically uses glibc, libstdc++,
libm and libgcc_s. Required symbol ceilings are glibc 2.34 and GLIBCXX_3.4.32.
These are included by the current supported Arch-based Omarchy host. Optional
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
