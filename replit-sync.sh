#!/bin/bash
# Simple script to pull from replit branch and remove unwanted files

set -e  # stop if any command fails

REPLIT_BRANCH="replit"
DELETE_PATHS=("server" ".replit" "replit.nix")  # ⬅️ edit this list

echo "🔄 Pulling latest from $REPLIT_BRANCH..."
git pull origin $REPLIT_BRANCH

echo "🧹 Removing unwanted files/folders..."
for path in "${DELETE_PATHS[@]}"; do
  if [ -e "$path" ]; then
    rm -rf "$path"
    echo "🗑️  Removed $path"
  fi
done

echo "✅ Cleanup done. Changes ready for review."