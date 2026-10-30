#!/usr/bin/env bash
set -euo pipefail

# Pre-commit hook that initialises a repo created from the template:
#   1. Replaces __REPO_NAME__ / __MODULE_NAME__ placeholders in README.md
#   2. Generates docs/banner.jpg with the repo name rendered on it
#
# Modifies files in place — if changes are made, the hook exits 1 so the
# user can review, re-stage, and commit.

REPO_ROOT="$(git rev-parse --show-toplevel)"
README="$REPO_ROOT/README.md"
TEMPLATE_REPO_NAME="terraform-azurerm-module-template"

REPO_NAME="$(basename "$REPO_ROOT")"
MODULE_NAME="${REPO_NAME#terraform-azurerm-}"

# Skip if we're in the template repo itself
if [ "$REPO_NAME" = "$TEMPLATE_REPO_NAME" ]; then
  exit 0
fi

# Nothing to do if placeholder is not present
if ! grep -q '__REPO_NAME__\|__MODULE_NAME__' "$README" 2>/dev/null; then
  exit 0
fi

# Replace __REPO_NAME__ and __MODULE_NAME__ with actual values
sed -e "s/__REPO_NAME__/${REPO_NAME}/g" -e "s/__MODULE_NAME__/${MODULE_NAME}/g" "$README" > "$README.tmp" && mv "$README.tmp" "$README"

# Generate banner image with module name
BANNER_GENERATED=false
if command -v uv &>/dev/null; then
  if [ -f "$REPO_ROOT/docs/blank-banner.png" ]; then
    echo "init-from-template: Generating banner image..."
    if uv run "$REPO_ROOT/scripts/generate-banner.py" "$REPO_NAME"; then
      BANNER_GENERATED=true
    else
      echo "init-from-template: Warning: Banner generation failed. You can generate it manually later with:"
      echo "  uv run scripts/generate-banner.py $REPO_NAME"
    fi
  fi
else
  echo "init-from-template: Warning: 'uv' is not installed — skipping banner generation."
  echo "  Install uv (https://docs.astral.sh/uv/) and run manually:"
  echo "  uv run scripts/generate-banner.py $REPO_NAME"
fi

echo ""
echo "init-from-template: Replaced __REPO_NAME__ with '$REPO_NAME' and __MODULE_NAME__ with '$MODULE_NAME' in README.md"
if [ "$BANNER_GENERATED" = true ]; then
  echo "init-from-template: Generated docs/banner.jpg with module name '$REPO_NAME'"
  echo ""
  echo "Please review the changes, re-stage, and commit again:"
  echo "  git add README.md docs/banner.jpg"
else
  echo ""
  echo "Please review the changes, re-stage, and commit again:"
  echo "  git add README.md"
fi
exit 1
