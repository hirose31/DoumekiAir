#!/bin/bash

exec >/tmp/access-google-photos.log 2>&1

set -Euo pipefail
export LANG="C"

cd ~/repos/DoumekiAir/script/ && \
  env PLACK_ENV=production carton exec -- ./access-google-photos
