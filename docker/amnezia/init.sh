#!/usr/bin/env bash
set -euo pipefail

ACTIVE_CONFIG_FILE="${ACTIVE_CONFIG_FILE:-amnezia.conf}"
SOURCE_CONFIG="/config/${ACTIVE_CONFIG_FILE}"
TARGET_NAME="${ACTIVE_CONFIG_FILE%.conf}"
TARGET_CONFIG="/etc/amnezia/amneziawg/${TARGET_NAME}.conf"

mkdir -p /etc/amnezia/amneziawg
find /etc/amnezia/amneziawg -mindepth 1 -delete

if [[ ! -s "${SOURCE_CONFIG}" ]]; then
  echo "Missing active config: ${SOURCE_CONFIG}"
  exit 1
fi

echo "Using active config ${SOURCE_CONFIG}"
cp "${SOURCE_CONFIG}" "${TARGET_CONFIG}"
chmod 600 "${TARGET_CONFIG}"

cleanup() {
  awg-quick down "${TARGET_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT TERM INT

awg-quick up "${TARGET_NAME}"

# Keep container alive while interface stays up.
tail -f /dev/null
