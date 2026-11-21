# Bifrost Projects

- Namespace: `Origo.Bifrost.Projects`
- Test namespace: `Origo.Bifrost.Projects.Test`
- Object range: 70013400–70013599 (app; whole Public 4 block, Gunnar 12.11.2026 #34, widened for #52 after Shopify left; usage objects take 70013400–70013499). Tests stay 97100–97199. The previous Public 3 range was 70009200–70009249.
- Foundation dependency: Bifrost Foundation 28.0.5.0
- Permissions: PermissionSetExtension only onto `BIFROST Read ori` / `BIFROST Full ori`
- No own assignable permission set; no `Setup ori` tabledata grants (exception below)

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

## Object ledger — issue #75

- Codeunit 70013406: `Proj. WIP Reverse Impl ori`; enum value 70013400: `Projects.WIP.Reverse`.
- Tests: codeunit 97114 `Projects WIP Reverse Tests ori`, codeunit 97115 `Proj. WIP Reverse Fixture ori`, enumextension/value 97114 `Proj. WIP Fixture Types ori` / `Test.WIP75.Seed` (test app only; no new delete operation).

## Issue #79 object ledger

- Codeunits 70013425 `Proj. Task Copy Impl ori`, 70013426 `Proj. Task Copy Process ori`; enum value 70013425 `Projects.Task.CopyFrom`.
- Tests: 97175 `Proj. Task Copy Tests ori`, 97176 `Proj. Task Copy Perm Tests ori`. Test-only nonassignable permission set 97176 `ProjCopyNoInsert ori`. Fixtures: 97177 codeunit, enumextension/value and cleanup page, 97178 seed codeunit (test app only). No new assignable permission set and no delete operation.
- Append-only existing-target copy; task conflicts refuse atomically. Foundation floor remains 28.0.5.0.
