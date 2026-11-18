# Godot 4.8 Template

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
| `addons/gut/` | [GUT](https://github.com/bitwes/Gut) 9.7.1 — Godot Unit Testing framework, ready to use |
| `addons/build_kit/` | From [GodotToolBox](https://github.com/curtislo226/GodotToolBox): Windows + Web builds, git-tag versions, CI, itch.io upload (see `addons/build_kit/README.md`) |
| `build.cfg` | build_kit settings — **set `name` to your game's file name** |
| `build.ps1` | Local build: tests → Web + Windows → `build/<version>/` (same code as CI) |
| `export_presets.cfg` | Web (no threads, no GDExtension) + Windows (embedded pck) presets — tracked in git |
| `.gutconfig.json` | Default GUT config; tests discovered under `res://tests/` |
| `.github/workflows/build_kit.yml` | CI: tests + Web export on every push; all platforms kept 30 days on main; `v*` tag → GitHub Release (+ itch.io if configured) |
| `.gitignore` | Godot + .NET + OS noise excluded |
| `project.godot` | Godot 4.8, GL Compatibility renderer (needed for Web), GUT plugin enabled, no `main_scene` set |
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

4. **Set `config/name`** in Project Settings (or edit `project.godot` directly), the `name` in `build.cfg`,
   and `application/product_name` in the Windows export preset.

5. **Start building.** Verify GUT works at any time:
   ```bash
   godot -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
   ```
   Exit code 0 = all tests passed. Build everything locally with `./build.ps1`
   (`-Check` only validates the settings). Show the version in game with `BuildInfo.label()`.

## Updating bundled GUT

GUT ships pre-installed. To update it later:

- Replace `addons/gut/` with a fresh download from the GUT AssetLib entry
  (or `git clone https://github.com/bitwes/Gut.git`).
- Test passes still run after the swap? Good. Otherwise check the migration
  notes in GUT's CHANGELOG.

## License

This template scaffold is freely reusable. GUT is bundled under its own MIT
license (see `addons/gut/LICENSE.md`).
