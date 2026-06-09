#!/bin/bash
set -euo pipefail

# Sync cc-tools to Claude Code plugin cache after local edits.
# Run this after making changes to update the cached version
# so new Claude Code sessions pick up the changes immediately.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/kintecus"
VERSION=$(jq -r .version "$REPO_ROOT/.claude-plugin/plugin.json")
CACHE_DIR="$HOME/.claude/plugins/cache/kintecus/tools/$VERSION"
INSTALL_FILE="$HOME/.claude/plugins/installed_plugins.json"

echo "Syncing tools@kintecus v$VERSION to plugin cache..."

# Update marketplace clone
if [[ -d "$MARKETPLACE_DIR/.git" ]]; then
  git -C "$MARKETPLACE_DIR" pull --ff-only origin main 2>/dev/null || {
    echo "Marketplace pull failed, copying directly..."
    rm -rf "$MARKETPLACE_DIR"
    cp -r "$REPO_ROOT" "$MARKETPLACE_DIR"
  }
else
  cp -r "$REPO_ROOT" "$MARKETPLACE_DIR"
fi

# Update cache
rm -rf "$CACHE_DIR"
mkdir -p "$CACHE_DIR"
cp -r "$REPO_ROOT"/{.claude-plugin,.mcp.json,commands,hooks,mcp,scripts,CLAUDE.md,README.md} "$CACHE_DIR/"

# Update version in installed_plugins.json
SHA=$(git -C "$REPO_ROOT" rev-parse HEAD)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Use jq to update the install record
jq --arg v "$VERSION" --arg sha "$SHA" --arg now "$NOW" --arg path "$CACHE_DIR" \
  '.plugins["tools@kintecus"][0].version = $v |
   .plugins["tools@kintecus"][0].installPath = $path |
   .plugins["tools@kintecus"][0].gitCommitSha = $sha |
   .plugins["tools@kintecus"][0].lastUpdated = $now' \
  "$INSTALL_FILE" > "${INSTALL_FILE}.tmp" && mv "${INSTALL_FILE}.tmp" "$INSTALL_FILE"

echo "Done. Restart Claude Code to load v$VERSION."
