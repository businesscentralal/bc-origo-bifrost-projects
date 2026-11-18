# Projects contracts

Projects owns projects, tasks, planning lines and the project lifecycle. Time sheets
and Clockify stay in Timesheets. The app depends only on Bifrost Foundation.

## Setup and discovery

Open **Projects Setup** from Foundation's registered applications. `Enabled` is on by
default. Disabling it hides enabled write operations and returns an explicit error
when a caller invokes one. Setup is company-specific. The Read role can read the
switch; the Full role can administer it. Neither extension grants Foundation Setup
tabledata, a new assignable role, or native project table privileges.

`Help.MessageTypes.Get` discovers the twenty-one registered `Projects.*.*` types, including `Projects.PurchaseLine.Link`, `Projects.ItemUsage.Post`, `Projects.WIPMethod.Get`, `Projects.WIPMethod.Set` and `Projects.Report.Get`.
`Help.Implementation.Get` describes each version 1.0 operation and its nested schema.
Descriptions, selection help and keywords support en-US and is-IS.

## Request fields

All calls require a JSON object in `data`. Project, task and planning-line calls
use `projectNo` (maximum 20 characters). WIP method calls use `code` instead;
Get may omit it to list methods. See the [WIP method setup contract](contracts.md)
for these two types. `subject` is not used. Update operations change only supplied fields.
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

Nested tasks inherit their project number; nested planning lines inherit both
parent keys. Nested `operation` defaults to `Create`. Use `operation: "Update"` to
change an existing nested task or planning line atomically with the parent. A missing
update key or duplicate create key produces a native error and rolls back the entire operation.
BC validates task totaling/indentation and resource, item and G/L planning fields.
Normal BC prerequisites (including a bill-to customer for tasks) still apply.

## Responses and errors

Success returns `status: "Success"` and `projectNo`; task and planning-line calls
also return `taskNo`, and planning-line calls return `lineNo`. There are no posts
or time sheet operations in these six types.

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

## Send a project quote

```json
{"type":"Projects.Quote.Send","version":"1.0","data":{"projectNo":"XPROJECT","documentSendingProfile":"EMAIL"}}
```

Sends the quote of a project in status `Quote` to its bill-to customer, as the
Send Project Quote action on the project card does, without its confirmation
window. The profile is `documentSendingProfile` (at most 20 characters, compared
in upper case, never cut), else the bill-to customer's Document Sending Profile,
else the profile marked Default. Every check runs before anything is sent:

- a project that is not in status `Quote` is `PreconditionFailed` (parameter `projectNo`, `received` is the status);
- a missing or unknown bill-to customer is `PreconditionFailed`;
- an unknown profile is `RecordNotFound`; a profile with a Disk channel, an e-mail settings prompt, or an e-mail channel without a customer address is `PreconditionFailed`.

Business Central then validates the electronic formats, sends through every
channel of the profile and archives the project by the Projects Setup rule
(Archive Projects). Its own errors come back as `BusinessCentralError` and roll
back. Success returns `projectNo`, `projectId`, `customerNo`, `customerName`,
`documentSendingProfileCode`, `documentSendingProfileSource` (`Request`,
`Customer` or `Default`) and `archived`. Not retry-safe: a second call sends the
quote again. Refusals and their `nextStep` follow the session language.

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
extensions under the #18 decision. Shipping queue acceptance is tracked separately
in #17 and must use the exact deployed Foundation version. The historical EULA
refusal on an older Foundation deployment does not establish a current sandbox or
evaluation-company refusal. No consent, trial or licence state is written to obtain
a verification pass.

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

## Standard project reports

`Projects.Report.Get` returns standard project reports as typed JSON detail rows or
as a base64 PDF using the standard report layout. It is read only and never posts
or changes project data. Custom layouts and scheduling are outside its scope.

