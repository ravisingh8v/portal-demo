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
  # read -p "🧹 Remove existing './src' before copying new one? (y/n): " confirm
  # if [[ $confirm =~ ^[Yy]$ ]]; then
    rm -rf ./src
    echo "✅ Old './src' removed."
  # else
    # echo "⚠️ Keeping existing './src'. Some files may overlap."
  # fi
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
  cp -R "$TEMP_DIR/$CLIENT_DIR/public/" ./public/
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
echo "Removing backend files/folders from root..."
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

# -----------------------
# STEP 7 — CLEANUP
# -----------------------
echo "🧹 Cleaning temporary worktree..."
git worktree remove "$TEMP_DIR" --force || true
rm -rf "$TEMP_DIR" || true

# -----------------------
# STEP 8 — COMMIT CHANGES
# -----------------------
# Ask for review before commit
read -p "🧐 Do you want to review the pulled changes before committing? (y/n): " REVIEW_CHOICE

if [[ "$REVIEW_CHOICE" == "y" || "$REVIEW_CHOICE" == "Y" ]]; then
  echo "✅ Please review your changes now. Use:"
  echo "   git status"
  echo "   git diff"
  echo "🕐 Once you're done reviewing, press 'y' to continue or 'n' to abort."
  
  read -p "Continue with commit and push? (y/n): " CONTINUE_CHOICE
  if [[ "$CONTINUE_CHOICE" != "y" && "$CONTINUE_CHOICE" != "Y" ]]; then
    echo "❌ Aborting sync as per your choice."
    exit 0
  fi
fi

# Ask for custom commit message
read -p "💬 Enter commit message (or press Enter for default): " COMMIT_MSG
COMMIT_MSG=${COMMIT_MSG:-$COMMIT_MSG_DEFAULT}

echo "💾 Committing and pushing changes..."
git add .
git commit -m "$COMMIT_MSG"
git push origin $(git branch --show-current)

echo "✅ Sync complete: $(git branch --show-current) branch updated."
