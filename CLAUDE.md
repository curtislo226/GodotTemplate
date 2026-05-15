# Project Name (replace this)

A Godot 4 project, scaffolded from
[godot-template](https://github.com/Curtis/godot-template).

> **This CLAUDE.md is a stub.** Run `/godot-bootstrap` in Claude Code to
> generate conventions tailored to this project's scope (lifespan,
> localization needs, team size). After running the skill, replace this
> entire file with the generated one.

---

## Always-applicable rules (don't remove these)

### Git policy — explicit consent required

- **Never** run `git commit`, `git push`, `git reset`, `git rebase`,
  `git checkout` (in a way that discards work), `git branch -D`, `git tag`,
  or any other state-changing git operation without the user's explicit
  consent for **that specific action**.
- Read-only git inspection is fine without asking: `git status`, `git log`,
  `git diff`, `git show`, `git branch` (list), `git remote -v`.
- After file edits, **stop and tell the user what changed and that it is
  uncommitted** — let them decide when to commit. Do not stage or commit
  automatically.
- You may **propose** git actions ("want me to commit this?") — just don't
  execute until the user says yes.
- A "yes" to one git action does not authorize future ones. Ask each time.

### Don't touch `addons/`

Don't modify files under `addons/`. Extend via composition or subclassing.
Updates come from upstream (AssetLib / git clone replacements), not local
edits.

### Testing

GUT is pre-installed under `addons/gut/`. Run tests via:

```bash
godot -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Exit code 0 = all pass.

---

## What `/godot-bootstrap` will add to this file

When you run the bootstrap skill, it will replace this CLAUDE.md with a
fuller version covering:

- Platform targets (desktop / mobile / web)
- Scripting language preference (GDScript / GDScript + C#)
- Folder layout conventions (domain/presentation/input split, or simpler
  for short-lived projects)
- Audio + settings + localization conventions
- Naming + style conventions
- Communication language (繁體中文 / English / etc.)

Until then, treat this as a vanilla Godot 4 project with the rules above.