| Parameter | Meaning |
| --- | --- |
| `report` | Required: `actualToBudget`, `analysis`, `wipToGL` or `register`. |
| `format` | Required: `json` or `pdf`. |
| `projectNo` | Exact project number, required except for `register`. |
| `taskNo` | Optional exact task within `projectNo`; unsupported for `wipToGL`. |
| `registerNo` | Required positive integer for `register`; unsupported otherwise. |
| `fromDate`, `toDate` | Optional paired ISO dates, inclusive; filter posting and planning dates. |

JSON responses contain `status`, `report`, `format` and `rows`. Actual-to-budget
rows expose item/resource identifiers and budget, actual and difference values for
quantity, cost and price. Analysis returns task budget, actual, billable and
invoiced costs/prices, omitting rows with no selected amounts. WIP rows expose
account, posting group, WIP amounts, G/L balance and difference. Register rows
expose ledger entry and register numbers, project, posting date, document and
quantity/cost/price amounts. All monetary amounts use local currency.

An empty JSON report returns `rows: []`. PDF responses contain
`contentType: "application/pdf"` and `pdfBase64`, including the empty standard
report. When the native report produces no pages for an empty dataset, the response
contains a valid blank PDF instead of an empty string. Populated reports keep the
standard layout. Example request:

```json
{"type":"Projects.Report.Get","data":{"report":"analysis","format":"json","projectNo":"PROJECT-001","taskNo":"TASK-001","fromDate":"2026-01-01","toDate":"2026-01-31"}}
```

An unknown report returns `InvalidParameter` with next step "Use one of the values
listed in the help." A missing required selector/filter returns `MissingParameter`
with "Pass the filter named in the refusal." Wrong JSON types, unknown keys,
missing records and conflicting project/task identifiers return
`InvalidParameterFormat`, `UnknownParameter`, `RecordNotFound` and
`ConflictingIdentifiers`, respectively, with corrective next steps. Missing native
read permissions returns `PermissionDenied`, naming BIFROST Read ori and native
project report permissions. Feature roles grant the report implementation; native
Business Central permissions remain the caller's responsibility.

## Self-service and approval time sheets

