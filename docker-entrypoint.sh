#!/bin/sh
set -eu
# Railway monte généralement le volume avec root comme propriétaire.
# Préparer uniquement notre répertoire, puis abandonner les privilèges.
if [ "$(id -u)" = 0 ]; then
  mkdir -p /data
  chown bricks:bricks /data
  for file in /data/first_bricks.dets*; do
    [ ! -f "$file" ] || chown bricks:bricks "$file"
  done
  exec runuser -u bricks -- "$@"
fi
exec "$@"
