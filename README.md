# Bifrost Projects

| App ID | App object range | Test object range | Target |
| --- | --- | --- | --- |
| `c847bab7-2525-4ff5-93c4-15512b3be1e5` | 70013500..70013599 | 97100..97199 | Business Central 28 or later, Cloud extension |

## Overview

Bifrost feature app for project (job) message types that are not covered by Bifrost Foundation: project lifecycle, tasks and planning lines, copy, status, prices, WIP, budget vs actual, project invoicing helpers and project queries. Message types use the `Projects.*.*` pattern.

Native time sheets belong to **Bifrost Projects**: create, submit, approve, reject, reopen, post and archive sheets, create lines from planning or a previous sheet, list pending approvals and register absence. The Clockify sync and Phone Role Center remain in **Bifrost Timesheets** (businesscentralal/bc-origo-bifrost-timesheets). Project journal and project-to-sales-invoice/credit-memo types live in **Bifrost Foundation**.

- Depends only on Bifrost Foundation.
- Object range: 70013400..70013599 (Projects app, Public 4), 97100..97199 (tests).

## Functional flow

1. Discover a type with `Help.MessageTypes.Get`, then read its contract through `Help.Implementation.Get`.
2. Send version `1.0` and a JSON object in `data`; `subject` is not used.
3. Read the native result or follow the typed refusal's recovery guidance.

### Message types

| Type | Data | Result |
| --- | --- | --- |
| `Projects.Visit.Start` | `projectNo`, `taskNo`, `kind` (`travel` or `work`), optional `at`, `autoStop`, `clientRequestId` | Opens one running visit. `autoStop` first adds the running visit's rounded hours. |
| `Projects.Visit.Stop` | optional `visitId`, `at`, `note`, `clientRequestId` | Stops the running visit and adds the rounded hours to an open job line. |
| `Projects.Visit.Complete` | `visitId` or `projectNo`+`taskNo`, optional `mileageKm`, `outcome`, `clientRequestId` | Marks the visit completed. Kilometres become an open usage line and nothing is submitted. |
| `Projects.Project.Create` | `projectNo`, optional fields, `tasks[]` | Creates a project and optional nested tasks/planning lines atomically. |
| `Projects.Project.Update` | `projectNo`, changed fields, optional `tasks[]` | Updates supplied fields; nested records explicitly create or update. |
| `Projects.Task.Create` | `projectNo`, `taskNo`, fields, `planningLines[]` | Creates a task and optional planning lines. |
| `Projects.Task.Update` | `projectNo`, `taskNo`, changed fields, optional `planningLines[]` | Updates a task; preserves omitted fields. |
| `Projects.PlanningLine.Create` | `projectNo`, `taskNo`, positive `lineNo`, fields | Creates a native resource, item, G/L account or text planning line. |
| `Projects.PlanningLine.Update` | `projectNo`, `taskNo`, `lineNo`, changed fields | Updates supplied native fields. |
| `Projects.PurchaseLine.Link` | purchase line (`systemId` or `documentType`+`documentNo`+`lineNo`), `projectNo`, `taskNo`, optional `lineType`, `planningLineNo` | Links an unreceived, uninvoiced purchase line to an open project task. Repeating the same link returns `changed: false`. |
| `Projects.ItemUsage.Post` | `projectNo`, `taskNo`, `lines[]` | Posts item usage through the project journal and returns the project ledger entry range. |
| `Projects.Usage.Get` | `projectNo`, `taskNo` | Native usage links and planning-line remaining quantities. |
| `Projects.Usage.Link` | `projectNo`, `taskNo`, `entryNo`, `lineNo` or `createPlanningLine: true` | Applies usage through native BC or transfers usage to planning lines. |
| `Projects.WIP.Get` | `projectNo` | Reads calculated and posted WIP entries. |
| `Projects.WIP.Post` | `projectNo`, `postingDate`, `documentNo` | Posts calculated WIP through native BC and the Projects Full permission gate. |
| `Projects.Statistics.Get` | `projectNo` | LCY budget/actual/billable/invoiced cost and price by resource/item/G/L and total. |
| `Projects.BudgetVsActual.Get` | `projectNo`, optional exact `taskNo` | Project totals plus posting-task detail; total/heading tasks excluded. |
| `Projects.WIP.Calculate` | `projectNo`, `postingDate`, `documentNo` | Runs native WIP calculation and returns entry state. |
| `Projects.Project.Copy` | `projectNo`, `targetProjectNo`, copy options | Runs native Copy Job with a selected task range. |
| `Projects.Report.Get` | `report`, `format`, project/task/date/register filters | Returns typed standard report rows or a base64 PDF. |
| `Projects.Project.Copy` | `projectNo`, `targetProjectNo`, copy options | Runs native Copy Job with an inclusive task range; optional Budget/Billable filtering, prices, quantities and dimensions. The target must be new; validation errors roll back the copy. |
| `Projects.Project.SetStatus` | `projectNo`, `status` and/or `blocked` | Validates native status, completion and blocking. |
| `Projects.Project.Archive` | `projectNo`, optional `description` | Creates a native archived project version (requires Projects Full and Archive Projects in Jobs Setup). |
| `Projects.ProjectArchive.Get` | `projectNo`, optional `versionNo` | Lists archived versions or reads one version with tasks and planning lines. |
| `Projects.Quote.Send` | `projectNo`, optional `documentSendingProfile` | Sends the quote of a project in status Quote to its bill-to customer through a Document Sending Profile, as the Send Project Quote action does. Irreversible. |
| `Projects.ItemCost.Update` | `projectNos[]` or `allOpen`, optional `postingDateFrom`/`postingDateTo`, `expectedCount` | Brings the item cost on project usage entries and planning lines up to the adjusted item cost (the Update Project Item Cost batch job). Irreversible; `expectedCount` counts the projects in scope. |

