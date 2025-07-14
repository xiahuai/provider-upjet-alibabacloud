#!/bin/bash

# restore-package-crds.sh - Restore original package CRDs after building family provider

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_PACKAGE_DIR="$ROOT_DIR/package"

echo "Restoring original package CRDs..."

# Regenerate all CRDs by running make generate (this will restore the original CRDs)
# For now, just restore from the backup in package/crds if it exists
if [ -d "$ROOT_DIR/.original-package-crds" ]; then
    rm -rf "$BASE_PACKAGE_DIR/crds"
    cp -r "$ROOT_DIR/.original-package-crds" "$BASE_PACKAGE_DIR/crds"
    rm -rf "$ROOT_DIR/.original-package-crds"
    echo "Restored original CRDs from backup"
else
    echo "No backup found - regenerating CRDs may be needed"
fi