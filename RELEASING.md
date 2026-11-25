# Releasing

GitHub Actions can be unavailable (the hosted runners don't start). Then
checks and releases run on a maintainer's machine. This file is the local flow.
When Actions run again, `validate.yml` and `release.yml` do the same work.

## Checks before every push

```bash
git config core.hooksPath .githooks   # once per clone
```

Every `git push` then runs `scripts/validate.sh`: plugin manifest, JSON,
shellcheck, AGENTS.md against CLAUDE.md, and the hook tests. It needs `jq` and
`shellcheck`. Run it by hand with `bash scripts/validate.sh`.

`validate.yml` runs the same checks on a self-hosted runner (label
`claudevideokit-public`). This repo is public, so fork pull requests must not
reach it: the jobs skip PRs from forks, and the repo setting "Require approval
for all external contributors" must stay on, because a fork PR can edit the
workflow itself. Check fork PRs by hand and run `scripts/validate.sh` locally.
`release.yml` stays on GitHub-hosted runners; while they are down, use the
local release flow below.

## Cut a release

Commits on main follow Conventional Commits (`feat:`, `fix:`, `chore:`...).
`feat` and `fix` commits make a release; `chore` alone does not.

### A. release-please CLI (preferred)

The CLI talks to the GitHub API and needs no runner. It writes the same release
PR and CHANGELOG the workflow writes.

```bash
npx release-please@17 release-pr --token="$(gh auth token)" \
  --repo-url=tansuasici/claude-video-kit --target-branch=main \
  --config-file=release-please-config.json --manifest-file=.release-please-manifest.json
```

Add `--dry-run` to see what it would do. Review the release PR it opens and
squash-merge it. Then tag main and create the GitHub release:

```bash
git checkout main && git pull
npx release-please@17 github-release --token="$(gh auth token)" \
  --repo-url=tansuasici/claude-video-kit --target-branch=main \
  --config-file=release-please-config.json --manifest-file=.release-please-manifest.json
```

### B. By hand

1. On a branch, set the version everywhere it is written:
   `bash scripts/set-version.sh 0.2.0` (VERSION, package.json, plugin.json,
   marketplace.json, the release-please manifest).
2. Add a `## 0.2.0 (YYYY-MM-DD)` section to the top of `CHANGELOG.md`, in the
   format of the sections below it.
3. Open a PR named `chore(main): release 0.2.0` and squash-merge it.
4. Tag main and create the release:
   ```bash
   git checkout main && git pull
   git tag v0.2.0 && git push origin v0.2.0
   gh release create v0.2.0 --title v0.2.0 --notes "See CHANGELOG.md"
   ```

## Publish to npm

From a clean main at the release commit:

```bash
npm whoami
npm publish --access public
```

npm asks for approval in the browser. Check the result with
`npm view @tansuasici/claude-video-kit version`.

## Docs site

The site reads this repo's VERSION and CHANGELOG at build time, so redeploy it
after a release. The steps are in the site's own repository.
