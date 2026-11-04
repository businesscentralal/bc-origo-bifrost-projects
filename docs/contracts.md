# Contract errors

Projects message types follow the Foundation contract-error rules (core#711): `InvalidParameterFormat` for wrong-shaped `data` or identifier keys, `MissingParameter` for missing/empty keys, `MultipleErrors` when several values are wrong.

## Purchase links and item usage

`Projects.PurchaseLine.Link` links an unreceived, uninvoiced purchase line to an open, unblocked project task. Select the line by `systemId` or `documentType`, `documentNo` and `lineNo`; supply `projectNo` and `taskNo`. Optional `lineType` accepts `budget`, `billable` or `both`; `planningLineNo` links an existing planning line or clears it with zero. Matching identifiers must refer to the same line. Repeating an unchanged link returns `changed: false`. Nothing is received, invoiced or posted.

`Projects.ItemUsage.Post` posts a nonempty array of positive item quantities to an open, unblocked project task. Each line takes `itemNo`, `quantity` and optional `variantCode`, `locationCode`, `binCode`, `unitOfMeasureCode`, `lotNo` and `serialNo`. Optional `postingDate` defaults to the work date; `documentNo` defaults to a task-specific value. Success returns `firstEntryNo`, `lastEntryNo` and the exact `entryNos`. Posting commits the whole successful task; retries can post again. Native tracking, stock and warehouse rules still apply. Unplanned/overrun usage behavior remains subject to the recorded product decision.

Both types require BIFROST Full and the corresponding native purchase/project/inventory permissions. Generic writes to the purchase line project-link fields are blocked and direct callers to these dedicated messages. Request types and keys are strict; refusals include an actionable `nextStep`.
