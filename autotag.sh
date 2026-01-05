#!/bin/bash

# Exit script if command fails or uninitialized variables used
set -euo pipefail

# ==================================
# Git Configuration
# ==================================

git config --global --add safe.directory "$GITHUB_WORKSPACE"

if [ -z "$(git config user.name)" ]; then
  git config user.name "${GITHUB_ACTOR:-github-actions}"
  git config user.email "${GITHUB_ACTOR:-github-actions}@users.noreply.github.com"
fi

# ==================================
# Get latest version from git tags
# ==================================

git fetch --tags --force || true
GIT_TAGS=$(git tag --sort=version:refname)
GIT_TAG_LATEST=$(echo "$GIT_TAGS" | tail -n 1)

if [ -z "$GIT_TAG_LATEST" ]; then
  GIT_TAG_LATEST="v0.0.0"
fi

OLD_TAG_NAME="$GIT_TAG_LATEST"
GIT_TAG_LATEST=$(echo "$GIT_TAG_LATEST" | sed 's/^v//')

echo "Current version: v$GIT_TAG_LATEST"

# ==================================
# Determine Version Increment Type
# ==================================

VERSION_TYPE="${1-}"

if [ -z "$VERSION_TYPE" ]; then
  SOURCE_BRANCH=""
  
  # 1. Try to get branch from Pull Request event
  if [ "${GITHUB_EVENT_NAME-}" = "pull_request" ] && [ -f "${GITHUB_EVENT_PATH-}" ]; then
    IS_MERGED=$(jq -r '.pull_request.merged' "$GITHUB_EVENT_PATH")
    if [ "$IS_MERGED" != "true" ]; then
      echo "Pull request closed without merge. Skipping tag."
      exit 0
    fi
    SOURCE_BRANCH="$GITHUB_HEAD_REF"
    echo "Detected branch from Pull Request: $SOURCE_BRANCH"
  fi

  # 2. Try to detect from the last commit message if branch not found
  if [ -z "$SOURCE_BRANCH" ]; then
    LAST_MSG=$(git log -1 --pretty=%s)
    echo "Last commit message: $LAST_MSG"
    
    # Patch: fix, hotfix, bugfix, or others
    PAT_FROM_PATCH="from .*/(fix|hotfix|bugfix)/.*"
    PAT_MERGE_PATCH="Merge branch '(fix|hotfix|bugfix)/.*'"
    
    # Minor: feat, feature, release
    PAT_FROM_MINOR="from .*/(feat|feature|release)[/-].*"
    PAT_MERGE_MINOR="Merge branch '(feat|feature|release)[/-].*'"
    
    # Major: breaking (explicit only)
    PAT_FROM_MAJOR="from .*/(breaking|major)[/-].*"
    PAT_MERGE_MAJOR="Merge branch '(breaking|major)[/-].*'"

    if [[ "$LAST_MSG" =~ $PAT_FROM_MINOR ]] || [[ "$LAST_MSG" =~ $PAT_MERGE_MINOR ]]; then
      VERSION_TYPE="minor"
    elif [[ "$LAST_MSG" =~ $PAT_FROM_MAJOR ]] || [[ "$LAST_MSG" =~ $PAT_MERGE_MAJOR ]]; then
      VERSION_TYPE="major"
    elif [[ "$LAST_MSG" =~ $PAT_FROM_PATCH ]] || [[ "$LAST_MSG" =~ $PAT_MERGE_PATCH ]]; then
      VERSION_TYPE="patch"
    else
      # Default behavior for unknown branch types (often just 'patch')
       VERSION_TYPE="${INPUT_DEFAULT_BUMP:-patch}"
    fi
  else
    # Detect from SOURCE_BRANCH (for pull_request events)
    if [[ "$SOURCE_BRANCH" =~ ^(feat|feature|release)[/-].* ]]; then
      VERSION_TYPE="minor"
    elif [[ "$SOURCE_BRANCH" =~ ^(breaking|major)[/-].* ]]; then
      VERSION_TYPE="major"
    else
      # fix, hotfix, or any other branch name -> patch (or default)
      VERSION_TYPE="patch"
    fi
  fi

  # 3. Final Fallback/Safety Check (though logic above covers most)
  if [ -z "$VERSION_TYPE" ]; then
    VERSION_TYPE="${INPUT_DEFAULT_BUMP:-patch}"
    echo "Branch type not detected. Defaulting to: $VERSION_TYPE"
  fi
fi

echo "Bump type: $VERSION_TYPE"

# ==================================
# Increment version number
# ==================================

VERSION_NEXT=""

if [ "$VERSION_TYPE" = "patch" ]; then
  VERSION_NEXT="$(echo "$GIT_TAG_LATEST" | awk -F. '{printf "%d.%d.%d", $1, $2, $3+1}')"
elif [ "$VERSION_TYPE" = "minor" ]; then
  VERSION_NEXT="$(echo "$GIT_TAG_LATEST" | awk -F. '{printf "%d.%d.%d", $1, $2+1, 0}')"
elif [ "$VERSION_TYPE" = "major" ]; then
  VERSION_NEXT="$(echo "$GIT_TAG_LATEST" | awk -F. '{printf "%d.%d.%d", $1+1, 0, 0}')"
elif [ "$VERSION_TYPE" = "none" ]; then
  echo "Bump type is 'none'. Skipping tag creation."
  exit 0
else
  printf "\nError: invalid VERSION_TYPE '$VERSION_TYPE'\n\n"
  exit 1
fi

# ==================================
# Create and Push Git Tag
# ==================================

TAG_NAME="v$VERSION_NEXT"
echo "Next version: $TAG_NAME"

# Output to GitHub Actions
if [ -n "${GITHUB_OUTPUT-}" ]; then
  echo "old_tag=$OLD_TAG_NAME" >> "$GITHUB_OUTPUT"
  echo "new_tag=$TAG_NAME" >> "$GITHUB_OUTPUT"
fi

git tag -a "$TAG_NAME" -m "Release: $TAG_NAME"

if [ -n "${INPUT_GITHUB_TOKEN-}" ]; then
    git remote set-url origin "https://x-access-token:${INPUT_GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
    echo "Pushing tag $TAG_NAME to origin..."
    git push origin "$TAG_NAME"
else
    echo "INPUT_GITHUB_TOKEN not set. Skipping push."
fi