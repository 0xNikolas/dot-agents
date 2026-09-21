---
argument-hint: "[path] [--dry-run]"
disable-model-invocation: true
name: ai-prune
description:
  Prune agent scratch directories by moving clearly outdated `.ai/` files into `.ai/archive/YYYY-MM-DD/` and deleting
  clearly outdated `.cache/` entries, leaving `.ai/todos` untouched.
---

# AI Prune

If these instructions are already present in the conversation from a slash or dollar invocation, follow them directly;
do not invoke this skill again through a skill tool.

Review everything under `.ai/` and `.cache/`, decide what is clearly outdated relative to the repository's present
state, archive the `.ai/` matches, and delete the `.cache/` matches. Prefer keeping over acting: only entries whose
staleness is backed by concrete evidence are touched.

## Arguments

- `path` (optional): Repository root or any path inside the repository. Default to the current directory.
- `--dry-run` (optional): Report the planned moves and deletions without changing the filesystem.

## Never Touch

- `.ai/todos/` and `.ai/archive/` (including everything beneath them).
- `TODO.md` and `PROMPT.md` files anywhere: they are user-owned notes. Do not read or move them.
- Live agent state: coordination ledgers, leases, locks, inboxes, and notification queues (for example `.ai/coord/`,
  `.cache/job-leases/`). A directory another agent may be writing to right now is live, not outdated.
- Tool-managed caches that the repository's configuration still wires in (prettier, ruff, pytest, uv, vitest, coverage,
  bundler and package-manager caches). They are regenerated on demand and are never "outdated".
- Anything modified within the last 24 hours, unless it is unambiguously a leftover of finished work.

## Workflow

1. Resolve the root. For a supplied file, use its containing directory; for a directory, use it. Resolve the Git root
   with `git -C "$start_dir" rev-parse --show-toplevel`; outside Git, use the directory itself. Store it as `repo_root`
   and compute `today=$(date +%Y-%m-%d)`. Stop when neither `.ai/` nor `.cache/` exists.

2. Inventory both trees with modification times, excluding the protected paths:

   ```sh
   fd -H -l -t f -E todos -E archive -E TODO.md -E PROMPT.md . "$repo_root/.ai"
   fd -H -l -t f . "$repo_root/.cache"
   ```

   Do not run per-file commands over the inventory; read the listing and open only the files whose relevance is unclear.

3. Establish the present state of the repository: `git log --oneline -30`, the current tree, `README.md`, `AGENTS.md` or
   `CLAUDE.md`, and the task runner or tool configuration. Then judge each entry, or a whole directory when all of its
   contents share the same fate. Treat an entry as clearly outdated only when evidence such as the following applies:
   - A plan, handoff, thread, or report whose work is visibly complete in the Git history or the current tree.
   - Notes that reference files, symbols, branches, PRs, or tools that no longer exist.
   - Debriefs, evidence captures, renders, logs, or temporary directories (random suffixes, `.tmp`, dated run folders)
     from a task that has finished.
   - Caches or outputs for tooling the repository no longer configures.

   Keep and list as uncertain anything you cannot tie to such evidence, anything still referenced by live docs, scripts,
   or configuration, and anything protected above.

4. Apply the decisions unless `--dry-run` was given:
   - `.ai/` entries: move each to `.ai/archive/$today/<path relative to .ai>` so the archive mirrors the original
     layout. Create parent directories with `mkdir -p`. A same-day re-run merges into the existing dated folder; if the
     destination path already exists, leave the source in place and report the collision instead of overwriting.
   - `.cache/` entries: delete with `rm -r`. Deletion is irreversible, so downgrade any borderline entry to "kept".
   - Remove directories under `.ai/` that became empty, except the protected ones.

5. Verify by listing `.ai/archive/$today/` and re-running the inventory from step 2; every acted-on path must be gone
   from its source. These directories are usually Git-ignored, so verify on the filesystem rather than with `git diff`.

## Completion

Report one outcome line, then a table with columns `Path`, `Action` (`archived`, `deleted`, `kept`), and `Reason`.
Include kept entries only when they were considered and judged uncertain; do not list protected or obviously live paths.
Keep paths, commands, and diagnostics undecorated.

- Success: `🗂️ Archived <n> → .ai/archive/<today> · Deleted <m> from .cache · Kept <k> uncertain`
- No-op: `✅ Nothing outdated under .ai or .cache · Kept <k> uncertain`
- Dry run: `🔎 Would archive <n> → .ai/archive/<today> · Would delete <m> from .cache · Kept <k> uncertain`
