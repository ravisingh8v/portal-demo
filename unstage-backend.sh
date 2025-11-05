#!/usr/bin/env bash
set -e

REPLIT_BRANCH="replit"
DELETE_PATHS=("server" "drizzle.config.ts" ".replit" "replit.nix")

echo "🔄 Fetching latest from $REPLIT_BRANCH..."
git fetch origin "$REPLIT_BRANCH"

echo "🔀 Merging $REPLIT_BRANCH into current branch..."
git merge "origin/$REPLIT_BRANCH" --allow-unrelated-histories --no-edit || true

echo "🧹 Reverting unwanted files/folders to pre-merge state..."
for path in "${DELETE_PATHS[@]}"; do
  if git ls-tree -r HEAD --name-only | grep -qx "$path"; then
    git checkout HEAD^ -- "$path" 2>/dev/null || echo "⚠️  Skipped $path (no previous version)"
    echo "↩️  Restored $path to pre-merge state"
  else
    echo "ℹ️  $path not tracked previously, removing from working tree"
    rm -rf "$path"
  fi
done

echo "✅ Cleanup complete. Review changes with: git status"
