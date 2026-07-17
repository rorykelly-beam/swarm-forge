# SwarmForge

SwarmForge runs a swarm of collaborating Claude agents — **specifier**, **coder**,
**refactorer**, and **architect** — each in its own tmux window, handing work off to
one another under a shared constitution.

## Running SwarmForge in a project

From the SwarmForge source directory, seed the target project with the files it needs,
then launch:

```bash
./copy-swarmforge.sh /path/to/your/project
cd /path/to/your/project
./swarm
```

The `swarm` launcher downloads the `swarmforge/scripts/` runtime from GitHub on first
run, so the target only needs the config, constitution, and role prompts.

## Copying the required files

`copy-swarmforge.sh` copies everything a folder needs to run SwarmForge via `./swarm`.

```bash
./copy-swarmforge.sh <target-dir> [--with-scripts] [--force]
```

It copies:

| File / directory | Purpose |
| --- | --- |
| `swarm` | the launcher (fetches `scripts/` and execs `swarmforge.sh`) |
| `swarmforge/swarmforge.conf` | window / agent configuration |
| `swarmforge/constitution.prompt` | constitution entrypoint |
| `swarmforge/constitution/articles/` | constitution articles |
| `swarmforge/roles/` | agent role prompts |

Options:

- `--with-scripts` — also copy the local `swarmforge/scripts/` runtime (if present) so
  the target works offline instead of downloading it on first run.
- `--force` — overwrite an existing `swarmforge/` install in the target (the script
  refuses to clobber one otherwise).

Example, provisioning a fully self-contained (offline) copy:

```bash
./copy-swarmforge.sh ~/work/my-app --with-scripts
```

### .gitignore handling

After copying, the script makes sure the target's `.gitignore` ignores SwarmForge's
runtime and downloaded files:

- `.swarmforge/`
- `.worktrees/`
- `swarmforge/scripts/`

If the target has no `.gitignore`, it is created with these entries. If one already
exists, only the missing entries are appended (matched line-for-line) — existing
contents are left untouched, so the step is safe to re-run.
