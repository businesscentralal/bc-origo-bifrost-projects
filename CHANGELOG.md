# Changelog

## Unreleased

### Changed (2026-10-21) - Object range moved into a registered range

- The app range moves from 10078485-10078584 (outside every registered Origo range) to 70009200-70009249, Origo Public 3 (Gunnar 21.10.2026). Main had no objects yet, so nothing is renumbered here; the scaffold branch is renumbered separately. Test range 97100-97199 is unchanged.

## 28.1.0.0 - Unreleased

- Repository scaffold from the Bifrost feature-app template (AL-Go, Alpaca shared container, Bifrost pipeline guards).
- Object ranges: app 70009200..70009249, tests 97100..97199.
- Template alignment with the Bifrost feature-app template: the workflow set, .gitattributes, the Icelandic translation file, and docs. PullRequestHandler.yaml skips the pull-request build when app/ and test/ contain no .al files. SourceGuards.yaml records NoClientCallstack, PermissionCoverage, ValidatedTableView, and IcelandicKeywordCounts as not applicable on a tip with no app code, and those checks gate again once app source exists.
- app.json sets applicationInsightsConnectionString the same way as Bifrost Inventory, so AppSourceCop AS0092 is satisfied.