Seven types let an employee work on their own time sheets and an approver work on their queue
(projects#38). The caller is always the signed-in session user; the request never names a user.

| Type | Who | Effect |
|---|---|---|
| `Projects.MyTimeSheet.Get` | Owner | Reads own sheets (Owner User ID = caller) with lines, daily hours (`days`), `totalHours` and `comments`. Optional `timeSheetNo`, `from` + `to`, `status` (Open, Submitted, Rejected, Approved), `take` (1..100), `skip`. |
| `Projects.MyTimeSheet.Create` | Owner | Creates the own sheet for one period (`startingDate` on the Time Sheet First Weekday; `resourceNo` only when the caller owns several time sheet resources), with the rules of the native Create Time Sheets report. The caller does not need Time Sheet Admin. An existing sheet returns `created` false. |
| `Projects.MyTimeSheetLine.Set` | Owner | Adds or edits own lines (`timeSheetNo`, `lines` 1..50: optional `lineNo`, `type` Job or Resource, `projectNo`, `taskNo`, `workTypeCode`, `description`, `days` [{`date`, `hours`}]). Only Open or Rejected lines can change; an edited rejected line returns to Open. All entries are one transaction. No delete: zero hours keeps the day. |
| `Projects.MyTimeSheet.Submit` | Owner | Submits own open lines (`timeSheetNo`, or `resourceNo` + `date`; optional `lineNos`). |
| `Projects.TimeSheetApproval.Get` | Approver | Reads sheets whose Approver User ID is the caller and that hold submitted lines. The caller's own sheets are never listed. Optional `timeSheetNo`, `from` + `to`, `take`, `skip`. |
| `Projects.TimeSheetApproval.Approve` | Approver | Approves submitted lines, per line (`lineNos`) or for the whole sheet. |
| `Projects.TimeSheetApproval.Reject` | Approver | Rejects submitted lines with an optional `comment` (80 characters). The comment is returned on the line by `Projects.MyTimeSheet.Get`. |

Every call that names a sheet checks owner or approver before anything is read or written, and
the native writer checks again. Another user's sheet is refused with `PermissionDenied`, a
`nextStep` and no record data. An approver cannot approve or reject their own sheet. A caller who
is not the time sheet owner (or approver) of any resource or sheet is refused. Line.Set, Approve and Reject
commit on success and roll back every selected line on failure, as the `Projects.TimeSheet.*`
administrator types do. Item and resource usage lines are not part of these types; they use the `Projects.Usage.*` types
below (#52).

Role sets: assign `PROJ TS SELF` (the four My* types), `PROJ TS APPROVER` (the three Approval types)
or `PROJ TS POST` (`Projects.TimeSheet.Post` and `.Archive`) together with `BIFROST Read ori`. The
sets are convenience bundles with direct tabledata, so a user who has them can also open time sheets in
the client, exactly as with native BC time sheets. Role separation for approval is the sheet's approver
identity (Approver User ID), checked in code. Posting is separated by journal and posting rights: only
`PROJ TS POST` carries the journal, ledger and register data a post needs. A posting user also needs
read access to the project's master data (customer, posting groups, prices), for example `D365 READ`. A self-service user
who creates sheets with `Projects.MyTimeSheet.Create` likewise needs ordinary read access (the native Create Time Sheets report
reads dimension and setup captions), for example `D365 READ`; every write right still comes from `PROJ TS SELF`. The owner and approver
checks in code apply in every role.

## Compare resource capacity with time sheets and usage

```json
{
  "type": "Projects.ResourceCapacity.Get",
  "data": {
    "resourceNo": "RESOURCE-001",
    "periodType": "month",
    "fromDate": "2026-01-01",
    "toDate": "2026-01-31"
  }
}
```

Returns `status`, `periodType` and `rows`. Each row contains `resourceNo`, `fromDate`, `toDate`, `capacity`, `timeSheetHours` and `usage`.

| Input | Meaning |
|---|---|
| `resourceNo` | Optional exact resource number, at most 20 characters. |
| `resourceGroupNo` | Optional exact resource group; combines with `resourceNo`. Omit both selectors for all visible resources. |
| `periodType` | Required: `day`, `week`, `month`, `quarter` or `year`. |
| `fromDate`, `toDate` | Required inclusive ISO dates. Partial periods are clipped; weeks end Sunday. Maximum 53 periods. |

`capacity` sums Res. Capacity Entry quantities. `timeSheetHours` sums active and archived Time Sheet Detail quantities for all statuses and types by work date. `usage` sums Res. Ledger Entry **Usage** quantities in the resource base unit by posting date, including negative corrections; Sale entries are excluded. Capacity and usage use the resource base unit. Time-sheet quantities are native hours. Time-sheet hours can overlap posted usage: do not add them together. Missing entries return zero.

The call changes no business data. It requires Projects to be enabled and the caller to have read access to Resource, Resource Group, Res. Capacity Entry, Res. Ledger Entry, Time Sheet Detail and Time Sheet Detail Archive. Business Central security filters continue to apply.

Invalid period types return `InvalidParameter`; more than 53 periods returns `LimitExceeded`. Missing/invalid/unknown parameters, nonexistent selectors and conflicting resource/group selectors return a Bifröst error code with a localized `nextStep`. Help is available in en-US (1033) and is-IS (1039).

Related: `Projects.ResourceAllocation.Get` uses the same resource/group selectors, calendar boundaries and `rows` identity fields; it reports planned project allocation and availability instead of time-sheet and posted usage quantities.

## Time sheet usage lines

Usage lines record items and resources a user used on a time sheet line (tools, km driven, bolts). A line belongs to a time sheet and one of its lines, carries a state and goes through approval into a journal. Native time sheet lines have no item type, so the usage sits in its own table (`TS Usage Line ori`). Use the dedicated messages; a generic `Data.Records.Set` of `Status`, `Reversed` or the journal fields is refused with a hint naming them.

| Message type | Who | What it does |
|---|---|---|
| `Projects.Usage.Register` | owner of the sheet | Creates an Open line. Keys: `timeSheetNo`, `lineNo`, `type` (Item or Resource), `no`, `date` (inside the sheet week), `quantity` (> 0), optional `unitOfMeasure`, `description`. The item or resource must exist and not be blocked. |
| `Projects.Usage.Submit` | owner | Open or Rejected lines become Submitted. Keys: `timeSheetNo`, optional `entryNos`. |
| `Projects.Usage.Approve` | approver named on the sheet, never its owner | Submitted lines become Approved. |
| `Projects.Usage.Reject` | approver | Submitted lines become Rejected, optional `comment` (at most 250 characters). The owner can submit them again. |
| `Projects.Usage.Transfer` | approver | Creates journal lines for Approved lines, once, in one transaction; nothing is posted. |
| `Projects.Usage.Reverse` | approver | Flags a Posted line Reversed, once. With `createJournalLine: true` it also creates a journal line with negative quantity. |
| `Projects.Usage.List` | owner, approver | Read-only, paged (`skip`, `take` at most 200). Filters `timeSheetNo`, `status`, `pending` (Submitted lines addressed to the caller as approver). |

States: Open, Submitted, Approved, Rejected, Transferred, Posted. Transferred means a journal line exists. Posting that journal line sets Posted and stores the ledger entry number; deleting the journal line before posting returns the line to Approved.

Journal mapping: an item line goes to the Item Journal (negative adjustment), a resource line to the Resource Journal (usage). A line whose time sheet line has a project goes to the Job Journal. Send `itemTemplate`/`itemBatch`, `resourceTemplate`/`resourceBatch` or `jobTemplate`/`jobBatch` for each kind present. Transfer and Reverse need write access to those journal tables and are refused with a next step otherwise. The usage message types need `BIFROST Full ori` together with the assignable set `PROJ USAGE` (`BIFROST Read ori` and `PROJ USAGE` for `Projects.Usage.List`); `PROJ USAGE` grants the Base Application time sheet, item, resource, journal and ledger data. The journal document number is `TSU` plus the entry number (`TSR` for a reversal).

## Read a time sheet

```json
{"type":"Projects.TimeSheet.Get","data":{"timeSheetNo":"TS00001"}}
```

Returns `timeSheets` with the header, lines, daily hours, line and day statuses,
and line totals. Only the authenticated owner or approver may read a sheet;
blank assignments grant no access. Native read permissions are also required.
Status names remain English enum names in both supported locales.

| Selection | Request data |
|---|---|
| One sheet by number | `{"timeSheetNo":"TS00001"}` |
| One sheet containing a date | `{"resourceNo":"R001","date":"2026-11-18"}` |
| Paged list | `{"resourceNo":"R001","from":"2026-11-01","to":"2026-11-30","take":20,"skip":0}` |

List filters are optional. `from` and `to` must be supplied together and select
sheet periods that overlap the inclusive range. All daily hours on each selected
sheet are returned. `take` is 1–100 (default 20); `skip` is a nonnegative integer
(default 0). Results are ordered by sheet number and include only authorized
sheets. When `hasMore` is true, add the number returned to `skip` for the next page.
Concurrent sheet changes can shift offset-based pages.

Single-sheet selectors cannot be mixed with paging or range filters. An empty
list for a mapped caller succeeds; a caller with no resource or sheet mapping
receives `PermissionDenied`. An unauthorized sheet returns `PermissionDenied`
without record data. Invalid input and missing records return typed Bifröst
errors with a localized `nextStep`. The help catalogue (description, selection
text and keywords) follows en-US or is-IS. Foundation publishes machine-readable
contract chapters in English at every LCID (core #1239).
Related operations: `Projects.PendingApproval.Get`, `Projects.TimeSheet.Submit`.
