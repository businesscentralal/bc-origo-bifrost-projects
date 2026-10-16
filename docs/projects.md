# Projects contracts

Projects owns projects, tasks, planning lines and the project lifecycle. Time sheets
and Clockify stay in Timesheets. The app depends only on Bifrost Foundation.

## Setup and discovery

Open **Projects Setup** from Foundation's registered applications. `Enabled` is on by
default. Disabling it hides enabled write operations and returns an explicit error
when a caller invokes one. Setup is company-specific. The Read role can read the
switch; the Full role can administer it. Neither extension grants Foundation Setup
tabledata, a new assignable role, or native project table privileges.

`Help.MessageTypes` discovers the seven registered `Projects.*` write types.
`Help.Implementation.Get` describes each version 1.0 operation and its nested schema.
Descriptions, selection help and keywords support en-US and is-IS.

## Request fields

All calls require a JSON object in `data`, containing `projectNo` (maximum 20
characters). `subject` is not used. Update operations change only supplied fields.
Create operations fail if the key already exists; they do not silently update it.

- Project: `description` (100), `billToCustomerNo` (20), `personResponsible` (20),
  `startingDate`, `endingDate` (ISO dates), `currencyCode` (10), optional `tasks[]`.
- Task: required `taskNo` (20); optional `description` (100), `taskType`
  (`Posting`, `Heading`, `Total`, `Begin-Total`, `End-Total`), `totaling` (250),
  nonnegative integer `indentation`, optional `planningLines[]`.
- Planning line: required `taskNo` (20), positive integer `lineNo`; optional `type`
  (`Resource`, `Item`, `G/L Account`, `Text`), `lineType` (`Budget`, `Billable`,
  `Both Budget and Billable`), `no` (20), `description` (100), `planningDate`,
  `unitOfMeasureCode` (10), numeric `quantity`, `unitCost`, `unitPrice`.
- Planning line deletion uses only `projectNo`, `taskNo`, `lineNo`.

Nested tasks inherit their project number; nested planning lines inherit both
parent keys. Nested `operation` defaults to `Create`. Use `operation: "Update"` to
change an existing nested task or planning line atomically with the parent. A missing
update key or duplicate create key produces a native error and rolls back the entire operation.
BC validates task totaling/indentation and resource, item and G/L planning fields.
Normal BC prerequisites (including a bill-to customer for tasks) still apply.

## Responses and errors

Success returns `status: "Success"` and `projectNo`; task and planning-line calls
also return `taskNo`, and planning-line calls return `lineNo`. There are no posts
or time sheet operations in these seven types.

Malformed or null values, overlong codes, invalid dates/enums and wrong-shaped
nested arrays return `InvalidParameterFormat`; missing/empty identifiers return
`MissingParameter`. Multiple problems return `MultipleErrors` with every parameter
path. Native validation and duplicate/missing records return `BusinessCentralError`.
Permission checks return `PermissionDenied` before licensing or writes. All native
writes use validation and table triggers in one rollback boundary. Foundation's
`Omit Commit` flag preserves the caller transaction: errors then propagate to the
outer dispatcher rather than forcing a nested commit.

## Example

After creating your own customer `XCUSTOMER`, send:

```json
{
  "type": "Projects.Project.Create",
  "version": "1.0",
  "data": {
    "projectNo": "XPROJECT",
    "billToCustomerNo": "XCUSTOMER",
    "description": "Example project",
    "tasks": [{"taskNo": "X100", "description": "First task"}]
  }
}
```

## Copy a project

```json
{"type":"Projects.Project.Copy","version":"1.0","data":{"projectNo":"XSOURCE","targetProjectNo":"XTARGET","fromTaskNo":"X100","toTaskNo":"X900","copyQuantity":true,"copyPrices":true,"copyDimensions":true,"planningLineType":"Both"}}
```

`projectNo` identifies the source. `targetProjectNo` is a new project number (20
characters maximum). Optional `description`, `sellToCustomerNo` and
`billToCustomerNo` override copied header fields. Both task-range endpoints are
inclusive and may be omitted. `planningLineType` is `Both` (default), `Budget` or
`Billable`. Quantity, price and dimension flags default to true and must be JSON
Booleans. Native Copy Job creates the target in Planning status and applies the
selected options. Success returns the new `projectNo` and `sourceProjectNo`.
An existing target or a native copy error rolls back the whole copy.

