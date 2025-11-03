#!/bin/bash
set -e
set -o pipefail

# -----------------------
# CONFIG
# -----------------------
REPLIT_BRANCH="replit"
CLIENT_DIR="client"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEMP_DIR="../replit_temp_$TIMESTAMP"

# backend/server folders to remove after syncing
REMOVE_FOLDERS=("server" "api" "drizzle" "migrations" "prisma")
REMOVE_FILES=("drizzle.config.ts" "server.ts" "index.server.ts")

# -----------------------
# STEP 1 — CHECK GIT STATUS
# -----------------------
echo "====================================================="
echo "🚀 Starting safe sync from branch '$REPLIT_BRANCH' to '$CURRENT_BRANCH'"
echo "====================================================="

if ! git diff-index --quiet HEAD --; then
  echo "⚠️ You have uncommitted changes. Please commit or stash them first."
  exit 1
fi

# -----------------------
# STEP 2 — FETCH AND PREP TEMP WORKTREE
# -----------------------
echo "📦 Fetching latest '$REPLIT_BRANCH'..."
git fetch origin "$REPLIT_BRANCH"

echo "🧱 Creating temporary worktree at $TEMP_DIR"
rm -rf "$TEMP_DIR" || true
git worktree add "$TEMP_DIR" "origin/$REPLIT_BRANCH"

# -----------------------
# STEP 3 — VALIDATE STRUCTURE
# -----------------------
if [ ! -d "$TEMP_DIR/$CLIENT_DIR/src" ]; then
  echo "❌ Expected '$CLIENT_DIR/src' not found in $REPLIT_BRANCH branch."
  git worktree remove "$TEMP_DIR" --force || true
  exit 1
fi

# -----------------------
# STEP 4 — CLEAN OLD FRONTEND (optional)
# -----------------------
if [ -d "./src" ]; then
  read -p "🧹 Remove existing './src' before copying new one? (y/n): " confirm
  if [[ $confirm =~ ^[Yy]$ ]]; then
    rm -rf ./src
    echo "✅ Old './src' removed."
  else
    echo "⚠️ Keeping existing './src'. Some files may overlap."
  fi
fi

# -----------------------
# STEP 5 — MOVE CLIENT FILES
# -----------------------
echo "📁 Copying frontend from '$REPLIT_BRANCH/$CLIENT_DIR' to current repo..."

# Copy client/src → ./src
mkdir -p ./src
cp -R "$TEMP_DIR/$CLIENT_DIR/src/"* ./src/

# Move index.html to root (if exists)
if [ -f "$TEMP_DIR/$CLIENT_DIR/index.html" ]; then
  cp "$TEMP_DIR/$CLIENT_DIR/index.html" ./index.html
fi

# Move public folder to root
if [ -d "$TEMP_DIR/$CLIENT_DIR/public" ]; then
  cp -R "$TEMP_DIR/$CLIENT_DIR/public" ./public
fi

# Copy any root-level frontend files (like vite.config, package.json partials)
for file in "$TEMP_DIR/$CLIENT_DIR"/*; do
  name=$(basename "$file")
  if [[ "$name" != "src" && "$name" != "public" && "$name" != "node_modules" ]]; then
    cp -R "$file" "./$name"
  fi
done

rm -rf "$CLIENT_DIR"

# -----------------------
# STEP 6 — REMOVE BACKEND FILES
# -----------------------
echo ""
read -p "🧹 Remove backend files/folders from root (server, drizzle, etc)? (y/n): " remove_backend
if [[ $remove_backend =~ ^[Yy]$ ]]; then
  for folder in "${REMOVE_FOLDERS[@]}"; do
    if [ -d "./$folder" ]; then
      rm -rf "./$folder"
      echo "Removed folder: $folder"
    fi
  done

  for file in "${REMOVE_FILES[@]}"; do
    if [ -f "./$file" ]; then
      rm -f "./$file"
      echo "Removed file: $file"
    fi
  done
fi

# -----------------------
# STEP 7 — CLEANUP
# -----------------------
echo "🧹 Cleaning temporary worktree..."
git worktree remove "$TEMP_DIR" --force || true
rm -rf "$TEMP_DIR" || true

# -----------------------
# STEP 8 — COMMIT CHANGES
# -----------------------
git add -A
git status --short

read -p "💬 Enter commit message (leave blank for default): " msg
if [ -z "$msg" ]; then
  msg="Sync frontend from replit ($REPLIT_BRANCH) on $TIMESTAMP"
fi

if git diff --cached --quiet; then
  echo "⚠️ No changes to commit."
else
  git commit -m "$msg"
  echo "✅ Committed: $msg"
fi

# -----------------------
# STEP 9 — OPTIONAL PUSH
# -----------------------
read -p "🚀 Push changes to origin/$CURRENT_BRANCH now? (y/n): " push_now
if [[ $push_now =~ ^[Yy]$ ]]; then
  git push origin "$CURRENT_BRANCH"
  echo "✅ Pushed to origin/$CURRENT_BRANCH"
else
  echo "⏭ Skipped push. You can do it later."
fi

echo "====================================================="
echo "🎉 Sync complete. Your './src' now contains Replit client code."
echo "====================================================="
