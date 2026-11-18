# Bifrost Projects

- Namespace: `Origo.Bifrost.Projects`
- Test namespace: `Origo.Bifrost.Projects.Test`
- Object range: 70013500–70013599 (app; upper part of Public 4, Gunnar 12.11.2026, #34). Shopify still uses 70013400–70013481. Tests stay 97100–97199. The previous Public 3 range was 70009200–70009249.
- Foundation dependency: Bifrost Foundation 28.0.5.0
- Permissions: PermissionSetExtension only onto `BIFROST Read ori` / `BIFROST Full ori`
- No own assignable permission set; no `Setup ori` tabledata grants (exception below)

## Deviations

- #33 admin time-sheet types need PROJ TS ADMIN for Base App tabledata (AS0110 fix, Architect 18.11.2026). `PROJ TS ADMIN` (permission set 70013589) is assignable and is assigned together with `BIFROST Full ori`. It holds the 27 Base Application tabledata grants and the `Create Time Sheets` report grant that `Projects TimeSheet Full ori` had, at the same levels; the extension keeps only this app's codeunits (#65).
