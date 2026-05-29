---
name: github-issue-master-workflow
description: Use when Codex needs to manage or execute repository work through existing or explicitly requested GitHub issues while working directly on master, including decomposing large issues when asked, committing completed issue-backed work with issue-closing keywords, and verifying issue closure.
---

# GitHub Issue Master Workflow

Use GitHub Issues as the task source of truth when work starts from an existing
issue, when the user explicitly asks to create or track an issue, or when a task
is already issue-backed. Do not create new GitHub issues, sub-issues, or
TODO-tracking issues unless the user explicitly asks for them. Direct user
requests can be implemented directly on `master` without opening an issue first.
This is a solo-dev repo: work directly on `master` and do not create pull
requests or issue branches unless the repository owner explicitly changes this
rule.

## Start From An Issue

1. Find the existing GitHub issue for the work, or create one only when the user
   explicitly asks for issue tracking.
2. Confirm any issue-backed work has a clear goal, scope, acceptance criteria,
   and any relevant constraints.
3. If the user explicitly asks to split a large issue, create sub-issues before
   implementation. Keep each sub-issue independently finishable.
4. Ensure the current branch is `master`.
5. Ensure `master` is up to date before editing when remote access is available
   and the user has not asked for local-only work.
6. If the working tree has dirty changes, inspect them before editing. Ask the
   user what to do before switching branches or overwriting unrelated changes.

## During Work

- Keep each commit focused on one issue or one coherent sub-issue.
- Update the issue if the scope changes, if blockers appear, or if the work is
  intentionally split further.
- Do not create new GitHub issues for discovered TODOs unless the user
  explicitly asks for them.
- Avoid bundling unrelated cleanup into the issue commit unless it is required
  to complete that issue.

## Issue Image Attachments

- When attaching generated images or screenshots to an issue comment, upload the
  files as GitHub issue assets instead of committing temporary reference files to
  the repository.
- Use the already-installed `gh image` command when the user asks to attach
  local generated images, screenshots, or other issue-relevant image assets to a
  GitHub issue comment.
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

## Commit And Close

- Commit completed issue work directly on `master`.
- Include a GitHub closing keyword in the commit message for completed work, for
  example `Closes #12`.
- If the commit only partially advances a larger parent issue, reference the
  parent without a closing keyword and close only the completed sub-issue.
- Include concise validation details in the final user response.
- After pushing the commit to `master`, verify the linked issue or sub-issue is
  closed. Close it manually if GitHub automation did not close it.

## Completion

1. Confirm the local branch is `master`.
2. Confirm the working tree only contains intended changes.
3. Run the relevant validation for the issue.
4. Commit the completed work with the issue-closing keyword.
5. Push `master` when publishing is part of the task.
6. Verify the corresponding issue is closed, or close it manually if needed.

## Reference

For source notes from GitHub Docs, read
`references/github-workflow-sources.md` when the exact behavior of sub-issues or
closing keywords matters.
