# wow-dev

A Claude Code plugin and Agent Skill for World of Warcraft addon and WeakAura development. It checks every API claim against Blizzard's own UI source for the exact game flavor you target, instead of trusting model memory.

## What it does

- Pins each task to one flavor: Retail, Mists Classic, Classic Era, Anniversary or WoW Forever.
- Looks up APIs, events, templates and assets in a local, per-flavor copy of `Gethe/wow-ui-source` and `Ketho/BlizzardInterfaceResources`, refreshed daily.
- Handles Midnight secret values: reads the secret tags in Blizzard's generated API docs and steers code toward curves, duration objects and secret-safe setters.
- Builds ready-to-paste `!WA:2!` WeakAura import strings offline and validates that they decode and that their custom code compiles.
- Prefers native Blizzard frames, templates and textures over custom UI.

## Install

### Claude Code

```
/plugin marketplace add miyanko-dev/wow-dev
/plugin install wow-dev@miyanko-dev
```

The skill triggers on its own for WoW work. You can also call it with `/wow-dev:wow-dev`.

### Other agents

Codex, Cursor, OpenCode, GitHub Copilot and others that read Agent Skills:

```
npx skills add miyanko-dev/wow-dev
```

## Requirements

| Tool | Needed for |
|---|---|
| `git` | API and asset lookups |
| `lua` 5.2 or newer | WeakAura import strings |
| `curl` | WeakAura strings without a local WeakAuras install |

No GitHub token or MCP server is needed.

## What it runs and fetches

The plugin has no hooks, no MCP server and no telemetry. It sends no data anywhere. The agent runs these only when a task needs them:

| Action | Where | Stored in |
|---|---|---|
| `git clone --depth 1` of one flavor branch, refreshed at most once a day | github.com, public repositories listed below | `~/.cache/wow-dev`, about 40 to 55 MB per flavor |
| `curl` of LibDeflate, LibSerialize and WeakAuras' `Transmission.lua`, only when WeakAuras is not installed | raw.githubusercontent.com, api.github.com | `~/.cache/wowdev-weakauras` |
| Item and spell lookups by build | wago.tools | not stored |
| Reads your WeakAuras SavedVariables to match your installed version | local game folder | not copied |

## Sources

| Repository | Used for |
|---|---|
| [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) | APIs, events, templates, secret value tags |
| [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources) | Textures, atlases, CVars, API lists |
| [WeakAuras/WeakAuras2](https://github.com/WeakAuras/WeakAuras2) | WeakAuras internals |
| [wago.tools](https://wago.tools) | Item and spell data per build |
| [wowdev/wow-listfile](https://github.com/wowdev/wow-listfile) | File IDs |

## Limits

A WeakAura string that decodes and compiles can still misbehave in game. Test it in the client.

## License

MIT. Not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft and WoW are trademarks of Blizzard Entertainment, Inc.