| `Projects.ResourceAllocation.Get` | `periodType`, `fromDate`, `toDate`; optional project/resource/group selectors | Resource capacity, per-project allocation and availability by period. |
| `Projects.WIPMethod.Get` | Optional exact `code`; `{}` lists all | Reads native WIP methods, recognized settings and flags. |
| `Projects.WIPMethod.Set` | Required `code`, optional recognized settings, flags and description | Creates or partially updates a custom method; refuses system-defined methods and methods used by WIP history. |


## Benefits

- Create related project, task and planning-line records in one transaction.
- Use native BC validation for project changes, WIP calculation and posting.
- Read stable recognized cost/sales enum names in either English or Icelandic sessions.

## Task indentation

Call `Projects.Task.Indent` with `{"projectNo":"PROJECT-001"}` after creating or updating the task structure. It runs Indent Project Tasks without confirmation, overwriting indentation on every task and totaling on End-Total tasks. `tasks[]` returns taskNo, taskType (English name), indentation, totaling and changed; `summary` returns taskCount and changedCount. A second call reports zero changed tasks. Unmatched End-Total tasks and nesting beyond ten levels return PreconditionFailed with the native reason and roll back every change. Unknown projects, invalid input and permission refusals are typed and include a next step. The caller needs BIFROST Full ori and native project-task write rights. No Create contracts or UI pages change.

## Logic flow

`Company switch and native permissions → Foundation licence/version checks → request validation → native transaction → response`

Write failures roll back the native transaction. Native WIP method validation failures include a translated summary and preserve the original platform diagnostic in `nativeError`. WIP method Set preserves omitted fields and refuses system-defined methods or methods referenced by calculated or posted WIP, including reversed posted history.

## Setup and configuration

Calls require the native BC table permissions in addition to the Foundation role. WIP posting also requires the Projects Full role extension (via `BIFROST Full ori`); Projects Read does not grant posting. Projects Setup is a company-wide switch; generic `Data.Records.Set` cannot change it.

The time-sheet message types (`Projects.TimeSheet.*`, `Projects.TimeSheetLine.*`, `Projects.Absence.Register`, `Projects.PendingApproval.Get`) need `BIFROST Full ori` together with the assignable set `PROJ TS ADMIN`, which grants the Base Application time-sheet, resource, employee, absence, project journal and number series data. `BIFROST Full ori` alone is refused with `PermissionDenied` and the next step "Assign the BIFROST Full ori and PROJ TS ADMIN permission sets." `Projects.PendingApproval.Get` only reads: `BIFROST Read ori` or `BIFROST Full ori` together with `PROJ TS ADMIN` is enough.

Technicians use `BIFROST Read ori` + `PROJ FIELD TECH` for `Projects.MyDay.Get`, `Projects.VisitBrief.Get` and their own `Projects.Usage.Register/Submit/List`. `PROJ FIELD TECH` includes `PROJ TS SELF`, adds read-only project planning/site/stock data and RIM on this app's usage lines, and grants no journal data or project/task/planning writes. `PROJ USAGE` is unchanged for approvers and back office, together with `BIFROST Full ori` (`BIFROST Read ori` suffices for List). Refusals name the appropriate sets. The Team Member SaaS entitlement/Effective Permissions receipt is NOT_RUN until the dedicated test user exists (23 November 2026, issue #82).

