# Bifrost Projects

- Namespace: `Origo.Bifrost.Projects`
- Test namespace: `Origo.Bifrost.Projects.Test`
- Object range: 70013500–70013599 (app; upper part of Public 4, Gunnar 12.11.2026, #34). Shopify still uses 70013400–70013481. Tests stay 97100–97199. The previous Public 3 range was 70009200–70009249.
- Foundation dependency: Bifrost Foundation 28.0.5.0
- Permissions: PermissionSetExtension only onto `BIFROST Read ori` / `BIFROST Full ori`
- No own assignable permission set; no `Setup ori` tabledata grants (exception below)

## Deviations

- #38: three role sets for time-sheet self-service, Architect 18.11.2026. `PROJ TS SELF` (70013586), `PROJ TS APPROVER` (70013587) and `PROJ TS POST` (70013588) are assignable, grant indirect tabledata only, and are assigned together with `BIFROST Read ori`. The Read/Full extensions and the ownership checks in code stay.
