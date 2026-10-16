# Changelog

## 28.1.0.0 - Unreleased

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
  WIP Post is not registered: supported Foundation posting-gate dependency is #18.
  Nonzero WIP and shipping acceptance remain pending.
- Add scaffold, permission, input-boundary and native write component tests
  (test codeunits 97100–97106). Runtime/UI/MCP and independent verification remain pending.

- Repository scaffold from the Bifrost feature-app template (AL-Go, Alpaca shared container, Bifrost pipeline guards).
- Object ranges: app 10078485..10078584, tests 97100..97199.
