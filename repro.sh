#!/usr/bin/env bash
# Reproduces Sveltia CMS's GitHub publish call against a branch with a pending required check,
# then the proposed alternative: auto-merge pinned to the checked head.
# Needs: gh signed in with write access to REPO, and the ruleset described in README.md.
set -euo pipefail
REPO="${REPO:-ajbarea/sveltia-github-publish-repro}"
SLUG="repro-$(date +%s)"
BRANCH="cms/posts/$SLUG"

base=$(gh api "repos/$REPO/git/ref/heads/main" --jq .object.sha)
gh api -X POST "repos/$REPO/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$base" >/dev/null
gh api -X PUT "repos/$REPO/contents/content/posts/$SLUG.md" -f branch="$BRANCH" \
  -f message="Create Post “$SLUG”" \
  -f content="$(printf -- '---\ntitle: %s\n---\n\nBody.\n' "$SLUG" | base64 -w0)" >/dev/null
pr=$(gh api -X POST "repos/$REPO/pulls" -f head="$BRANCH" -f base=main \
  -f title="Create Post “$SLUG”" --jq .number)
head=$(gh api "repos/$REPO/pulls/$pr" --jq .head.sha)
echo "PR #$pr, head $head"

echo "== 1. What publish() sends today, while the required check is still running"
sleep 15
gh api -X PUT "repos/$REPO/pulls/$pr/merge" -f merge_method=squash \
  -f commit_title="Create Post “$SLUG”" -f sha="$head" -i 2>&1 | grep -E '^HTTP|"message"' || true

echo "== 2. Proposed: enablePullRequestAutoMerge, pinned with expectedHeadOid"
id=$(gh api "repos/$REPO/pulls/$pr" --jq .node_id)
gh api graphql \
  -f query='mutation($id:ID!,$oid:GitObjectID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,mergeMethod:SQUASH,expectedHeadOid:$oid}){pullRequest{autoMergeRequest{mergeMethod enabledAt}}}}' \
  -f id="$id" -f oid="$head" --jq .data.enablePullRequestAutoMerge.pullRequest.autoMergeRequest

echo "== 3. Once the check passes (about 5 minutes), GitHub merges it:"
echo "   gh api repos/$REPO/pulls/$pr --jq '{merged, merged_by: .merged_by.login, merge_commit_sha}'"
