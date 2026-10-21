# Changelog

## 28.1.0.0 - Unreleased

### Changed (2026-10-21) - Object range moved into a registered range

- Integrate the approved workflow restoration from main and retain one telemetry manifest property. Add a late nested-update failure regression (97101) to prove the existing project header and earlier nested task insert roll back together (#2).

- Every app object, Message Type enum value and range reference moves from 10078485-10078584 (outside every registered Origo range) to 70009200-70009249, Origo Public 3 (Gunnar 21.10.2026). The mapping is a fixed offset: old ID + 59930715, so 10078485 becomes 70009200. The objects use 70009200-70009229. Tests that check the range now use 70009200-70009249. Test object IDs 97100-97199 are unchanged.

- Fix Claude #17 D1-D3: complete public parameter help (70009204), correct Icelandic
  discovery/help and posting-rights caption, and return localized RecordNotFound for
  unknown BudgetVsActual task (70009226). Add recursive help and bilingual/task-isolation
  regressions (97100, 97108).

- Add Projects company enablement, administrative page, Foundation app registration,
  permission-set extensions and generic setup-write protection (#1; objects 70009200–70009203).
- Register project/task/planning-line create and update, plus planning-line delete,
  with localized discovery and typed nested contracts (#2; enum 70009200, codeunits
  70009204–70009214). Use native field/table triggers and atomic rollback on failure.
- Teach the inherited permission coverage guard to resolve feature extensions of known
  Foundation roles, retaining source-table checks and adding negative self-tests.
- Add native Copy Job options and validated status/blocking messages (#3/#4;
  codeunits 70009215–70009216, enum values 70009207–70009208; tests 97104–97105).
- Preserve temporary test argument blobs before public Foundation reads; scope
  catalogue tests to this app's assigned enum range. Support explicit nested
  Update operations and inherit planning-line task keys from their parent.
- Add WIP Get and native Calculate contracts (#5 partial; codeunits 70009217,
  70009218 and 70009220; enum values 70009209–70009210; test codeunit 97106).
  Add WIP Post with a Projects-owned internal permission token/gate mapped to
  Projects Read/Full extensions (#5/#18; objects 70009219, 70009221–70009222;
  tests 97106–97107). Add nonzero native WIP calculation/posting and gate tests.
- Add native Statistics and BudgetVsActual contracts (#6; objects 70009224–70009226;
  enum values 70009212–70009213; tests 97108). Return LCY cost/price totals and
  type splits using the BC statistics engine, with posting-task breakdown.
- Add Usage Get/Link with exact project/task and identity checks, duplicate-link refusal,
  native remaining-quantity updates and planning-from-usage (#8; objects
  70009227–70009229, enum values 70009214–70009215; tests 97109).
- Add owned native Web Client fixture helpers in the test app only (97110–97111);
  keep shipping licensing and MCP evidence separate.
- Add scaffold, permission, input-boundary and native write component tests
  (test codeunits 97100–97106). Runtime/UI/MCP and independent verification remain pending.

- Repository scaffold from the Bifrost feature-app template (AL-Go, Alpaca shared container, Bifrost pipeline guards).
- Object ranges: app 70009200..70009249, tests 97100..97199.
- Object ranges: app 10078485..10078584, tests 97100..97199.
- Template alignment with the Bifrost feature-app template: the workflow set, .gitattributes, the Icelandic translation file, and docs. PullRequestHandler.yaml skips the pull-request build when app/ and test/ contain no .al files. SourceGuards.yaml records NoClientCallstack, PermissionCoverage, ValidatedTableView, and IcelandicKeywordCounts as not applicable on a tip with no app code, and those checks gate again once app source exists.
- app.json sets applicationInsightsConnectionString the same way as Bifrost Inventory, so AppSourceCop AS0092 is satisfied.
