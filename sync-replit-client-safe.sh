#!/bin/bash
# ---------------------------------------------------------------------
# 🧩 Safe Replit → Develop Sync Script
# ---------------------------------------------------------------------
# This script:
# 1. Pulls latest code from 'replit' branch
# 2. Extracts 'client' folder into a temp directory
# 3. Cleans backend files safely
# 4. Merges only frontend/client code (non-destructive)
# ---------------------------------------------------------------------

set -e  # Exit immediately if a command fails
set -o pipefail

REPLIT_BRANCH="replit"
BACKUP_DIR="../backup_$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="../replit_client_temp"
LOG_FILE="./sync_log_$(date +%Y%m%d_%H%M%S).txt"

echo "====================================================="
echo "🚀 Starting Safe Sync from '$REPLIT_BRANCH' branch"
echo "====================================================="
sleep 1

# Step 1: Verify current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🔍 You are currently on branch: $CURRENT_BRANCH" | tee -a $LOG_FILE

# Step 2: Ensure working tree is clean
if ! git diff-index --quiet HEAD --; then
  echo "⚠️ Uncommitted changes found. Commit or stash before running this script." | tee -a $LOG_FILE
  exit 1
fi

# Step 3: Backup current project
echo "📦 Creating backup of current frontend at $BACKUP_DIR" | tee -a $LOG_FILE
mkdir -p "$BACKUP_DIR"
cp -r ./ "$BACKUP_DIR/" || true

# Step 4: Fetch latest changes from origin
echo "🌐 Fetching latest changes..." | tee -a $LOG_FILE
git fetch origin $REPLIT_BRANCH || { echo "❌ Failed to fetch $REPLIT_BRANCH"; exit 1; }

# Step 5: Create a temporary working tree from Replit branch
echo "🧱 Checking out $REPLIT_BRANCH into temp folder..." | tee -a $LOG_FILE
rm -rf "$TEMP_DIR"
git worktree add "$TEMP_DIR" "origin/$REPLIT_BRANCH"

# Step 6: Copy only client/frontend files
echo "🧩 Copying Replit client files to ./src (non-destructive)" | tee -a $LOG_FILE
rsync -av --ignore-existing "$TEMP_DIR/client/" ./ --exclude server --exclude api --exclude drizzle --exclude migrations --exclude scripts | tee -a $LOG_FILE

# Step 7: Clean backend files that may have slipped in
echo "🧹 Removing backend configs and scripts..." | tee -a $LOG_FILE
rm -f drizzle.config.ts tsconfig.server.json vite.config.server.ts vite.config.backend.ts server.ts index.server.ts src/server.ts src/api.ts
rm -rf server api drizzle migrations scripts prisma

# Step 8: Cleanup temp worktree
git worktree remove "$TEMP_DIR" --force || true
rm -rf "$TEMP_DIR"

# Step 9: Commit the sync
echo "💾 Committing synced client changes..." | tee -a $LOG_FILE
git add .
git commit -m "🔄 Synced latest client changes from Replit branch (safe merge)" || echo "✅ No changes to commit."

# Step 10: Push changes (optional)
read -p "➡️ Do you want to push changes to remote? (y/n): " PUSH
if [ "$PUSH" == "y" ]; then
  git push origin "$CURRENT_BRANCH"
  echo "✅ Pushed successfully!"
else
  echo "🚫 Skipped pushing."
fi

echo "====================================================="
echo "✅ Sync completed safely!"
echo "Backup: $BACKUP_DIR"
echo "Log file: $LOG_FILE"
echo "====================================================="
