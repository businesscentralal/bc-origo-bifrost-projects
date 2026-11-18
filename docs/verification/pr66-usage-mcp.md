# Verify the usage amendment through MCP (PR #66)

| Check | Result |
|---|---|
| Source head | `9d080281118ff6ab4ba0c1386fc9a1bb7fc4d10a` |
| Worker / date | Hár, worker-32 / 18 November 2026 |
| Own tenant | `w129-34`, BC 29 W1, CRONUS International Ltd. |
| Product and test apps | Own builds from the source head, published with Synchronize; each compiled with 0 errors and 0 warnings |
| Paired CI | [Pull Request Build 44346519899](https://github.com/businesscentralal/bc-origo-bifrost-projects/actions/runs/44346519899), green at the source head |
| Finding | [Worker review 6984139986](https://github.com/businesscentralal/bc-origo-bifrost-projects/pull/66#issuecomment-6984139986): missing bilingual MCP checks for five usage types |

All ten checks below passed through the Origo MCP server. Each request used
`data: {}`. The expected BC business response is `Error` with `MissingParameter`
validation errors, rather than a successful write. Register collects six errors;
the other types report one. No business fixtures were required or created.

| Message type | LCID 1033 | LCID 1039 | Missing parameters |
|---|---|---|---|
| `Projects.Usage.Register` | PASS | PASS | `timeSheetNo`, `lineNo`, `type`, `no`, `date`, `quantity` |
| `Projects.Usage.Submit` | PASS | PASS | `timeSheetNo` |
| `Projects.Usage.Approve` | PASS | PASS | `timeSheetNo` |
| `Projects.Usage.Reject` | PASS | PASS | `timeSheetNo` |
| `Projects.Usage.Reverse` | PASS | PASS | `entryNo` |

The exact refusal next step is `Send the missing key.` in 1033 and
`Sendu lykilinn sem vantar.` in 1039. `Help.Implementation.Get` with
`detail: "use"` also succeeded for each type in both languages.

## Reproduce a bounded refusal

```json
{"type":"Projects.Usage.Submit","data":{},"lcid":1039,"async":true}
```

1. Read `get_message_type_help` for the type on your own tenant.
2. Invoke the request above with `invoke_message_type`.
3. Poll `queue_get_status` using the returned ID until it finishes.
4. Check `status: "bc_error"` and the decoded `bcResponse`: `MissingParameter`,
   `parameter: "timeSheetNo"`, `nextStep: "Sendu lykilinn sem vantar."`.

The queued route is used because this local BC server returns a localhost
response URL for synchronous tasks. The MCP client leaves that response as a
task envelope when its configured host differs. The queue status tool resolves
the response against the configured tenant and returns the full business result.
A task envelope alone is not counted as a passing business check.

## Evidence limits

The non-SUPER `PermissionDenied` MCP path is **NOT_RUN**: the available MCP user
is SUPER. These validation refusals do not verify that path. AL test codeunit
97154, `Scenario_65_FullWithoutUsageSet_RefusedNamesProjUsage`, supplies the
separate exact English and Icelandic permission-hint regression.

Earlier Transfer/List MCP rows and time-sheet MCP evidence carry forward;
this verification adds the five missing types. The earlier 120 targeted tests
(97146, 97147, 97150, 97153, 97154) passed with 0 failed and 0 skipped.
UI checks are **NOT_RUN** because the amendment changes no page or action.
Licence-path checks are **NOT_RUN**, as required before release.

This record adds verification evidence only. The permission implementation is
commit `959b6276aa43b5af5c6da1510078f8a668931e58`; the PR's single Current state
comment records the final candidate, CI and handoff status.

Queue and response history is retained as protocol evidence on the own tenant.
An attempted deletion of the initial probe queue was refused by BC because its
licensing usage had not been synchronized. No licensing sync, counter change,
guard change or setup-mode change was performed to remove that history.
