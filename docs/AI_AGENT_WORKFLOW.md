# AI agent workflow policy

This policy applies to every AI coding agent working in this repository, including Codex, Claude, Gemini, and future tools.

## Start each new feature from the default branch

For a new feature, bug fix, refactor, or documentation change:

1. Update the remote default branch (`origin/master`).
2. Create a new, descriptive local branch from that branch, such as `feat/coffee-cat` or `fix/dlna-seek`.
3. Do not begin unrelated work on an existing feature branch.

Exceptions require an explicit user instruction, for example: “continue the existing branch” or “work on branch `name`”.

## Restricted Git actions: require explicit approval

The following actions are restricted. An agent must perform them only after the user explicitly requests that exact type of action in the current conversation:

- Stage changes (`git add`)
- Create or amend a commit (`git commit`, `git commit --amend`)
- Push, force-push, or otherwise update a remote branch (`git push`)
- Create, edit, merge, close, or reopen a pull request
- Create a release, tag, or GitHub release

Do not infer permission from phrases such as “finish,” “complete,” “ready,” “ship,” “deploy,” “looks good,” or “tests pass.”

## Required handoff before restricted actions

After implementing and validating a change:

1. Run the relevant checks and tests.
2. Report what changed and the validation results.
3. State that the work is ready for review.
4. Ask the user whether they want the changes staged, committed, pushed, or made into a pull request.

Leave the working tree uncommitted until the user says what they want.

## Safety and scope

- Never use destructive Git commands (`reset --hard`, forced checkout, history rewriting) unless the user explicitly requests them.
- Preserve unrelated user changes in a dirty working tree.
- Do not include generated build output, credentials, local settings, caches, or personal data in commits.
- Keep each commit focused on one coherent user-approved change.

## Applying this policy

`AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` at the repository root point to this document so different agents discover the same rules.
