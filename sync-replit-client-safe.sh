#!/bin/bash
set -e
set -o pipefail

# -----------------------
# CONFIG
# -----------------------
REPLIT_BRANCH="replit"
CLIENT_DIR_IN_REPLIT="client"    # path inside replit worktree that contains frontend
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEMP_DIR="../replit_temp_$TIMESTAMP"

# Backend files/folders to remove from repo root after copying client to root
# Adjust this list to your repo specifics
BACKEND_FOLDERS=( server api drizzle migrations scripts prisma )
BACKEND_FILES=( drizzle.config.ts tsconfig.server.json vite.config.server.ts vite.config.backend.ts server.ts index.server.ts src/server.ts src/api.ts Dockerfile docker-compose.yml fly.toml vercel.json package.server.json )

# -----------------------
# FUNCTIONS
# -----------------------
echo_header() {
  echo "====================================================="
  echo " $1"
  echo "====================================================="
}

prompt_yesno() {
  # prompt_yesno "Question?" => exits with 0 for yes, 1 for no
  read -p "$1 (y/n): " ans
  case "$ans" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

# Copy file with checks: if target exists, handle depending on mode
# modes:
#   "skip"  -> never overwrite
#   "all"   -> overwrite all
#   "ask"   -> ask per file
COPY_MODE="ask"   # default

# copy_from_temp <source_file_relative_to_temp_client> <dest_root_relative_path>
copy_from_temp() {
  src="$TEMP_DIR/$CLIENT_DIR_IN_REPLIT/$1"
  dst="./$2"
  dst_dir="$(dirname "$dst")"

  if [ ! -e "$src" ]; then
    return 0
  fi

  if [ -e "$dst" ]; then
    if [ "$COPY_MODE" = "skip" ]; then
      echo "⏭ Skipping existing: $2"
      return 0
    elif [ "$COPY_MODE" = "all" ]; then
      mkdir -p "$dst_dir"
      cp -f "$src" "$dst"
      echo "🔁 Overwritten: $2"
      return 0
    else
      # ask per-file
      read -p "File exists: $2. Overwrite? (y)es / (n)o / (A)ll / (S)kip all: " ans
      case "$ans" in
        [Yy]*) mkdir -p "$dst_dir"; cp -f "$src" "$dst"; echo "🔁 Overwritten: $2" ;;
        [Aa]*) COPY_MODE="all"; mkdir -p "$dst_dir"; cp -f "$src" "$dst"; echo "🔁 Overwritten: $2 (and set to overwrite ALL)";;
        [Ss]*) COPY_MODE="skip"; echo "⏭ Skip all future existing files";;
        *) echo "⏭ Skipped: $2";;
      esac
      return 0
    fi
  else
    mkdir -p "$dst_dir"
    cp "$src" "$dst"
    echo "✅ Copied: $2"
    return 0
  fi
}

# Recursively copy entire client tree, respecting modes
copy_client_tree() {
  # we want to iterate all files under $TEMP_DIR/$CLIENT_DIR_IN_REPLIT
  if [ ! -d "$TEMP_DIR/$CLIENT_DIR_IN_REPLIT" ]; then
    echo "⚠️  No $CLIENT_DIR_IN_REPLIT found in replit branch at $TEMP_DIR. Aborting."
    return 1
  fi

  # find all files (preserve subdir structure)
  pushd "$TEMP_DIR/$CLIENT_DIR_IN_REPLIT" >/dev/null
  # Use find to list files only
  find . -type f | while read -r file; do
    # strip leading ./ from find output
    rel="${file#./}"
    copy_from_temp "$rel" "$rel"
  done
  popd >/dev/null
}

# -----------------------
# START
# -----------------------
echo_header "Starting safe sync: replit -> $CURRENT_BRANCH"

# 0. Ensure clean working tree
if ! git diff-index --quiet HEAD --; then
  echo "⚠️ Uncommitted changes detected. Please commit or stash before running this script."
  git status --porcelain
  exit 1
fi

# 1. Fetch and prepare temporary worktree
echo "Fetching origin/$REPLIT_BRANCH..."
git fetch origin "$REPLIT_BRANCH"

echo "Creating temporary worktree at $TEMP_DIR from origin/$REPLIT_BRANCH..."
rm -rf "$TEMP_DIR" || true
git worktree add "$TEMP_DIR" "origin/$REPLIT_BRANCH"

