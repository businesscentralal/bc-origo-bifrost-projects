# Changelog

## 28.1.0.0 - Unreleased

- Repository scaffold from the Bifrost feature-app template (AL-Go, Alpaca shared container, Bifrost pipeline guards).
- Object ranges: app 70009200..70009249 (Origo Public 3; moved 21.10.2026 from 10078485..10078584, which is outside every registered Origo range), tests 97100..97199.
- Template alignment with the Bifrost feature-app template: the workflow set, .gitattributes, the Icelandic translation file, and docs. PullRequestHandler.yaml skips the pull-request build when app/ and test/ contain no .al files. SourceGuards.yaml records NoClientCallstack, PermissionCoverage, ValidatedTableView, and IcelandicKeywordCounts as not applicable on a tip with no app code, and those checks gate again once app source exists.
- app.json sets applicationInsightsConnectionString the same way as Bifrost Inventory, so AppSourceCop AS0092 is satisfied.
