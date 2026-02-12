#!/bin/bash
# Install git hooks from git-hooks/ directory to .git/hooks/

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Installing git hooks..."

# Copy all hooks from git-hooks/ to .git/hooks/
for hook in "$SCRIPT_DIR"/git-hooks/*; do
    if [ -f "$hook" ]; then
        hook_name=$(basename "$hook")
        echo "  Installing $hook_name"
        cp "$hook" "$SCRIPT_DIR/.git/hooks/$hook_name"
        chmod +x "$SCRIPT_DIR/.git/hooks/$hook_name"
    fi
done

echo "✓ Git hooks installed successfully!"
echo ""
echo "Installed hooks:"
ls -1 "$SCRIPT_DIR/.git/hooks/" | grep -v ".sample"
