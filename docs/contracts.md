# Contract errors

Projects message types follow the Foundation contract-error rules (core#711): `InvalidParameterFormat` for wrong-shaped `data` or identifier keys, `MissingParameter` for missing/empty keys, `MultipleErrors` when several values are wrong.

## Resource allocation

`Projects.ResourceAllocation.Get` is read-only. Required data keys: `periodType` (`day`, `week`, `month`, `quarter`, `year`), `fromDate`, `toDate` (inclusive ISO dates). Optional exact `projectNo`, `resourceNo`, `resourceGroupNo` combine; conflicting resource/group selectors are refused. At most 53 calendar periods are accepted. Rows contain resourceNo, fromDate, toDate, capacity, allocated, availability and per-project allocated quantities in resource base units. Only scheduled lines on open projects count; capacity remains the resource total when projectNo filters allocation. Zero capacity is a valid result.

The test extension includes an explicit owned allocation fixture page (97128). It creates unique native resource/project/capacity data and reports the exact keys and expected 8 capacity / 3 allocation / 5 availability. Its cleanup action removes only records that its current instance created and reports the actual remaining count. The fixture performs no financial posting or licence/EULA/trial writes. Fixture creation is setup only; shipping acceptance requires invoking `Projects.ResourceAllocation.Get` through the real queue against the published deployed candidate.

## Purchase links and item usage

`Projects.PurchaseLine.Link` links an unreceived, uninvoiced purchase line to an open, unblocked project task. Select the line by `systemId` or `documentType`, `documentNo` and `lineNo`; supply `projectNo` and `taskNo`. Optional `lineType` accepts `budget`, `billable` or `both`; `planningLineNo` links an existing planning line or clears it with zero. Matching identifiers must refer to the same line. Repeating an unchanged link returns `changed: false`. Nothing is received, invoiced or posted.

`Projects.ItemUsage.Post` posts a nonempty array of positive item quantities to an open, unblocked project task. Each line takes `itemNo`, `quantity` and optional `variantCode`, `locationCode`, `binCode`, `unitOfMeasureCode`, `lotNo` and `serialNo`. Optional `postingDate` defaults to the work date; `documentNo` defaults to a task-specific value. Success returns `firstEntryNo`, `lastEntryNo` and the exact `entryNos`. Posting commits the whole successful task; retries can post again. Native tracking, stock and warehouse rules still apply. Unplanned/overrun usage behavior remains subject to the recorded product decision.

Both types require BIFROST Full and the corresponding native purchase/project/inventory permissions. Generic writes to the purchase line project-link fields are blocked and direct callers to these dedicated messages. Request types and keys are strict; refusals include an actionable `nextStep`.

## Projects.WIPMethod.Get / Projects.WIPMethod.Set (#16)

Version `1.0`, JSON data object; subject is unused. Get is outbound/read-only. Set is inbound and never posts or deletes records.

Get accepts an optional exact `code` (maximum 20 characters). An empty object lists all native WIP methods; an unknown supplied code returns `RecordNotFound`. Set requires a nonempty `code`, creates a missing custom method and updates an existing custom method. Omitted fields preserve their native defaults or existing values.

Optional Set fields: `description` (maximum 100 characters), `recognizedCosts`, `recognizedSales`, `wipCost`, `wipSales`, `valid` (the last three are JSON booleans). Unknown fields, nulls, wrong JSON types, overlong strings and unknown enum names are refused before writes. `systemDefined` is read-only and cannot be supplied.

`recognizedCosts` accepts exact English native enum names: `At Completion`, `Cost of Sales`, `Cost Value`, `Contract (Invoiced Cost)`, `Usage (Total Cost)`. `recognizedSales` accepts `At Completion`, `Contract (Invoiced Price)`, `Usage (Total Cost)`, `Usage (Total Price)`, `Percentage of Completion`, `Sales Value`. Installed native enum extensions are also accepted. These names are independent of session language. Native field validation applies; for example, clearing `wipCost` requires `Usage (Total Cost)` and clearing `wipSales` requires `Contract (Invoiced Price)`.

Success: `{ "status": "Success", "methods": [{ "code": "CUSTOM", "description": "Custom method", "recognizedCosts": "At Completion", "recognizedSales": "At Completion", "wipCost": true, "wipSales": true, "valid": true, "systemDefined": false }] }`. Set returns the single saved method; Get returns the matching method or the list.

System-defined methods and methods referenced by any calculated or posted WIP entry (including reversed posted history) return `PreconditionFailed`. Create a new custom code instead. Native validation failures return `BusinessCentralError` with a localized refusal summary and `nextStep`, preserve the original platform diagnostic separately in `nativeError`, and roll back the entire change. Invalid or missing input returns `InvalidParameterFormat` or `MissingParameter`; Foundation rejects undeclared fields with `UnknownParameter` before the handler executes. Every refusal includes `nextStep`. Discovery, refusal messages and recovery guidance are localized at LCID 1033/1039; help chapters stay English.

Example Set: `{ "code": "CUSTOM", "description": "Custom WIP", "recognizedCosts": "Usage (Total Cost)", "recognizedSales": "Contract (Invoiced Price)", "wipCost": false, "wipSales": false }`. Then Get with `{ "code": "CUSTOM" }`.

Requires enabled Projects setup, Foundation licence/version checks and native WIP Method table permissions; Set additionally requires read permission on WIP Entry and WIP G/L Entry. The Foundation role extensions grant execution of the new codeunits without elevating native table rights. No page or action is changed.


## Projects.PlanningLine.CreatePurchaseOrder

Version 1 takes `projectNo`, optional `taskNo` or `planningLineNos` (exclusive), `preview` (false by default), optional `vendorOverrides` (`planningLineNo`, `vendorNo`) and `expectedCount`. Preview has read effect and rolls back its calculation; create is irreversible and uses the Foundation confirmation gate. `expectedCount` counts proposed planning lines, not orders.

Returns `proposals` (planning line, task, item, variant, location, quantity, vendor and receipt date), `skipped` with reasons, `purchaseOrders` with native task/planning links, and summary counts. Caller-owned pending Order Planning lines cause `PreconditionFailed` before calculation. Unknown selectors/vendors, conflicting task/line selectors, malformed or unknown parameters, missing/stale confirmation and native permissions produce structured refusals with `nextStep`. No posting or new deletion operation. Only this call's scratch lines are consumed.

## Projects.MyDay.Get / Projects.VisitBrief.Get (#82)

Version 1, outbound/read-only, subject unused. Both require BIFROST Read ori + PROJ FIELD TECH and resolve resource ownership from the authenticated BC user. Optional resourceNo disambiguates multiple owned resources; it cannot select another technician. MyDay accepts optional ISO date (today), include array (items/address; default address) and detail full. VisitBrief requires projectNo and taskNo, with optional detail full.

MyDay returns technician{resourceNo,name}, visits[] with project/task/line/date, description, customerName, phone, plannedHours, own date-scoped loggedHours, nullable timeSheetNo/timeSheetLineNo, openUsage and optional address/items; nextVisit is the first ordered visit or null. Brief returns project{}, task{}, site{}, planned{resources[],items[]} with positive remaining quantities, myTime{} (own all-date task total), myUsage[], recordIds{project,task}, empty history[]/followUps[], summary and nextSteps[]. Site is the project's native ship-to snapshot. No feature-app calls, attachment reads, writes or confirmation are involved.

Refusals: MissingParameter, InvalidParameterFormat, UnknownParameter, RecordNotFound, ConflictingIdentifiers, PermissionDenied, PreconditionFailed; each has nextStep. Missing current-week sheets/task lines are Success and offer ready-made Projects.MyTimeSheet.Create / Projects.MyTimeSheetLine.Set parameters, without writing. Native resource units should be hours. Team Member SaaS receipt AC06 is NOT_RUN pending the dedicated user (23 November 2026).