`Projects.MyDay.Get` defaults to today and returns each owned Resource planning line in planning-date/task/line order, with project number breaking ties. `include` accepts `items` and `address` (default: address). `Projects.VisitBrief.Get` requires projectNo/taskNo; both accept resourceNo to choose among multiple owned resources. Hours use native resource quantities, so resources should use hours as their unit. Day time is restricted to the requested date; brief time covers the task across all own sheets. Site data is the project's native ship-to snapshot. Missing sheets/task lines return ready-made `nextSteps` without writes. Brief `recordIds` allows assistants to use other apps; Projects reads no attachments and depends on no feature app. `history` and `followUps` remain empty pending #83/#87.


`PROJ TS ADMIN` grants direct RIMD access to time-sheet and archive tables and project journal lines, and RI access to employee absence and time-sheet posting entries. These rights also apply outside message-type calls; the owner and approver checks in message handlers do not restrict direct table access. Assign it only to users who should have those native permissions. The Foundation role extensions grant only Projects-owned objects.

For WIP methods, Get requires read permission on `Job WIP Method`. Set requires write permission on that table and read permission on `Job WIP Entry` and `Job WIP G/L Entry`. The app's role extensions grant codeunit execution without granting native table permissions.

## Example scenario

```json
{
  "type": "Projects.WIPMethod.Set",
  "version": "1.0",
  "data": {
    "code": "CUSTOM",
    "description": "Custom WIP",
    "recognizedCosts": "Usage (Total Cost)",
    "recognizedSales": "Contract (Invoiced Price)",
    "wipCost": false,
    "wipSales": false
  }
}
```

Read the saved method with `Projects.WIPMethod.Get` and `{ "code": "CUSTOM" }`. Help chapters stay English in every language; discovery, refusal messages and `nextStep` are translated for en-US and is-IS.

## Objects

