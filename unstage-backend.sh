#!/usr/bin/env bash
set -e  # stop if any command fails

# --------------------------
# CONFIG
# --------------------------
REPLIT_BRANCH="replit"
DELETE_PATHS=("server" "drizzle.config.ts" ".replit" "replit.nix")  # paths to discard/remove

echo "🔄 Pulling latest from $REPLIT_BRANCH..."
git fetch origin "$REPLIT_BRANCH"
git merge "origin/$REPLIT_BRANCH" --allow-unrelated-histories --no-edit || true

echo "🧹 Cleaning unwanted files/folders..."
for path in "${DELETE_PATHS[@]}"; do
  if [ -e "$path" ]; then
    echo "🗑️  Discarding changes for $path..."
    
    # 1️⃣ If it existed before merge, restore to previous state
    if git ls-tree -r HEAD~1 --name-only | grep -qx "$path"; then
      git restore --source=HEAD~1 --staged --worktree -- "$path" 2>/dev/null || true
      echo "↩️  Restored $path to its pre-merge state"
    else
      # 2️⃣ If it’s new from Replit (not in previous commit), remove it completely
      git rm -rf --cached --ignore-unmatch "$path" 2>/dev/null || true
      rm -rf "$path"
      echo "🧨 Removed new file/folder: $path"
    fi
  else
    # Even if it’s already deleted, unstage it if Git has it
    git restore --staged --worktree -- "$path" 2>/dev/null || true
    git rm -rf --cached --ignore-unmatch "$path" 2>/dev/null || true
  fi
done

# Ensure nothing in DELETE_PATHS is staged anymore
for path in "${DELETE_PATHS[@]}"; do
  git restore --staged --worktree -- "$path" 2>/dev/null || true
done

echo "✅ Cleanup complete."
echo "💡 Run 'git status' to verify — deleted paths should not appear in staged changes."
