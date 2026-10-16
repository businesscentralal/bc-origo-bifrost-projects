# Bifrost Projects

Bifrost feature app for project (job) message types that are not covered by Bifrost Foundation: project lifecycle, tasks and planning lines, copy, status, prices, WIP, budget vs actual, project invoicing helpers and project queries. Message types use the `Projects.*.*` pattern.

Time sheets and the Clockify sync belong to **Bifrost Timesheets** (businesscentralal/bc-origo-bifrost-timesheets), not here. Project journal and project-to-sales-invoice/credit-memo types live in **Bifrost Foundation**.

- Depends only on Bifrost Foundation.
- Object range: 10078485..10078584 (app), 97100..97199 (tests).

## Message types

| Type | Data | Result |
| --- | --- | --- |
| `Projects.Project.Create` | `projectNo`, optional fields, `tasks[]` | Creates a project and optional nested tasks/planning lines atomically. |
| `Projects.Project.Update` | `projectNo`, changed fields, optional new `tasks[]` | Updates supplied fields and creates supplied nested records. |
| `Projects.Task.Create` | `projectNo`, `taskNo`, fields, `planningLines[]` | Creates a task and optional planning lines. |
| `Projects.Task.Update` | `projectNo`, `taskNo`, changed fields, optional new `planningLines[]` | Updates a task; preserves omitted fields. |
| `Projects.PlanningLine.Create` | `projectNo`, `taskNo`, positive `lineNo`, fields | Creates a native resource, item, G/L account or text planning line. |
| `Projects.PlanningLine.Update` | `projectNo`, `taskNo`, `lineNo`, changed fields | Updates supplied native fields. |
| `Projects.PlanningLine.Delete` | `projectNo`, `taskNo`, `lineNo` | Deletes through native BC checks. |

Calls use version `1.0` and a JSON object in `data`; `subject` is not used.
All writes require the native BC table permissions in addition to the Foundation role.
Projects Setup is a company-wide switch; generic `Data.Records.Set` cannot change it.

See [Projects contracts](docs/projects.md) for fields, nested behavior and errors.

## Delivery status

Scaffold and lifecycle implementation are under development. Native component tests
are separate from queue API, licensing, bilingual Web Client and MCP acceptance.
Template/workflow restoration is retained by human PR #10. Issues #3–#8 remain
pending; tracking issue #9 does not authorize more message types.