| Type | ID | Name |
| --- | --- | --- |
| table | 70013433 | `Proj. Field Visit ori` |
| enum | 70013434 | `Proj. Visit Status ori` |
| enum | 70013435 | `Proj. Visit Kind ori` |
| codeunit | 70013436 | `Proj. Visit Start Impl ori` |
| codeunit | 70013437 | `Proj. Visit Stop Impl ori` |
| codeunit | 70013438 | `Proj. Visit Complete Impl ori` |
| codeunit | 70013439 | `Proj. Visit Mgt ori` |
| codeunit | 70013440 | `Proj. Visit Runner ori` |
| codeunit | 70013441 | `Proj. Visit Contract ori` |
| codeunit | 70013442 | `Proj. Visit Restrict ori` |
| enum value | 70013433 | `Projects.Visit.Start` |
| enum value | 70013434 | `Projects.Visit.Stop` |
| enum value | 70013435 | `Projects.Visit.Complete` |
| permission set | 70013443 | `PROJ VISIT` |
| test codeunit | 97186 | `Proj. Visit Tests ori` |
| test codeunit | 97187 | `Proj. Visit Perm Tests ori` |
| codeunit | 70013424 | `Proj. Plan Purchase Impl ori` |
| codeunit | 70013421 | `Proj. Plan Purchase Proc ori` |
| codeunit | 70013422 | `Proj. Plan Purchase Result ori` |
| codeunit | 70013423 | `Proj. Plan Purchase Scope ori` |
| enum value | 70013420 | `Projects.PlanningLine.CreatePurchaseOrder` |
| test codeunit | 97171 | `Proj. Plan Purchase Tests ori` |
| test codeunit | 97172 | `Proj Plan Purch Perm Tests ori` |
| test permission set | 97172 | `ProjNoPurch ori` (nonassignable) |
| test codeunit | 97173 | `Proj. Plan Purch Fixture ori` |
| test codeunit | 97174 | `Proj. Plan Purch Seed ori` |
| test enum extension/value | 97173 | `Proj. Plan Purch Types ori` / `Test.PlanPurchase74.Seed` |
| test page | 97173 | `Proj. Plan Purch Cleanup ori` |
| codeunit | 70013500 | `Projects Gate ori` |
| codeunit | 70013501 | `Projects Registration ori` |
| codeunit | 70013502 | `Projects Install ori` |
| codeunit | 70013503 | `Projects Setup Restrict ori` |
| codeunit | 70013504 | `Projects Contract ori` |
| codeunit | 70013505 | `Proj. Create Impl ori` |
| codeunit | 70013506 | `Proj. Update Impl ori` |
| codeunit | 70013507 | `Proj. Task Create Impl ori` |
| codeunit | 70013508 | `Proj. Task Update Impl ori` |
| codeunit | 70013509 | `Proj. Plan Create Impl ori` |
| codeunit | 70013510 | `Proj. Plan Update Impl ori` |
| codeunit | 70013512 | `Projects Input ori` |
| codeunit | 70013513 | `Projects Write Process ori` |
| codeunit | 70013514 | `Projects Write ori` |
| codeunit | 70013515 | `Proj. Copy Impl ori` |
| codeunit | 70013516 | `Proj. Status Impl ori` |
| codeunit | 70013517 | `Proj. WIP Get Impl ori` |
| codeunit | 70013518 | `Proj. WIP Calc Impl ori` |
| codeunit | 70013519 | `Proj. WIP Post Impl ori` |
| codeunit | 70013406 | `Proj. WIP Reverse Impl ori` |
| enum value | 70013400 | `Projects.WIP.Reverse` |
| test codeunit | 97114 | `Projects WIP Reverse Tests ori` |
| test codeunit | 97115 | `Proj. WIP Reverse Fixture ori` |
| test enum extension/value | 97114 | `Proj. WIP Fixture Types ori` / `Test.WIP75.Seed` |
| codeunit | 70013520 | `Projects WIP ori` |
| codeunit | 70013522 | `Proj. Posting Gate ori` |
| codeunit | 70013524 | `Proj. Statistics Impl ori` |
| codeunit | 70013525 | `Proj. Budget Actual Impl ori` |
| codeunit | 70013526 | `Projects Statistics ori` |
| codeunit | 70013527 | `Proj. Usage Get Impl ori` |
| codeunit | 70013528 | `Proj. Usage Link Impl ori` |
| codeunit | 70013529 | `Projects Usage ori` |
| codeunit | 70013540 | `Proj. WIP Method Get ori` |
| codeunit | 70013541 | `Proj. WIP Method Set ori` |
| codeunit | 70013542 | `Projects WIP Methods ori` |
| codeunit | 70013420 | `Proj. Item Cost Impl ori` |
| codeunit | 70013407 | `Proj. Item Cost Process ori` |
| codeunit | 70013408 | `Projects Item Cost ori` |
| codeunit | 70013409 | `Proj. Item Cost Confirm ori` |
| codeunit | 70013543 | `Proj. WIP Method Process ori` |
| codeunit | 70013425 | `Proj. Task Copy Impl ori` |
| codeunit | 70013426 | `Proj. Task Copy Process ori` |
| enum value | 70013425 | `Projects.Task.CopyFrom` |
| enumextension | 70013500 | `Projects Message Types ori` (adds value 70013552 `Projects.ItemCost.Update`) |
| codeunit | 70013419 | `Proj. Task Indent Impl ori` |
| enum value | 70013406 | `Projects.Task.Indent` |
| page | 70013500 | `Projects Setup ori` |
| permissionsetextension | 70013500 | `Projects Read ori` |
| permissionsetextension | 70013501 | `Projects Full ori` |
| permissionset | 70013402 | `PROJ USAGE` |
| codeunit | 70013431 | `Proj. My Day Impl ori` |
| codeunit | 70013432 | `Proj. Visit Brief Impl ori` |
| codeunit | 70013429 | `Proj. Field Service Mgt ori` |
| codeunit | 70013430 | `Proj. Field Contract ori` |
| permissionset | 70013403 | `PROJ FIELD TECH` |
| test codeunit | 97184 | `Proj. Field Service Tests ori` |
| test codeunit | 97185 | `Proj. Field Fixture ori` |
| test enumextension/value and cleanup page | 97185 | `Proj. Field Fixture Types ori / Test.Field82.Seed` |
| permissionset | 70013589 | `PROJ TS ADMIN` |
| table | 70013500 | `Projects Setup ori` |
| table | 70013521 | `Proj. Posting ori` |

Enum extension `Projects Message Types ori` adds WIP method values 70013540 and 70013541. Test codeunit 97116 covers issue #16; the test app's complete object range is 97100..97199.

## Dependencies

| Publisher | App | Minimum version |
| --- | --- | --- |
| Origo | Bifrost Foundation | 28.0.5.0 |

## Documentation

- [Project lifecycle contracts](docs/projects.md)
- [WIP method setup contract and errors](docs/contracts.md)

## Delivery status

Scaffold and lifecycle implementation are under development. Native component tests
are separate from queue API, licensing, bilingual Web Client and MCP acceptance.
Template/workflow restoration from merged PR #10 is integrated. Issues #5 and #6 have native implementation and component tests; current-candidate runtime and independent acceptance remain pending. Issue #8 has native implementation and component tests with runtime acceptance pending; #7 is closed as not planned with Gunnar's recorded disposition; tracking issue #9 does not authorize more message types.


