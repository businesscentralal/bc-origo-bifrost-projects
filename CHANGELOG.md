# Changelog

## 28.1.0.0 - Unreleased

- Repository scaffold from the Bifrost feature-app template (AL-Go, Alpaca shared container, Bifrost pipeline guards).
- Object ranges: app 10078485..10078584, tests 97100..97199.
- Template alignment with the Bifrost feature-app template: the workflow set, .gitattributes, the Icelandic translation file, and docs. app/src/.gitkeep retains the source directory. Removal of the empty-source workflow skips and the first executable Projects registration remain pending under PR #10 D1.
- app.json sets applicationInsightsConnectionString the same way as Bifrost Inventory, so AppSourceCop AS0092 is satisfied.
