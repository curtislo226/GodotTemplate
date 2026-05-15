# Godot 4 Template

Opinionated starter for new Godot 4 projects. Pairs with the `/godot-bootstrap`
Claude Code skill, which fills in autoloads + `CLAUDE.md` based on the
project's scope.

## Usage

```bash
gh repo create my-game --template Curtis/godot-template --clone
cd my-game
# (Optional, recommended) In Claude Code:
#   /godot-bootstrap
# — scaffolds autoload .gd files and tailors CLAUDE.md to the project.

# Open in Godot (don't use "New Project" — project.godot already exists):
godot project.godot
# or: Godot launcher → Import → select my-game/project.godot
```

## What's pre-installed

| Artifact | Purpose |
|----------|---------|
| `addons/gut/` | [GUT](https://github.com/bitwes/Gut) — Godot Unit Testing framework, ready to use |
| `.gutconfig.json` | Default GUT config; tests discovered under `res://tests/` |
| `.github/workflows/test.yml` | CI runs GUT on push + PR (Ubuntu, Godot 4.6.0) |
| `.gitignore` | Godot + .NET + OS noise excluded |
| `project.godot` | Forward+ renderer, GUT plugin enabled, no `main_scene` set |
| `icon.svg` | Default Godot icon — replace with your game's icon |
| Empty folder skeleton | `domain/`, `presentation/`, `input/`, `scripts/`, `tests/domain/`, `assets/audio/{ui/}`, `assets/images/`, `assets/fonts/`, `localization/` |

## What this template DOESN'T include

These are project-specific decisions and live in the `/godot-bootstrap` skill:

- Autoload `.gd` files (AudioManager / SceneLoader / SettingsManager)
- Domain logic patterns (bounded contexts, event streams)
- Localization CSV (only if multi-language)
- Specific game addons (card-framework, dialogue plugins, etc.)
- Full `CLAUDE.md` — only a stub is shipped

## After cloning

1. **Open in Godot** to trigger the initial import scan:
   ```bash
   godot project.godot
   ```
   Or use the launcher → Import → select `project.godot`.

2. **Run `/godot-bootstrap`** in Claude Code (in the project root) to scaffold
   autoloads and write a project-specific `CLAUDE.md`.

3. **Replace `icon.svg`** with your game's icon.

4. **Set `config/name`** in Project Settings (or edit `project.godot` directly).

5. **Start building.** Verify GUT works at any time:
   ```bash
   godot -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
   ```
   Exit code 0 = all tests passed.

## Updating bundled GUT

GUT ships pre-installed. To update it later:

- Replace `addons/gut/` with a fresh download from the GUT AssetLib entry
  (or `git clone https://github.com/bitwes/Gut.git`).
- Test passes still run after the swap? Good. Otherwise check the migration
  notes in GUT's CHANGELOG.

## License

This template scaffold is freely reusable. GUT is bundled under its own MIT
license (see `addons/gut/LICENSE.md`).
