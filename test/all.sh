#!/bin/bash

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# Individual upstream scripts remain historical coverage, not this fork's gate.
exec make -C "$root" check
