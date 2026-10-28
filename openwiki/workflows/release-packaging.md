---
type: workflow
title: Release and packaging
description: How Threat Plates is released - the unified multi-client TOC, .pkgmeta for the BigWigs packager, the tag-driven GitHub workflows for release, beta, alpha and pull request test builds, versioning and the changelog hand-off.
tags: [release, packaging, toc, pkgmeta, github-actions, curseforge, versioning]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-3f44aabc99d62b052211ac8d
    resource: repo://.github/workflows/_package_release.yml
  - id: openwiki-source-b748d0b2c4a1e3826af80ff3
    resource: repo://.github/workflows/build_alpha.yml
  - id: openwiki-source-563612bb423561c57a1ff197
    resource: repo://.github/workflows/build_beta.yml
  - id: openwiki-source-ffeb728fcf9972519249e12c
    resource: repo://.github/workflows/build_pr_test.yml
  - id: openwiki-source-7a80b79a6fb3618cbfab08a2
    resource: repo://.github/workflows/build.yml
  - id: openwiki-source-e61a972950549d3aa083f4b0
    resource: repo://.github/workflows/cleanup_pr_test.yml
  - id: openwiki-source-bcb2557f5d0f407e19efbd24
    resource: repo://.pkgmeta
  - id: openwiki-source-3109d6b4b39ada7d983ff1d5
    resource: repo://TidyPlates_ThreatPlates.toc
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Release and packaging

## One TOC for every client

`TidyPlates_ThreatPlates.toc` is the only manifest. Its comma-separated `## Interface:` line (currently
`120105, 11509, 20506, 50504, 16001` - Retail, Classic Era, TBC Anniversary, Mists Classic, WoW Forever) is read
natively by all supported clients, so one package works everywhere; there are no per-client TOC files or packager
build variants. Wrath (30405) and Cata (40402) are deliberately not listed yet (comment in the TOC).

- Forever's entry is the 4th return value of `GetBuildInfo()` there and rises with every Forever patch without
  warning. If the addon shows as out of date on Forever, read the value with `/tptp version` (development build)
  and update the TOC.
- `## Version: @project-version@` is replaced by the packager; unreplaced, it marks a development build (see
  [Development workflow](development.md)).
- The TOC also declares `## SavedVariables: ThreatPlatesDB`, the addon compartment function and the
  CurseForge/WoWInterface/Wago project ids, and defines the load order (see
  [Architecture overview](../architecture/overview.md)).

## `.pkgmeta`

Configuration for the [BigWigs packager](https://github.com/BigWigsMods/packager):

- `package-as: TidyPlates_ThreatPlates`.
- `externals`: libraries pulled into `Libs/` at packaging time (LibStub, CallbackHandler, LibSharedMedia, the
  Ace3 modules, AceGUI SharedMedia widgets, LibCustomGlow, LibDeflate (latest tag), LibDualSpec).
- `embedded-libraries`: `UTF8` (ForAllIndentsAndPurposes is embedded in `Libs/` but its CurseForge slug no
  longer exists, so the entry is commented out).
- `enable-nolib-creation: no` - only the full package.
- `manual-changelog: CHANGELOG.md` (Markdown), converted for WoWInterface.
- `ignore`: `Source`, `README.md`, `CLAUDE.md`, `AGENTS.md`, `openwiki`, the IDE project file; files starting with a
  dot are excluded automatically.

## GitHub workflows

All channels call the reusable workflow `.github/workflows/_package_release.yml`, which checks out the tag,
fails if `CHANGELOG.md` lacks the `@build-time@` placeholder, replaces `@build-time@` with today's date in
`CHANGELOG.md` and the changes log, and runs `BigWigsMods/packager@v2` with `-e -l -n
"ThreatPlates-{project-version}"`. Where the package is published depends on which secrets the caller forwards:

| Workflow | Trigger | Published to |
| --- | --- | --- |
| `build.yml` | tag `X.Y.Z` (no `-alpha`/`-beta`) or manual | CurseForge, WoWInterface, Wago, GitHub |
| `build_beta.yml` | tag containing `-beta` or manual | CurseForge, Wago, GitHub (not WoWInterface) |
| `build_alpha.yml` | tag containing `-alpha` or manual | GitHub only |
| `build_pr_test.yml` | `/buildtest` comment on a pull request by an owner/member/collaborator, or manual | GitHub only, as prerelease `pr<N>-test<run>`, linked in a pull request comment |
| `cleanup_pr_test.yml` | pull request closed | deletes that pull request's test tags and releases |

The pull request test tag deliberately contains neither `alpha` nor `beta`, so it does not also trigger the alpha
or beta workflow; prerelease is set explicitly instead.

Localization has its own workflows (see [Localization pipeline](localization.md)); the localization publish
step to CurseForge runs on `main` only.

## Versions and release flow

- Version numbers: major = WoW expansion (13 = Midnight), minor = new functionality, patch = bug fixes; test
  builds use `-alphaN` / `-betaN` suffixes.
- Branches: work on `feature/*` / `hotfix/*`, integrate on `develop`, prepare on `release/<major.minor>`,
  release from `main` by pushing a version tag.
- Before tagging, `CHANGELOG.md` must contain exactly the entries of the top (unreleased) block of
  `TidyPlates_ThreatPlates_Changes.log`, under `# @project-version@ (@build-time@)`; see the changelog rules in
  [Development workflow](development.md#changelog).
