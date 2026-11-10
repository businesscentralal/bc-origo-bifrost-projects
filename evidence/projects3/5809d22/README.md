# Projects issue 3 verification at 5809d22

Source candidate: `5809d22ab818ff2e9718f01d62bf3f6dd638d61e`, PR #23, branch `feat/projects-project-copy`.

Lóni (worker-10) compiled and deployed this candidate on 10 November 2026 to owned local BC29 tenant `w129-20`, CRONUS International Ltd. Projects and Tests version 28.1.0.0. Downloaded deployed package hashes equal the freshly compiled packages, whose manifests embed the full candidate SHA. Foundation28.0.13.0 at `eda637586a4b94bad5b83cc2de191dea8b98fde4` was already installed and reused. No EULA/trial/licence/backend writes were made in this verification.

| Verification | Actual result |
|---|---|
| Product CodeCop/UICop/AppSourceCop | 0 errors, 0 warnings |
| Configured PTE test CodeCop/UICop | 0 errors, 0 warnings; retained scoped PR22 analyzer disposition |
| Full Projects AL suite, mode local | 61 executed / 61 passed / 0 failed / 0 skipped / 0 errors |
| MCP acceptance | 24 checks / 24 passed / 0 failed / 0 skipped, LCIDs1033 and1039 |
| Playwright MCP Web Client | 8 scenarios / 8 passed / 0 failed / 0 skipped, LCIDs1033 and1039 |
| Exact-tip paired CI42799591898 | Default/Test/final cleanup success; downloaded TestResults.xml recounted61/61/0/0 |
| Owned cleanup | All13 checked fixture tables empty; both Projects apps uninstalled with deleteExtensionData and unpublished204, then absent on Automation API readback |

MCP includes public queue-backed localized discovery, copy success, existing-target, reversed-range, invalid-customer, unknown-key and missing-key responses; direct implementation help and readback assertions supplement these. All customer/resource/project/task/planning/dimension/posting fixtures were self-created. Copy defaults retain Budget line quantity3/unitCost7/unitPrice11 and default dimension; Billable copy with quantity/prices/dimensions false returns zero quantity/price and no default dimension. Source planning rows remain identical; failed targets are absent. The24 count includes discovery/help and data assertions, not24 copy requests. Permission denial is in the61 native tests; no restricted-user MCP pass is claimed.

UI verifies the copied header/Budget Cost21, exactly taskX100 (X200 excluded), one Budget planning line quantity3/cost7/price11/amount33, and localized Projects Setup in each actual language session. Icelandic was selected through My Settings; `html lang=is-IS`, Icelandic shell and product labels were observed. W1 native Project/Job captions remain English, so this does not claim Icelandic Base Application translation. English was restored and verified. The prior URL-language-only limitation is resolved by the actual settings workflow.

Gateway diff scan: one changed production AL file,22passing checks and1failed version-heading detector. Actual unbracketed `##28.1.0.0 - Unreleased` contains the issue entry. The script's summary incorrectly says2failed while its check map has1; raw report retained. No code was changed to suppress a check. Prior wider advisories remain: context-help pages were not reverified; CHANGELOG omits test fixture page97114; the fixture page has no built-in cleanup (exact-manifest cleanup was executed separately). No new production strings or public contract changes. Production range70009200..70009249/tests97100..97199 is the current repository allocation.

This evidence commit contains verification artifacts only. The PR source SHA stays5809d22. Independent exact-tip Claude verification, Grok clearance, eligible non-author approval, Architect merge/deployment and Tester UAT remain separate stages. This is not issue completion.