Copyright © 2026 Origo.

### Shift project planning dates (#76)

`Projects.PlanningLine.ShiftDates` applies Change Project Planning Line Dates to a project or inclusive task range. Supply `projectNo`, `lineType` (`Budget`, `Billable`, `Both`) and exactly one of `dateFormula` (for example `+1W`) or `fixedDate` (ISO date). Optional `dateField` selects `planningDate` (default), `currencyDate`, or `both`; `includeFrom`/`includeTo` filter each selected date independently.

The operation is a plain write with no `expectedCount` (Architect ruling 20 November 2026). Transferred or invoiced lines in scope refuse the entire batch. The response lists old/new planning, currency and document dates; preserve the old values for exact restoration, especially for fixed dates and month-end shifts. Currency changes can also recalculate currency amounts. No UI change.

| Object | ID | Name |
|---|---|---|
| Codeunit | 70013417 | `Proj. Shift Dates Impl ori` |
| Codeunit | 70013418 | `Proj. Shift Dates Process ori` |
| Enum value | 70013533 | `Projects.PlanningLine.ShiftDates` |
| Test codeunit | 97167 | `Proj. Shift Dates Tests ori` |
| Test codeunit | 97168 | `Proj Shift Date Perm Tests ori` |
### Reverse posted WIP

`Projects.WIP.Reverse` uses the **Reverse Only** option of **Post WIP to G/L**. Send `projectNo`, required ISO `postingDate`, and `documentNo` (1–20 characters). Preview without `expectedCount`, then confirm the number of eligible posted WIP entries. The operation posts correcting G/L entries; it preserves calculated WIP and returns `reversedEntries`, current `wip`, `summary` and `nextStep: Projects.WIP.Calculate`. Completed WIP, an earlier posting date, missing candidates and stale confirmation are refused without changes. Requires **BIFROST Full ori** and native project/posting permissions.

### Copy tasks into an existing project

`Projects.Task.CopyFrom` uses Copy Project Tasks to append an inclusive task range and native planning lines, or planning lines converted from posted Usage/Sale entries. Both projects must exist. All colliding task numbers are refused before any copy; completed or fully blocked targets are refused. Omit `expectedCount` to preview the source task count, then repeat with that count. `copyQuantity`, `copyPrices` and `copyDimensions` default to true. No existing tasks or planning lines are replaced or deleted. Requires BIFROST Full ori and the caller's native project permissions. For a new target use `Projects.Project.Copy`.

### Purchase orders from project planning lines (#74)

`Projects.PlanningLine.CreatePurchaseOrder` previews uncovered item demand on one open, unblocked project. Set `preview: true` to calculate without retaining changes. Then create with `expectedCount` equal to the number of proposals. Purchase orders are grouped by vendor and carry native project task and planning-line links; receiving and invoicing posts project usage.

Select an optional exact `taskNo` or `planningLineNos` array, never both. Vendor overrides contain `planningLineNo` and `vendorNo`. Existing caller lines on Order Planning cause refusal before calculation. Only this call's own scratch lines are consumed. Non-item, billable-only and covered lines are returned in `skipped`. No posting or UI change. Company-wide planning belongs in the requisition or planning worksheet.

### Planning line transfer to journal (#81)

`Projects.PlanningLine.TransferToJournal` creates linked project journal lines from budget planning lines. Send `projectNo`, a nonempty `planningLines` array (`taskNo`, `lineNo`, optional positive `quantity`), `templateName`, `batchName`, and `postingDate`. Omitted quantity uses the remaining quantity. Existing journal lines stay unchanged, and nothing is posted. Check with `Projects.ProjectJournal.Check`, then post with `Projects.ProjectJournal.Post`.

| Object | ID | Purpose |
| --- | --- | --- |
| Proj. Plan Journal Impl ori | 70013427 | Contract, discovery, validation and permissions |
| Proj. Plan Journal Proc ori | 70013428 | Atomic native linked journal creation |
| Projects.PlanningLine.TransferToJournal | 70013426 | Message enum value |
| Proj. Plan Journal Tests ori | 97179 | Functional and bilingual acceptance tests |
| Proj. Plan Jnl Perm Tests ori | 97180 | Restrictive permission acceptance tests |
| ProjJnlNoInsert ori | 97180 | Nonassignable test permissions without journal insert |
| Proj. Plan Journal Fixture ori / Seed ori | 97181 / 97182 | Raw acceptance data and test-only seed adapter |
| Proj. Plan Journal Types ori | 97181 | Test-only fixture seed registration |
| Proj. Plan Jnl Cleanup ori | 97183 | Removes only story-marked acceptance fixtures and their posting entries |
