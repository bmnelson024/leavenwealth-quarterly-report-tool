#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# push-to-github.sh
# Commits the latest index.html and pushes to GitHub Pages.
# Run from Terminal: bash push-to-github.sh
# ──────────────────────────────────────────────────────────────────────────────

REPO_URL="https://github.com/bmnelson024/leavenwealth-quarterly-report-tool.git"
BRANCH="main"
DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$DIR"

# ── First-time setup: initialize git if not already done ──────────────────────
if [ ! -d ".git" ]; then
  echo "Setting up git for the first time..."
  git init
  git remote add origin "$REPO_URL"
  git fetch origin "$BRANCH" 2>/dev/null
  git checkout -b "$BRANCH" --track "origin/$BRANCH" 2>/dev/null || git checkout "$BRANCH"
  echo "Git initialized and connected to GitHub."
fi

# ── Stage, commit, and push ───────────────────────────────────────────────────
echo "Staging index.html..."
git add index.html

if git diff --cached --quiet; then
  echo "No changes to commit — index.html is already up to date on GitHub."
  exit 0
fi

TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
git commit -m "Update Quarterly Report Builder — $TIMESTAMP"

echo "Pushing to GitHub..."
git push origin "$BRANCH" --force

echo ""
echo "Done! Live at: https://bmnelson024.github.io/leavenwealth-quarterly-report-tool/"
