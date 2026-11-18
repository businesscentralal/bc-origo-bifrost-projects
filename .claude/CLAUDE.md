# Bifrost Projects

- Namespace: `Origo.Bifrost.Projects`
- Test namespace: `Origo.Bifrost.Projects.Test`
- Object range: 70013400–70013599 (app; whole Public 4 block, Gunnar 12.11.2026 #34, widened for #52 after Shopify left; usage objects take 70013400–70013499). Tests stay 97100–97199. The previous Public 3 range was 70009200–70009249.
- Foundation dependency: Bifrost Foundation 28.0.5.0
- Permissions: PermissionSetExtension only onto `BIFROST Read ori` / `BIFROST Full ori`
- No own assignable permission set; no `Setup ori` tabledata grants (exception below)

## Deviations

- #33 admin time-sheet types need PROJ TS ADMIN for Base App tabledata (AS0110 fix, Architect 18.11.2026). `PROJ TS ADMIN` (permission set 70013589) is assignable and is assigned together with `BIFROST Full ori`. It holds the 27 Base Application tabledata grants and the `Create Time Sheets` report grant that `Projects TimeSheet Full ori` had, at the same levels; the extension keeps only this app's codeunits (#65).
- #52 usage types need PROJ USAGE for Base App tabledata (same AS0110 fix, Architect 18.11.2026, PR #66 comment 6980138913). `PROJ USAGE` (permission set 70013402) is assignable and is assigned together with `BIFROST Full ori` (or `BIFROST Read ori` for `Projects.Usage.List`). It holds the 16 Base Application tabledata grants that `Projects Usage Full ori` and `Projects Usage Read ori` had, at the same levels; both extensions keep only this app's objects. No Base App grant lives in a permission set extension anywhere in Projects.
