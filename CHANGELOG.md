# Changelog

## [28.1.0.0] - 2026-11-14 (Unreleased)

- Projects #12: keep all allocation planning filters loaded (codeunit 70009235) and verify positive resource-group filtering (test codeunit 97120).
- Projects #12 verification repair: usage test fixtures choose ledger numbers not already referenced by native usage links, preserving existing rows on reused tenants; regression coverage in test codeunit 97109.

### Added (2026-10-21)

- Add `Projects.ResourceAllocation.Get` for native calendar-period capacity, scheduled open-project allocations and availability, with exact selectors, a 53-period limit and localized refusal/help contracts (#12; codeunits 70009230, 70009235, 70009238; enum value 70009216; tests 97120/97121 and owned nonfinancial fixture actions 97128).

### Changed (2026-11-10)

- Integrate allocation #12 with the approved removal of PlanningLine.Delete and native WIP fixture updates; keep exact coverage of the sixteen remaining registered types (enum 70009200; tests 97100/97103).

### Added (2026-11-14)

- Merge main into the #12 allocation branch: object ID clash on codeunit 70009231 (`Proj. Purchase Impl ori` from main vs `Projects Allocation ori`); the allocation side moved to the next free ID 70009235. Enum value count is now 21 registered types (tests 97100/97103).
- Resolve the #11/#16 merge codeunit clashes: move `Proj. Purchase Impl ori` from 70009241 to unused 70009231 and `Proj. Item Usage Impl ori` from 70009242 to unused 70009234; retain main's WIP method IDs. Keep all 20 message registrations and the exact bilingual catalogue assertion.

- Add `Projects.WIPMethod.Get` and `Projects.WIPMethod.Set` (#16): list native recognized cost/sales settings and create or partially update custom WIP methods. System-defined methods and methods with calculated or posted WIP history return `PreconditionFailed` with translated recovery guidance. Native validation refusals translate their summary and retain the original diagnostic in `nativeError`.
- Add codeunits 70009240–70009243, enum values 70009240–70009241 and test codeunit 97116. Sync Icelandic discovery and refusal XLF entries; contract chapters stay English in every locale.

- Remove duplicate telemetry manifest key introduced by merging main; restore product/test compilation for Projects purchase linking and item usage (#11).
- Merge current main and keep `Projects.PlanningLine.Delete` removed (Gunnar decision d-20261105-delete-types). Register `Projects.PurchaseLine.Link` and `Projects.ItemUsage.Post` (enum values 70009219–70009220; codeunits 70009230, 70009232, 70009233, 70009237, 70009241, 70009242, 70009244, 70009245, 70009247; tests 97124, 97125, 97129–97132) on that scaffold (#11).

### Changed (2026-10-21) - Object range moved into a registered range
### Added (2026-11-14)

- `Projects.Quote.Send` (#15): sends the quote of a project in status Quote to its bill-to customer through a Document Sending Profile (request, customer, then Default), as the Send Project Quote action does. Refuses a project not in status Quote, a missing bill-to customer, an unknown profile and profiles that need a client (Disk, e-mail prompt) or have no customer e-mail address, each with a coded error and `nextStep` in en-US and is-IS. New objects: enum value 70009222, codeunits 70009248 "Proj. Quote Send Impl ori" and 70009249 "Proj. Quote Send Process ori" (granted in the Projects Read/Full extensions); test codeunit 97140 "Projects Quote Send Tests ori", and an MCP fixture for the worker-owned tenant (codeunit 97141 / page 97141 "Proj. Quote Send Fixture ori": customers, quote and open projects, a profile without channels and a Disk profile; removed afterwards with Test.Records.Delete). The scaffold catalogue test (97100) now counts sixteen types. These IDs move with the range change of #34.
### Tests (2026-11-10) — Project status validation

- Projects #4: codeunit 97105 now verifies native completion date errors and atomic rollback, plus rejection of invalid blocking values before a status change.

### Fixed (2026-11-10)

- Codeunits 70009201 "Projects Registration ori" and 70009203 "Projects Setup Restrict ori" declare `InherentPermissions = X` and `InherentEntitlements = X`, so Foundation's `OnRegisterApps` and the table-write-restriction event no longer fail for users without a Projects role (#31). Regression test in codeunit 97100.

### Issue #3 copy acceptance (2026-11-04)

- Complete copy option and rollback coverage for native Copy Job (70009214–70009215, tests97104/97113): inclusive task selection, Budget/Billable filtering, prices, quantities, dimensions, reversed ranges, customer validation and restricted-role denial.
- Clarify the README copy contract and use a descriptive response-field variable in the copy adapter; no public contract removed.
### Tests (2026-11-09)

- Make WIP tests (97106) create and remove their own blank-No. Job default dimension, independent of CRONUS demo data (#29).

### Tests (2026-11-10)

- Codeunit 97102 creates its own blank-number Job dimension when the company has none, so codeunit 97106 economic WIP tests do not depend on CRONUS demo data. The mandatory default-dimension row is removed after the scenario.

### Removed (2026-11-10)

- Remove the unreleased message type `Projects.PlanningLine.Delete` (enum value 70009206, codeunit 70009211) per Gunnar decision d-20261105-delete-types. `Projects.PlanningLine.Create` and `Projects.PlanningLine.Update` stay.

### Changed (2026-11-04)

- Use a descriptive response-field variable in the seven issue #2 message adapters (70009205–70009211); the public contracts and behavior are unchanged.

### Tests (2026-11-04)

- Add an isolated issue #2 write-fixture page (97112) for customer/resource/item/G/L queue and bilingual Web Client acceptance; no consent or licence writes.

### Changed (2026-10-21) - Object range moved into a registered range

- Reconcile the WIP posting contract with the resolved Projects Read/Full decision (#18) and distinguish the historical Foundation EULA refusal from current-version queue verification (#17).
- Add idempotent, language-isolated MCP fixture actions to the test app (97110/97111) for unposted economic WIP and unlinked usage; seeding leaves posting to the actual queue calls and writes no consent or licence state.
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

### Purchase links and item usage (verification candidate)

- Create compatible owned VAT and general posting setup for localized purchase MCP fixtures (97131), with a native inventory/purchase fixture regression (97124).
- Add native purchase line linking and atomic project item usage posting with strict selectors, tracking-key isolation and exact native ledger capture (codeunits 70009230, 70009232, 70009233, 70009237, 70009241, 70009242, 70009244, 70009245, 70009247). Add native posting, transaction/refusal and permission regressions 97124, 97125 and 97129, with in-memory native rollback observation helper 97130. Register both types as enum values 70009219–70009220 and grant owned executable objects through the existing Read/Full extensions; native write rights remain caller-owned. Verify dedicated-field refusals through the supported Foundation dispatcher rather than an unlicensed direct implementation call. Add a disposable-container test fixture seeder/page (97131–97132) for native tracked stock and purchase data. Shipping full-suite/UI/MCP acceptance remains pending.
- Object ranges: app 10078485..10078584, tests 97100..97199.
- Object ranges: app 70009200..70009249 (Origo Public 3; moved 21.10.2026 from 10078485..10078584, which is outside every registered Origo range), tests 97100..97199.
- Template alignment with the Bifrost feature-app template: the workflow set, .gitattributes, the Icelandic translation file, and docs. PullRequestHandler.yaml skips the pull-request build when app/ and test/ contain no .al files. SourceGuards.yaml records NoClientCallstack, PermissionCoverage, ValidatedTableView, and IcelandicKeywordCounts as not applicable on a tip with no app code, and those checks gate again once app source exists.
- app.json sets applicationInsightsConnectionString the same way as Bifrost Inventory, so AppSourceCop AS0092 is satisfied.
