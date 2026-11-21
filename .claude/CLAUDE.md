# Bifrost Projects

- Namespace: `Origo.Bifrost.Projects`
- Test namespace: `Origo.Bifrost.Projects.Test`
- Object range: 70013400–70013599 (app; whole Public 4 block, Gunnar 12.11.2026 #34, widened for #52 after Shopify left; usage objects take 70013400–70013499). Tests stay 97100–97199. The previous Public 3 range was 70009200–70009249.
- Foundation dependency: Bifrost Foundation 28.0.5.0
- Permissions: PermissionSetExtension only onto `BIFROST Read ori` / `BIFROST Full ori`
- No own assignable permission set; no `Setup ori` tabledata grants (exception below)
- #83 field visits use assignable `PROJ VISIT` (70013443) together with `BIFROST Read ori` and `PROJ TS SELF`. It holds the visit table and the Base App read grants the visit needs (job, task, planning line, work type, resource) plus usage-line RIM. No journal tabledata. `PROJ FIELD TECH` (owned by #82) includes `PROJ VISIT`. Do not recreate `PROJ FIELD TECH` here. Object ids 70013429–70013432 and tests 97184–97185 belong to #82.

## Deviations

- #38: three role sets for time-sheet self-service, Architect 18.11.2026. `PROJ TS SELF` (70013586), `PROJ TS APPROVER` (70013587) and `PROJ TS POST` (70013588) are assignable and assigned together with `BIFROST Read ori`. Ruling C (Architect, 18.11.2026, PR #57) replaced "indirect only": the sets are convenience bundles with direct tabledata. Role separation for approval is the sheet's approver identity; posting is separated by journal/posting rights; the sets are bundles. The Read/Full extensions and the owner/approver checks in code stay.
- #33 admin time-sheet types need PROJ TS ADMIN for Base App tabledata (AS0110 fix, Architect 18.11.2026). `PROJ TS ADMIN` (permission set 70013589) is assignable and is assigned together with `BIFROST Full ori`. It holds the 27 Base Application tabledata grants and the `Create Time Sheets` report grant that `Projects TimeSheet Full ori` had, at the same levels; the extension keeps only this app's codeunits (#65).
- #52 usage types need PROJ USAGE for Base App tabledata (same AS0110 fix, Architect 18.11.2026, PR #66 comment 6980138913). `PROJ USAGE` (permission set 70013402) is assignable and is assigned together with `BIFROST Full ori` (or `BIFROST Read ori` for `Projects.Usage.List`). It holds the 16 Base Application tabledata grants that `Projects Usage Full ori` and `Projects Usage Read ori` had, at the same levels; both extensions keep only this app's objects. No Base App grant lives in a permission set extension anywhere in Projects.

## Issue 78 object ledger

- Codeunit 70013419 `Proj. Task Indent Impl ori` (renumbered from 70013406 after #75 took it; 70013406-70013409 are claimed by PR #88, 70013417-70013418 belong to #76): native task indentation, shared write transaction.
- Enum value 70013406 `Projects.Task.Indent` in `Projects Message Types ori`.
- Test codeunits 97169 `Proj. Task Indent Tests ori` and 97170 `Proj. Indent Perm Tests ori`; test-only permission set 97170 `ProjIndentNative ori` (all renumbered from 97114/97115 after #75 took them). No assignable role added.

## #76 object ledger

- Codeunit 70013417 `Proj. Shift Dates Impl ori`: contract and validation.
- Codeunit 70013418 `Proj. Shift Dates Process ori`: atomic native date batch.
- Enum value 70013533 `Projects.PlanningLine.ShiftDates`.
- Test codeunits 97167 `Proj. Shift Dates Tests ori`, 97168 `Proj Shift Date Perm Tests ori`.
- Architect ruling 20.11.2026: plain write, no expectedCount; refuse transferred/invoiced lines.
## Object ledger — issue #77

- Codeunit 70013420: `Proj. Item Cost Impl ori` (renumbered from 70013419 after Projects.Task.Indent took it on main). 70013417 stays `Proj. Shift Dates Impl ori` (Architect ruling 20.11.2026). Also 70013407 `Proj. Item Cost Process ori`, 70013408 `Projects Item Cost ori`, 70013409 `Proj. Item Cost Confirm ori`.
- Enum value 70013552: `Projects.ItemCost.Update`.
- Tests: codeunits 97156 `Projects Item Cost Tests ori`, 97157 `Proj. Item Cost Perm Tests ori`.

## Object ledger — issue #75

- Codeunit 70013406: `Proj. WIP Reverse Impl ori`; enum value 70013400: `Projects.WIP.Reverse`.
- Tests: codeunit 97114 `Projects WIP Reverse Tests ori`, codeunit 97115 `Proj. WIP Reverse Fixture ori`, enumextension/value 97114 `Proj. WIP Fixture Types ori` / `Test.WIP75.Seed` (test app only; no new delete operation).

## Issue #79 object ledger

- Codeunits 70013425 `Proj. Task Copy Impl ori`, 70013426 `Proj. Task Copy Process ori`; enum value 70013425 `Projects.Task.CopyFrom`.
- Tests: 97175 `Proj. Task Copy Tests ori`, 97176 `Proj. Task Copy Perm Tests ori`. Test-only nonassignable permission set 97176 `ProjCopyNoInsert ori`. Fixtures: 97177 codeunit, enumextension/value and cleanup page, 97178 seed codeunit (test app only). No new assignable permission set and no delete operation.
- Append-only existing-target copy; task conflicts refuse atomically. Foundation floor remains 28.0.5.0.

## Issue #74 object ledger

- Codeunits 70013424 `Proj. Plan Purchase Impl ori`, 70013421 `Proj. Plan Purchase Proc ori`, 70013422 `Proj. Plan Purchase Result ori`, 70013423 `Proj. Plan Purchase Scope ori` (scoped native subscribers).
- Enum value 70013420 `Projects.PlanningLine.CreatePurchaseOrder`.
- Tests 97171 `Proj. Plan Purchase Tests ori`, 97172 `Proj Plan Purch Perm Tests ori`. Test-only nonassignable permission set 97172 `ProjNoPurch ori` isolates purchase-right refusals. Test fixtures: codeunits 97173/97174, enumextension/value 97173 (seed only) and cleanup page 97173. No new assignable role.
- Gunnar 20.11.2026, comment 7052438484: consume only scratch lines created by this call; refuse before calculation if caller has existing order-planning lines. Architect: one operation with rollback-only preview.

## Issue #82 — technician reads and role

- Gunnar 20.11.2026: assignable PROJ FIELD TECH (70013403), assigned with BIFROST Read ori. Includes the PROJ TS SELF bundle, native project/planning/site/stock reads and TS Usage Line ori RIM; no journal data or Job/Job Task/Job Planning Line writes. PROJ USAGE unchanged.
- Codeunits 70013429–70013432: MyDay/VisitBrief implementations, shared manager and contract. Message enum values 70013427/70013428. Test 97184; test fixture codeunit, enumextension/value and cleanup page 97185.
- Architect 21.11.2026: implement and open the PR now; AC06 SaaS Team Member Effective Permissions receipt is NOT_RUN until the user is provisioned on 23 November.
## Issue #81 object ledger

- Codeunits 70013427 `Proj. Plan Journal Impl ori` and 70013428 `Proj. Plan Journal Proc ori`; enum value 70013426 `Projects.PlanningLine.TransferToJournal`.
- Tests 97179 `Proj. Plan Journal Tests ori`, 97180 `Proj. Plan Jnl Perm Tests ori`; nonassignable test permission set 97180 `ProjJnlNoInsert ori`. Fixture codeunits 97181/97182, cleanup test codeunit 97183, test enumextension/value 97181 `Test.PlanJournal81.Seed`.
- Append-only native journal creation, write effect, no confirmation or posting gate. Enables Usage Link and preserves existing journal lines. Foundation minimum stays 28.0.5.0.

## Issue #83 object ledger

- Table 70013433 `Proj. Field Visit ori`. Enums 70013434 `Proj. Visit Status ori`, 70013435 `Proj. Visit Kind ori`.
- Codeunits 70013436 `Proj. Visit Start Impl ori`, 70013437 `Proj. Visit Stop Impl ori`, 70013438 `Proj. Visit Complete Impl ori`, 70013439 `Proj. Visit Mgt ori`, 70013440 `Proj. Visit Runner ori`, 70013441 `Proj. Visit Contract ori`, 70013442 `Proj. Visit Restrict ori`.
- Enum values 70013433 `Projects.Visit.Start`, 70013434 `Projects.Visit.Stop`, 70013435 `Projects.Visit.Complete`.
- Permission set 70013443 `PROJ VISIT`. Tests 97186 `Proj. Visit Tests ori`, 97187 `Proj. Visit Perm Tests ori`.
- Projects Setup fields: Travel Work Type Code, Mileage Resource No., Rounding Minutes, Client Time Tolerance Hours, Allow Unplanned Tasks. Zero rounding means one minute and zero tolerance means 24 hours, so existing rows keep working. The message path does not insert the setup row.
