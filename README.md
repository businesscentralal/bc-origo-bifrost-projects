# Bifrost Projects

| App ID | App object range | Test object range | Target |
| --- | --- | --- | --- |
| `c847bab7-2525-4ff5-93c4-15512b3be1e5` | 70013500..70013599 | 97100..97199 | Business Central 28 or later, Cloud extension |

## Overview

Bifrost feature app for project (job) message types that are not covered by Bifrost Foundation: project lifecycle, tasks and planning lines, copy, status, prices, WIP, budget vs actual, project invoicing helpers and project queries. Message types use the `Projects.*.*` pattern.

Time sheets and the Clockify sync belong to **Bifrost Timesheets** (businesscentralal/bc-origo-bifrost-timesheets), not here. Project journal and project-to-sales-invoice/credit-memo types live in **Bifrost Foundation**.

- Depends only on Bifrost Foundation.
- Object range: 70013500..70013599 (app; upper part of Public 4 while Shopify still uses 70013400..70013481), 97100..97199 (tests).

## Functional flow

1. Discover a type with `Help.MessageTypes.Get`, then read its contract through `Help.Implementation.Get`.
2. Send version `1.0` and a JSON object in `data`; `subject` is not used.
3. Read the native result or follow the typed refusal's recovery guidance.

### Message types

| Type | Data | Result |
| --- | --- | --- |
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

| `Projects.ResourceAllocation.Get` | `periodType`, `fromDate`, `toDate`; optional project/resource/group selectors | Resource capacity, per-project allocation and availability by period. |
| `Projects.WIPMethod.Get` | Optional exact `code`; `{}` lists all | Reads native WIP methods, recognized settings and flags. |
| `Projects.WIPMethod.Set` | Required `code`, optional recognized settings, flags and description | Creates or partially updates a custom method; refuses system-defined methods and methods used by WIP history. |


## Benefits

- Create related project, task and planning-line records in one transaction.
- Use native BC validation for project changes, WIP calculation and posting.
- Read stable recognized cost/sales enum names in either English or Icelandic sessions.

## Logic flow

`Company switch and native permissions → Foundation licence/version checks → request validation → native transaction → response`

Write failures roll back the native transaction. Native WIP method validation failures include a translated summary and preserve the original platform diagnostic in `nativeError`. WIP method Set preserves omitted fields and refuses system-defined methods or methods referenced by calculated or posted WIP, including reversed posted history.

## Setup and configuration

Calls require the native BC table permissions in addition to the Foundation role. WIP posting also requires the Projects Full role extension (via `BIFROST Full ori`); Projects Read does not grant posting. Projects Setup is a company-wide switch; generic `Data.Records.Set` cannot change it.

The time-sheet message types (`Projects.TimeSheet.*`, `Projects.TimeSheetLine.*`, `Projects.Absence.Register`, `Projects.PendingApproval.Get`) need `BIFROST Full ori` together with the assignable set `PROJ TS ADMIN`, which grants the Base Application time-sheet, resource, employee, absence, project journal and number series data. `BIFROST Full ori` alone is refused with `PermissionDenied` and the next step "Assign the BIFROST Full ori and PROJ TS ADMIN permission sets." `Projects.PendingApproval.Get` only reads: `BIFROST Read ori` or `BIFROST Full ori` together with `PROJ TS ADMIN` is enough.

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
| codeunit | 70013543 | `Proj. WIP Method Process ori` |
| enumextension | 70013500 | `Projects Message Types ori` |
| page | 70013500 | `Projects Setup ori` |
| permissionsetextension | 70013500 | `Projects Read ori` |
| permissionsetextension | 70013501 | `Projects Full ori` |
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
