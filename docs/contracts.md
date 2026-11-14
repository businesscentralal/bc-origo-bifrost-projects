# Contract errors

Projects message types follow the Foundation contract-error rules (core#711): `InvalidParameterFormat` for wrong-shaped `data` or identifier keys, `MissingParameter` for missing/empty keys, `MultipleErrors` when several values are wrong.

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
