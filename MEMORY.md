# wow-dev memory

Updated 2026-10-05. Packaged as a Claude Code plugin plus Agent Skill and published as `miyanko-dev/wow-dev`. 1.0.1 renamed the marketplace from `miyanko-dev` to `wow-dev`, matching the single-plugin repo convention.

## Decisions

| Decision | Reason |
|---|---|
| One repo is plugin, marketplace (`source: "./"`) and Agent Skill (`skills/wow-dev/`) | One install path for Claude Code, `npx skills add` for other agents |
| Lookups use shallow per-branch clones via `scripts/wow-source.sh`, not GitHub MCP | GitHub code search only indexes `live`, MCP returns whole files, MCP needs a token |
| No bundled MCP server, no `userConfig` | Public clones need no secret |
| No hard-coded interface numbers or builds | They change every patch, the skill reads them from the branch |

## Verified on 2026-10-05

- Secret value tags exist on `live` (12.1.0) and `forever` (1.60.1). `classic`, `classic_era` and `classic_anniversary` have the helpers but zero tagged APIs.
- `classic_anniversary` is 2.5.6, so its WeakAuras TOC is `_TBC`, not `_Vanilla`.

## Release checklist

1. Bump `version` in `.claude-plugin/plugin.json`, or installed copies never update.
2. Run `claude plugin validate --strict .` and fix every warning.
3. Add the changes to `CHANGELOG.md`.
4. Push, wait for the Validate workflow to pass, then tag `vX.Y.Z` and create a GitHub release.
