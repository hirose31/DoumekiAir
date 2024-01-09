#!/bin/bash

set -Euo pipefail
export LANG="C"

cd ~/repos/DoumekiAir/script/ && \
  env PLACK_ENV=production carton exec -- ./access-google-photos
