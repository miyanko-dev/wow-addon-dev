---
name: wow-addon-dev
description: world of warcraft addon and weakaura development across retail, mists classic, classic era, anniversary and wow forever. use for writing, reviewing, debugging, simplifying, or designing wow addons and weakauras, for midnight secret values and addon restrictions, and for producing ready-to-paste !WA:2! weakaura import strings. verifies APIs, events, assets, templates, UI patterns, and version differences against the matching flavor branch of gethe/wow-ui-source and ketho/blizzardinterfaceresources, plus weakauras/weakauras2 for weakauras triggers, conditions, prototypes, and custom code behaviour.
---

# WoW Addon and WeakAura Developer

Two kinds of deliverable, pick by what the task needs.

- **Addon**, when the behaviour should stand alone, survive WeakAuras being disabled, or needs its own saved variables, slash commands, or key bindings.
- **WeakAura**, when the user asks for one, or when the job is a display driven by triggers. Always ship it as an import string, see below.

## Expertise

Act with deep, authoritative knowledge of World of Warcraft addon and WeakAura development across all live flavors: retail, Mists Classic, Classic Era, Anniversary and WoW Forever.

Know the APIs, events, frame and template system, secure/taint rules, secret values, and the differences between these versions cold. Still verify every claim against the source, see below.

## Sources

Verify APIs, events, assets, textures, atlases, templates, Blizzard UI patterns, and version differences against these repositories only:

| Key | Repository | Use for |
|---|---|---|
| `ui` | `Gethe/wow-ui-source` | Blizzard APIs, events, templates, UI code, secret value tags |
| `res` | `Ketho/BlizzardInterfaceResources` | icons, textures, atlases, CVars, global API lists |
| `wa` | `WeakAuras/WeakAuras2` | WeakAuras internals, branch `main` |

Fetch the branch for the target flavor with the bundled script, `${CLAUDE_SKILL_DIR}/scripts/wow-source.sh` (the `scripts/` folder next to this file). It clones on first use, refreshes at most once a day, and prints the local path and the build it holds.

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/wow-source.sh" ui classic_era
```

Then search that path with the Grep tool or `rg`. Read only the matching lines, never whole files: `UnitDocumentation.lua` alone is about 30k tokens.

- Signatures and secret tags: `Interface/AddOns/Blizzard_APIDocumentationGenerated`, search for `Name = "UnitHealth",`
- Blizzard UI code and templates: the rest of `Interface/AddOns`
- Assets, CVars and API lists: the `res` clone, under `Resources/`

State the build the script printed whenever an answer depends on the version.

When git is unavailable, read single files from `https://raw.githubusercontent.com/<repo>/<branch>/<path>`, or GitHub MCP `get_file_contents` with an explicit `ref`. Never use GitHub code search for a flavor question, it only indexes the default branch `live`. Do not use web search or other clones for API behaviour. If no source can be reached, say the repositories could not be checked and do not guess.

warcraft.wiki.gg is allowed for behaviour notes and change history once a signature is confirmed in the source. Treat it as secondary.

### WeakAuras2 scope

- Reach for it only when the question is about WeakAuras itself, not about a Blizzard API. Blizzard behaviour is still settled by `ui`.
- Its `main` branch ships classic flavors only. Retail `.toc` files were removed on 2026-01-28, so retail code paths there are unmaintained and must not be treated as authoritative.
- Pick the TOC by the major version of the target build: 1 is `_Vanilla`, 2 `_TBC`, 3 `_Wrath`, 4 `_Cata`, 5 `_Mists`. Read its `## Interface:` number. WoW Forever has no TOC of its own, so treat WeakAuras support there as unverified unless the user has it installed.
- Trigger and condition logic lives in `WeakAuras/Prototypes.lua`, cooldown and event plumbing in `WeakAuras/GenericTrigger.lua`, and cross-flavor API shims in `WeakAuras/Compatibility.lua`.

## Game data outside the UI source

File IDs, item stats, spell costs, and cooldowns are not in the UI source repositories. Never quote one from memory, look it up or state that it is unverified.

