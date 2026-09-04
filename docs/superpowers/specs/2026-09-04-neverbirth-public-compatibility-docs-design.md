# Neverbirth public compatibility documentation release design

Date: 2026-09-04
Status: approved

## Goal

Promote the existing playable update to Neverbirth's default GitHub branch, then publish an English and Simplified Chinese guide for the two compatibility hooks in that update. The guide must tell another Isaac mod author what each hook does, how to call it safely, and what Neverbirth does not promise.

## Locked decisions

- The public guide covers two integrations: Fortune Rivalling Heaven Gu luck thresholds and Dice Set custom dice active items.
- The release uses `origin/multiple-language-support` commit `fcd6a8e` as its gameplay and API base. This is the existing playable update that contains both public hooks.
- The current default branch commit `7350157` is an ancestor of `fcd6a8e`. Publishing this release intentionally promotes the complete playable update, rather than cherry-picking isolated compatibility functions into the older default branch.
- Memory Disorder is not a public integration in this release. The detailed profile chapter, API status row, sample code, implementation link, and test link will be removed. A short note will state that the published version does not expose a Memory Disorder compatibility API.
- `memory_disorder.lua` and `tests/memory_disorder_behavior_test.lua` remain outside this release. This work does not add, publish, or modify them.
- Both language versions will have the same section order, API status, examples, limitations, and maintainer checks.
- The documents belong to Neverbirth. They remain at the repository root as `COMPATIBILITY.md` and `COMPATIBILITY.zh-CN.md`.
- The completed documents will be merged into the default `main` branch.
- `README.md` will link to both language versions with relative repository links, so the links resolve on the default branch rather than a temporary work branch.

## Approaches considered

### Publish all three integrations

This would require publishing and loading the Memory Disorder module and its tests. It was rejected because the user selected the option that keeps this interface out of the public release.

### Promote the playable update and publish its two interfaces

This is the selected approach. It makes the default branch match the playable code that already contains both documented interfaces and avoids advertising a function that exists only on a non-default branch.

### Split provisional and stable APIs into separate guides

This would make the stability boundary explicit, but two short public APIs do not justify another document. A status table and a maintainer appendix are enough for this release.

## Document structure

The English and Chinese guides will use the same structure:

1. What another mod can integrate
2. Terms used in the guide
3. API status and stability
4. Finding Neverbirth and using runtime IDs
5. Load-order pattern
6. Fortune Rivalling Heaven Gu
7. Dice Set
8. Interfaces that are not public
9. Maintainer appendix

The opening table will replace the duplicated introductory list and status table.

## Wording rules

- Explain the player-facing result before introducing function names.
- Define `Luck threshold`, `active item`, and `dice-themed active item` in both languages.
- State that a Luck threshold reaches an effect's highest possible activation chance, which may be below 100%.
- Describe Dice Set progress as collecting, holding, or using a recognized dice item. Do not say that merely seeing a pedestal counts.
- In Chinese, prefer plain phrases such as `可接入功能`, `要调用的函数或表`, and `允许被选择的角色列表` over internal terms such as `兼容表面`, `目标能力`, and `候选池`.
- Use a neutral technical voice. Avoid promotional text, title-case English headings, rhetorical introductions, and undefined contract language.

## Examples and API boundaries

- Examples assume the calling mod already has its own `MyMod` object. They will explicitly warn authors not to call `RegisterMod` again.
- Each registration attempt will remain idempotent and will retry once from the caller's `MC_POST_GAME_STARTED` callback when Neverbirth loads later.
- The Fortune section will preserve the fixed and resolver examples, numeric validation, duplicate-registration warning, and hot-path restrictions.
- The Dice section will state that `options` must be a table or `nil`. It will explain that only `protectStats = false` disables stat protection.
- Automatic name-based dice detection will remain documented as a fallback, not the preferred integration.
- EID will remain optional, and the guide will not imply that EID is required for core behavior.

## Stability language

The guide will call the two hooks provisional and unversioned rather than presenting an undefined public contract version. It will state what authors may rely on in the current release and direct them to check the exact function they need.

The guide will not claim that an `API_VERSION`, `Neverbirth.Compat` namespace, or ready callback exists. It will also remove the contradictory statement about updating a compatibility version that does not exist.

## README and publication

`README.md` will receive a small compatibility section with two relative links:

- `COMPATIBILITY.md`
- `COMPATIBILITY.zh-CN.md`

The release branch will be rebased onto the clean remote commit `origin/multiple-language-support` at `fcd6a8e`, not onto the dirty local checkout. After verification, the release branch will fast-forward the remote `main` branch. It will not include the later local-only commits or uncommitted changes from the dirty `multiple-language-support` checkout.

## Verification

Before merging:

- Confirm `origin/main` is an ancestor of the selected playable update and that the release branch contains `fcd6a8e`.
- Confirm the release tree contains all four Fortune registration functions and `RegisterDiceItem` before publishing their documentation.
- Confirm both documents contain the same ordered sections and the same executable Lua examples.
- Confirm every relative Markdown link exists in the release tree.
- Confirm neither guide advertises `MemoryDisorderCharacterProfiles` or links to absent Memory Disorder files.
- Confirm the Chinese guide contains no `满概率`, `兼容表面`, `目标能力`, `候选池`, or `见过或使用过` wording.
- Confirm the English guide does not use `seen or used` for Dice Set progress.
- Confirm the examples do not call `RegisterMod`.
- Confirm README contains both relative compatibility links.
- Run all existing Lua tests from the promoted playable update in the clean release worktree.
- Run `git diff --check` and review the exact diff before committing.
- After merging, repeat the tests and link checks on the merged `main` result before pushing.

This is static repository verification. It does not replace an in-game two-mod load-order test.

## Out of scope

- Publishing or repairing the Memory Disorder integration
- Changing gameplay mechanics or balance values
- Adding a compatibility namespace or API version to Lua
- Changing EID behavior
- Modifying XML, resources, localization XML, or the user's unrelated working-tree changes
- Reworking or selectively extracting gameplay changes already contained in the approved `fcd6a8e` playable update
