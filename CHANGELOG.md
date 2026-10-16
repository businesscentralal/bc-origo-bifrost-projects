# Changelog

## 28.1.0.0 - Unreleased

- Fix Claude #17 D1-D3: complete public parameter help (10078489), correct Icelandic
  discovery/help and posting-rights caption, and return localized RecordNotFound for
  unknown BudgetVsActual task (10078511). Add recursive help and bilingual/task-isolation
  regressions (97100, 97108).

- Add Projects company enablement, administrative page, Foundation app registration,
  permission-set extensions and generic setup-write protection (#1; objects 10078485–10078488).
- Register project/task/planning-line create and update, plus planning-line delete,
  with localized discovery and typed nested contracts (#2; enum 10078485, codeunits
  10078489–10078499). Use native field/table triggers and atomic rollback on failure.
- Teach the inherited permission coverage guard to resolve feature extensions of known
  Foundation roles, retaining source-table checks and adding negative self-tests.
- Add native Copy Job options and validated status/blocking messages (#3/#4;
  codeunits 10078500–10078501, enum values 10078492–10078493; tests 97104–97105).
- Preserve temporary test argument blobs before public Foundation reads; scope
  catalogue tests to this app's assigned enum range. Support explicit nested
  Update operations and inherit planning-line task keys from their parent.
- Add WIP Get and native Calculate contracts (#5 partial; codeunits 10078502,
  10078503 and 10078505; enum values 10078494–10078495; test codeunit 97106).
  Add WIP Post with a Projects-owned internal permission token/gate mapped to
  Projects Read/Full extensions (#5/#18; objects 10078504, 10078506–10078507;
  tests 97106–97107). Add nonzero native WIP calculation/posting and gate tests.
- Add native Statistics and BudgetVsActual contracts (#6; objects 10078509–10078511;
  enum values 10078497–10078498; tests 97108). Return LCY cost/price totals and
  type splits using the BC statistics engine, with posting-task breakdown.
- Add Usage Get/Link with exact project/task and identity checks, duplicate-link refusal,
  native remaining-quantity updates and planning-from-usage (#8; objects
  10078512–10078514, enum values 10078499–10078500; tests 97109).
- Add owned native Web Client fixture helpers in the test app only (97110–97111);
  keep shipping licensing and MCP evidence separate.
- Add scaffold, permission, input-boundary and native write component tests
  (test codeunits 97100–97106). Runtime/UI/MCP and independent verification remain pending.

- Repository scaffold from the Bifrost feature-app template (AL-Go, Alpaca shared container, Bifrost pipeline guards).
- Object ranges: app 10078485..10078584, tests 97100..97199.