- Sound, texture, and model file IDs: the community listfile at `wowdev/wow-listfile`, released as `community-listfile.csv`
- Item and spell values: `wago.tools` DB2 exports pinned to the target build, such as `ItemSparse`, `SpellName`, `SpellPower`, `SpellCooldowns`
- Query shape: `https://wago.tools/db2/<Table>/csv?build=<build>&filter[<Column>]=<value>`, with builds listed at `https://wago.tools/api/builds`
- Treat third party sites as secondary. Wowhead in particular can serve Season of Discovery values on Classic pages, so confirm against the client data for the build you are targeting.

## Strict version focus

Pin every decision to one flavor and its branch.

| Flavor | Branch |
|---|---|
| Retail | `live` |
| Mists Classic | `classic` |
| Classic Era | `classic_era` |
| Anniversary | `classic_anniversary` |
| WoW Forever | `forever` |

- Anniversary realms progress through expansions, so read its build from the script rather than assuming Classic Era.
- If the task depends on the version and it is unclear, check which flavors are installed first. The game lives in `/Applications/World of Warcraft/` on macOS and `C:\Program Files (x86)\World of Warcraft\` on Windows, one `_flavor_` folder each. Ask only when more than one is installed and the choice still matters.
- Write code only against the APIs, events, and templates that exist on that branch.
- Take the `## Interface:` number from the branch, never from memory, and use the matching per-flavor `.toc` (e.g. `_Vanilla`, `_Mainline`).

## Secret values

Since 12.0, some APIs return secret values to addon code. Addon code can hold and display a secret but not inspect it.

- They apply on `live` and `forever`. The `classic`, `classic_era` and `classic_anniversary` branches ship the helper APIs but tag no API as secret. Re-check on each new build with a count of `SecretArguments` in `Blizzard_APIDocumentationGenerated`.
- Before using any unit, aura, cooldown, spell, combat or chat API on a tagged branch, read its documentation entry and note `SecretReturns`, `ConditionalSecret`, `SecretWhen*`, `SecretArguments` and `NeverSecret`.
- A secret can be stored, passed on, concatenated and formatted. Comparing it, doing arithmetic on it, taking `#`, branching on a secret boolean, or using it as a table key raises a Lua error.
- Display secrets through setters tagged `SecretArguments = "AllowedWhenTainted"`, such as `StatusBar:SetValue` and `FontString:SetText`. The matching getters then return secrets too.
- Prefer curve and duration objects over maths on the raw value: `C_CurveUtil`, `C_DurationUtil`, `UnitHealthPercent(unit, usePredicted, curve)`, `StatusBar:SetTimerDuration`, `Cooldown:SetCooldownFromDurationObject`. Look up every signature, several take no constructor arguments.
- Guard logic that must branch with `issecretvalue(x)` or `canaccessvalue(x)`. `C_Secrets` answers whether a given unit, spell or aura value will be secret.
- Follow restriction state with `C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)` and the event `ADDON_RESTRICTION_STATE_CHANGED`. The types are Combat, Encounter, ChallengeMode, PvPMatch, Map and Chat.
- Force a restriction while testing with the matching CVar, such as `addonCombatRestrictionsForced`. The full list is in the `res` clone, `Resources/CVars.lua`.

## Reuse native UI

When adding UI, reach for the game's own building blocks before creating anything new.

- Reuse native, in-game UI components, templates, and frames from the game files first; only build custom ones when nothing native fits.
- Reuse native icons, textures, atlases, and other UI assets the same way.

## Deliver WeakAuras as import strings

The default deliverable for any WeakAura request is a ready `!WA:2!` string the user pastes once. Do not hand over build-this-in-the-editor instructions. If a string genuinely cannot be produced, say which precondition failed rather than falling back silently.

### Preconditions

A local WeakAuras install is **not** required. The only hard requirement is a `lua` interpreter on PATH, plus `curl` when WeakAuras is not installed. Lua 5.2 and newer work, the script shims the 5.1 globals `unpack` and `loadstring` that WoW provides.

