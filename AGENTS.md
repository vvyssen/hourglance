# Hourglance · 一瞥

Swift sources in `Sources/`, no Xcode project. `./build.sh` builds the universal `build/Hourglance.app` with only the Command Line Tools. `Info.plist` holds the version (`CFBundleShortVersionString`). The icons are drawn in code by `Icon/make-icon.swift` (`Icon/build-icons.sh`), and they have to match how the clock really looks.

Keep `README.md` and `README.zh-CN.md` in sync when you change one.

## Releasing

A release is a `vX.Y.Z` tag on `main`. Pushing the tag runs `.github/workflows/release.yml`, which builds the app on a GitHub macOS runner, zips it, and publishes the GitHub release with the tag message as its notes. Don't build or upload the release by hand.

```sh
scripts/release.sh status                 # version, last tag, commits since then
scripts/release.sh patch --yes -F notes.md   # or minor / major / X.Y.Z; -m "…" for short notes
gh run watch "$(gh run list -w release -L1 --json databaseId -q '.[0].databaseId')"
gh release view vX.Y.Z
```

The script refuses to run unless you're on `main`, the tracked tree is clean, and `main` isn't behind `origin`. It bumps `Info.plist` (version + build number), runs `./build.sh` as a preflight, commits `Release vX.Y.Z`, makes an annotated tag, and pushes both.

**When to release (agents can decide this themselves):**
- Release when `status` shows user-visible changes (features, fixes, settings, icon) that are committed, build cleanly, and have been tried in the running app. Don't release in the middle of a change, or for refactors, docs, or CI-only changes.
- Versions: `patch` for fixes, `minor` for new features or settings, `major` only if the user asks.
- Notes: write them for users, in English and then Chinese, one line per change. Don't paste commit subjects. Then tell the user the version and the release link.
- If the workflow fails, fix it on `main`, then re-run it for the same tag: `gh workflow run release -f tag=vX.Y.Z`. Only make a new patch release if the app itself needs a fix.

The app is ad-hoc signed and not notarized (there's no Developer ID), so users have to click through Gatekeeper on first launch. The workflow's release notes explain how.
