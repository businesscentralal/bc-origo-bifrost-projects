# Contract errors

Projects message types follow the Foundation contract-error rules (core#711): `InvalidParameterFormat` for wrong-shaped `data` or identifier keys, `MissingParameter` for missing/empty keys, `MultipleErrors` when several values are wrong.

## Resource allocation

`Projects.ResourceAllocation.Get` is read-only. Required data keys: `periodType` (`day`, `week`, `month`, `quarter`, `year`), `fromDate`, `toDate` (inclusive ISO dates). Optional exact `projectNo`, `resourceNo`, `resourceGroupNo` combine; conflicting resource/group selectors are refused. At most 53 calendar periods are accepted. Rows contain resourceNo, fromDate, toDate, capacity, allocated, availability and per-project allocated quantities in resource base units. Only scheduled lines on open projects count; capacity remains the resource total when projectNo filters allocation. Zero capacity is a valid result.

The test extension includes an explicit owned allocation fixture page (97128). It creates unique native resource/project/capacity data and reports the exact keys and expected 8 capacity / 3 allocation / 5 availability. Its cleanup action removes only records that its current instance created and reports the actual remaining count. The fixture performs no financial posting or licence/EULA/trial writes. Fixture creation is setup only; shipping acceptance requires invoking `Projects.ResourceAllocation.Get` through the real queue against the published deployed candidate.