# 2. Confirm we found client folder
if [ ! -d "$TEMP_DIR/$CLIENT_DIR_IN_REPLIT" ]; then
  echo "⚠️ $CLIENT_DIR_IN_REPLIT not found inside the replit worktree. Available top-level files:"
  ls -la "$TEMP_DIR" || true
  git worktree remove "$TEMP_DIR" --force || true
  exit 1
fi

# 3. If destination root has files that will conflict, show a summary and choose mode
echo ""
echo "Scanning for potential conflicts between replit client and current repo..."
CONFLICT_COUNT=0
pushd "$TEMP_DIR/$CLIENT_DIR_IN_REPLIT" >/dev/null
while IFS= read -r -d '' f; do
  rel="${f#./}"
  if [ -e "../../$rel" ]; then
    CONFLICT_COUNT=$((CONFLICT_COUNT+1))
  fi
done < <(find . -type f -print0)
popd >/dev/null

if [ $CONFLICT_COUNT -gt 0 ]; then
  echo "⚠️ Detected $CONFLICT_COUNT existing files in repo that would conflict."
  echo "Choose how to handle existing files:"
  echo "  1) Overwrite ALL existing files"
  echo "  2) Skip ALL existing files (keep current repo files)"
  echo "  3) Ask per file (default)"
  read -p "Select 1/2/3 (default 3): " choice
  case "$choice" in
    1) COPY_MODE="all" ;;
    2) COPY_MODE="skip" ;;
    *) COPY_MODE="ask" ;;
  esac
else
  echo "No existing file conflicts detected. Files will be copied."
  COPY_MODE="skip"  # safe default: copy only non-existing files
fi

# 4. Copy files from replit client to repo root
echo ""
echo "🧩 Copying client files from replit branch into repo root (mode: $COPY_MODE)..."
copy_client_tree

# 5. After copying, optionally remove client folder contents (in repo root) if you want moved files only.
# User asked to move client to root and then delete client folder in source replit. We'll delete the client dir from repo root if it exists.
# But be careful: in our workflow we only copied client/* to root (files placed at root paths), so a 'client' folder in repo root may not be needed.
if [ -d "./client" ]; then
  if prompt_yesno "Remove local ./client folder now? (this deletes ./client in repo root)"; then
    rm -rf ./client
    echo "Removed ./client from repo root."
  else
    echo "Left ./client in repo root."
  fi
fi

# 6. Remove backend files/folders from repo root (ask user)
echo ""
echo "🧹 Backend cleanup will remove these folders: ${BACKEND_FOLDERS[*]}"
echo "and these files: ${BACKEND_FILES[*]}"
if prompt_yesno "Proceed to remove backend files/folders from repo root?"; then
  for d in "${BACKEND_FOLDERS[@]}"; do
    if [ -d "./$d" ]; then
      rm -rf "./$d"
      echo "Removed folder: $d"
    fi
  done
  for f in "${BACKEND_FILES[@]}"; do
    if [ -f "./$f" ]; then
      rm -f "./$f"
      echo "Removed file: $f"
    fi
  done
else
  echo "Skipped backend cleanup."
fi

# 7. Remove the temp worktree
echo ""
echo "Cleaning up temporary worktree..."
git worktree remove "$TEMP_DIR" --force || true
rm -rf "$TEMP_DIR" || true

# 8. Stage changes, show summary, and prompt for commit message
echo ""
echo "Staging changes..."
git add -A

# Show git status summary
echo ""
echo "Git diff summary (staged):"
git --no-pager status --porcelain | sed -n '1,200p'

echo ""
read -p "💬 Enter a commit message (press Enter for default): " CUSTOM_MSG
if [ -z "$CUSTOM_MSG" ]; then
  COMMIT_MSG="Sync frontend from replit ($REPLIT_BRANCH) on $TIMESTAMP"
else
  COMMIT_MSG="$CUSTOM_MSG"
fi

# Commit
if git diff --cached --quiet; then
  echo "⚠️ No staged changes to commit."
else
  git commit -m "$COMMIT_MSG"
  echo "Committed with message: $COMMIT_MSG"
fi

# 9. Optional push prompt
echo ""
if prompt_yesno "Push commit to origin/$CURRENT_BRANCH now?"; then
  git push origin "$CURRENT_BRANCH"
  echo "✅ Pushed to origin/$CURRENT_BRANCH"
else
  echo "Skipped push. You can push manually later."
fi

echo_header "Done. Safe sync complete."

exit 0
