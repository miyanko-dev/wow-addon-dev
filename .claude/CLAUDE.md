# wow-addon-dev

## Rules

- One repo is the plugin, its marketplace (`source: "./"`) and the Agent Skill in `skills/wow-addon-dev/`, all named `wow-addon-dev`.
- Lookups use shallow per-branch clones from `skills/wow-addon-dev/scripts/wow-source.sh`, not GitHub MCP. MCP returns whole files and needs a token, and GitHub code search only indexes `live`.
- Add no `userConfig`. A public clone must work without a secret.
- Hard-code no interface numbers or builds in the skill. They change every patch, so the skill reads them from the branch.

## Checks

- `claude plugin validate --strict .` checks the marketplace and `claude plugin validate --strict .claude-plugin/plugin.json` the plugin. Fix every warning.
- `npx skills add . --list` confirms that other agents find the skill.
- The Validate workflow runs the same three on every push to `main` and every pull request.

## Release

1. Bump `version` in `.claude-plugin/plugin.json`, or installed copies never update.
2. Run the checks and fix every warning.
3. Add the changes to `CHANGELOG.md`.
4. Push and wait for the Validate workflow to pass.
5. Tag `vX.Y.Z` and create a GitHub release.