## Change status or blocking

```json
{"type":"Projects.Project.SetStatus","version":"1.0","data":{"projectNo":"XPROJECT","status":"Open","blocked":"None"}}
```

Send `status`, `blocked`, or both. Status accepts `Planning`, `Quote`, `Open` or
`Completed`. Blocking accepts `None` (unblock), `Posting` or `All`. Omitted state
fields are preserved. A call with neither state field returns `MissingParameter`.
The operation uses BC field validation, including native completion/WIP handling;
it does not assign status directly or bypass WIP requirements. Success returns
`status: "Success"` and `projectNo`. Native validation errors roll back both changes.

## Read or calculate WIP

```json
{"type":"Projects.WIP.Calculate","version":"1.0","data":{"projectNo":"XPROJECT","postingDate":"2026-10-16","documentNo":"XCALC"}}
```

`Projects.WIP.Get` requires only `projectNo`. Calculate also requires an explicit ISO
posting date and document number. It invokes the native WIP engine and its method,
blocked-project and field validations. Success returns `projectNo`, `entries` and
`glEntries`; each entry includes its number, document/date, accounts, amount, type
and completion state. Posted entries also include reversal state and G/L entry no.
Get reads one project and does not change or post its entries.

Native component coverage includes self-seeded read fixtures, an empty-project
calculation baseline, nonzero economic calculation and native G/L posting fixtures,
required options and native missing-method validation. Component tests are distinct
from shipping queue, bilingual Web Client and independent acceptance.
`Projects.WIP.Post` uses the Projects-owned gate mapped to the Read/Full role
extensions under the #18 decision. Shipping queue acceptance remains blocked
separately in #17.

## Pending scope

WIP, statistics and usage link are implemented for issues #5, #6 and #8; shipping
acceptance and delivery remain pending. Issue #7 was
closed as not planned, with Gunnar's recorded skip comment; no query implementation
is claimed. Invoice helpers and other medium/low gaps stay in tracking #9 pending
Gunnar's decision. No acceptance or delivery is implied by this contract text.

## WIP posting and statistics

`Projects.WIP.Post` takes the same `projectNo`, ISO `postingDate` and `documentNo`
as Calculate. It invokes native BC WIP posting, retaining native checks and transaction
rollback. New ledger entries retain the calculated WIP document number. The caller
must hold the Projects Full role extension via `BIFROST Full ori` as well as native
business permissions. Projects Read grants no posting token write. The token table stores no data.

`Projects.Statistics.Get` takes `projectNo` and returns `currency: "LCY"` and
`statistics` with `budget`, `actual`, `billable`, `invoiced`. Each contains `resource`,
`item`, `glAccount`, `total`, each with `cost` and `price`. These are native BC
statistics amounts, including the native invoice sign convention.
`Projects.BudgetVsActual.Get` returns the same project totals plus `tasks[]` with
`taskNo` and the same `statistics` shape. Optional exact `taskNo` filters the task
breakdown only. Only posting tasks are included, avoiding total-task double counting.
Both operations are read-only and require native read permissions.

## Usage links

`Projects.Usage.Get` requires `projectNo` and `taskNo`, returning `links[]`
(`entryNo`, `lineNo`) and `planningLines[]` (`lineNo`, `quantity`,
`remainingQuantity`, `usageLink`). It does not change quantities.

`Projects.Usage.Link` additionally requires the exact usage `entryNo`. Supply a
positive existing `lineNo`, or `createPlanningLine: true` to use BC transfer from
usage. Creation accepts `lineType` Budget (default), Billable or Both Budget and
Billable; native BC may split budget and billable lines. The project must have
Apply Usage Link enabled. An entry from another project/task or an already linked
entry is rejected before changes. Existing planning lines must match the entry's
type, number, unit, location, variant and work type. Native validation and
rollback are retained. No journal or financial entry is posted by this message.
