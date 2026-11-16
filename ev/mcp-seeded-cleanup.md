# Self-seeded MCP run at ee90b8a (w129-36, 1033 + 1039)
- Seed: project X42MCP049572 created through REST api/v2.0 projects (HTTP 201).
- 12/12 scenario checks passed (mcp-seeded.json): for each irreversible type, expectedCount 0 on the seeded project gives ConfirmationMismatch, expected 1, naming the project. With expectedCount 1, ItemUsage.Post and Quote.Send pass the gate and reach their own refusal; nothing is posted or sent. Usage.Link is not gated.
- The "seed" and "cleanup" rows in mcp-seeded.json say false because the script did not read the id from the 201 response, so its DELETE did not run. Cleanup was then done by hand: GET projects startswith(number,'X42MCP') found id 3d2a0d78-a6e1-f111-b6fb-00090ffe0001, and DELETE returned 204.
- Remaining after cleanup (cleanup-counts.txt): Job, Job Ledger Entry, Job Task, Job Planning Line, Job WIP Entry and Job WIP G/L Entry each have 0 rows for X42MCP*.