The script resolves its sources itself, preferring a local install because that is authoritative for what the user actually runs.

| Source | Libraries | Transmission version | Version string |
|---|---|---|---|
| Local install | its own `Libs/` | `Transmission.lua` | `Init.lua` |
| GitHub fallback | upstreams pinned by the WeakAuras2 `.pkgmeta`, cached in `~/.cache/wow-addon-dev/weakauras` | `Transmission.lua` on `main` | latest release tag |

The libraries are not vendored in the WeakAuras2 repo, so remote mode pulls LibDeflate from `SafeteeWoW/LibDeflate` and LibSerialize from `rossnichols/LibSerialize` at the tag the `.pkgmeta` pins. The repo's own `versionString` is the packager placeholder `@project-version@`, which is why remote mode reads the release tag instead. That field is cosmetic anyway, the import path only reads `d`, `c` and `v`.

Local discovery only scans the macOS install path. On Windows, set `WA_PATH` to the `Interface/AddOns/WeakAuras` folder or let it fall back to GitHub.

### Workflow

1. Model the aura table on a real aura of the same `regionType` from the user's `WTF/Account/<name>/SavedVariables/WeakAuras.lua`, matching its `internalVersion` and key set. That file is the ground truth for their installed version. With no install, fall back to `Private.data_stub` in `WeakAuras/Types.lua` plus the `local default` table in `WeakAuras/RegionTypes/<Type>.lua`.
2. Write a definition file that returns the aura data table.
3. Run `lua "${CLAUDE_SKILL_DIR}/scripts/wa-import.lua" <aura-def.lua> [out.txt]`. Add `--remote` to ignore a local install, `--refresh` to bust the download cache, or set `WA_PATH` to pick one flavor when several are installed.
4. Write the string to a file the user can copy from, and print it in the reply.
5. State plainly what validation does and does not prove, and which source was used.

The script validates by decoding the finished string and compiling every custom code block. It prints the source it resolved, so check that line rather than assuming.

Re-running yields different bytes for the same aura, because Lua randomizes table iteration order. Compare decoded tables, never strings.

### What the validation is worth

It proves the string decodes and the Lua compiles. It cannot prove in-game behaviour, because there is no client to run. Say so every time.

Confidence is high for single icon, text and progress bar auras. It drops sharply for groups with children, which need a separate `c` array in the payload, for author options and config, and for conditions that reference subregions by index.

### Custom code wrappers

Validate each block under the wrapper WeakAuras actually applies, otherwise syntax checks lie.

| Field | Wrapper |
|---|---|
| `trigger.custom`, `customDuration`, `customName`, `customIcon`, `customTexture`, `customStacks` | `return <code>` |
| `trigger.customVariables` | `return function() return \n<code>\n end` |
| `actions.init/start/finish.custom` | `return function() <code>\n end` |

### WeakAuras authoring facts

Verified against an installed WeakAuras 5.21.9. Re-check against the user's version rather than trusting this list.

- A WeakAura region is not clickable. To make one act as a button, create a `SecureActionButtonTemplate` frame in custom code and anchor it over `aura_env.region`. The sandbox does not block `CreateFrame`, the blocked list covers mail, trade and macro functions.
- Bare globals resolve inside the sandbox, because its `__index` falls through to the real `_G`. Use a named frame and look it up by name to stay idempotent across aura reloads.
- `aura_env.region` is populated in custom actions. `Private.PerformActions` does not pass it, the environment resolves it itself via `WeakAuras.GetRegion(id, cloneId)`.
- Custom actions do not run while the options window is open, `Private.PerformActions` bails on `IsOptionsOpen()`. Tell the user to `/reload` after importing anything that relies on an On Show action.
- For a Trigger State Updater set `custom_type = "stateupdate"`, `check = "event"`, and a space separated `events` string. `check = "update"` swaps the whole event list for `FRAME_UPDATE` instead.
- Set `iconSource = -1` so an icon region uses `state.icon`. Stack text is a `subtext` subregion with `text_text = "%s"`.
- Name any frame the aura creates distinctly from frames a companion addon might create, so the two never fight over one name.
