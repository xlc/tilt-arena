---
name: github-issue-pr-workflow
description: Use when Codex needs to manage or execute repository work through GitHub issues and pull requests, including creating TODOs as issues, decomposing large issues into sub-issues, creating branches before implementation, linking PRs to issues, closing completed issues, and cleaning up local branches after merge.
---

# GitHub Issue PR Workflow

Use GitHub Issues as the task source of truth. Do not start implementation from
an untracked TODO, chat note, or local plan when the work should be tracked.

## Start From An Issue

1. Find or create the GitHub issue for the work.
2. Confirm the issue has a clear goal, scope, acceptance criteria, and any
   relevant constraints.
3. If the issue is too large for one pull request, create sub-issues before
   implementation. Keep each sub-issue independently reviewable.
4. Start the branch from the default branch, which this repo calls `master`.
5. Create a dedicated branch before editing files. Use a short name that includes
   the issue number, such as `issue-12-player-movement`.

## During Work

- Keep each branch and pull request focused on one issue or one coherent
  sub-issue.
- Update the issue if the scope changes, if blockers appear, or if the work is
  intentionally split further.
- Create new GitHub issues for discovered TODOs instead of leaving TODOs only in
  code, comments, or chat.
- Avoid bundling unrelated cleanup into an issue branch unless it is required to
  complete that issue.

## Issue Image Attachments

- When attaching generated images or screenshots to an issue comment, upload the
  files as GitHub issue assets instead of committing temporary reference files to
  the repository.
- Use the already-installed `gh image` command when the user asks to attach
  local generated images, screenshots, or other issue-relevant image assets to a
  GitHub issue or pull request comment.
- Run `gh image` to turn local image files into
  `https://github.com/user-attachments/assets/...` Markdown links:

  ```bash
  gh image --repo owner/repo image-1.png image-2.png > /tmp/image-links.md
  ```

- Then compose the issue comment body with those returned Markdown links and
  post it with `gh issue comment`:

  ```bash
  gh issue comment 14 --repo owner/repo --body-file /tmp/comment.md
  ```

- `gh image` uses GitHub's browser-session upload flow. If it fails with
  `uploadToken not found`, verify the browser session has write access to the
  target repository or provide a valid `GH_SESSION_TOKEN`. Do not fall back to
  repo-hosted raw links unless the user explicitly asks for repository assets.
- Treat `GH_SESSION_TOKEN` as a secret. Prefer passing it through the shell
  environment instead of a `--token` argument so it is not exposed in process
  listings or saved command history.

## Pull Requests

- Open the PR against `master` unless the repository owner explicitly chooses a
  different base.
- Link the PR to the completed issue in the PR body.
- Prefer GitHub closing keywords for completed work, for example `Closes #12`.
- Remember that closing keywords only auto-close issues when the PR targets the
  repository default branch. If the PR targets another branch, manually track and
  close the issue after merge.
- Include a concise summary and the validation performed.
- If a PR completes only part of a parent issue, link the sub-issue it completes
  and leave the parent open until all required sub-issues are done.

## Completion

1. After the PR merges, verify the linked issue or sub-issue is closed. Close it
   manually if automation did not close it.
2. Switch back to `master`.
3. Pull the latest default branch.
4. Delete the local issue branch.
5. Confirm there are no stale local branches for completed work.

## Reference

For source notes from GitHub Docs, read
`references/github-workflow-sources.md` when the exact behavior of sub-issues,
branch links, PR links, or closing keywords matters.
