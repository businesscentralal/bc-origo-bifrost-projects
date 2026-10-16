# Changelog

## 28.1.0.0 - Unreleased

- Add Projects company enablement, administrative page, Foundation app registration,
  permission-set extensions and generic setup-write protection (#1; objects 10078485–10078488).
- Register project/task/planning-line create and update, plus planning-line delete,
  with localized discovery and typed nested contracts (#2; enum 10078485, codeunits
  10078489–10078499). Use native field/table triggers and atomic rollback on failure.
- Teach the inherited permission coverage guard to resolve feature extensions of known
  Foundation roles, retaining source-table checks and adding negative self-tests.
- Add scaffold, permission, input-boundary and native write component tests
  (test codeunits 97100–97103). Runtime/UI/MCP and independent verification remain pending.

- Repository scaffold from the Bifrost feature-app template (AL-Go, Alpaca shared container, Bifrost pipeline guards).
- Object ranges: app 10078485..10078584, tests 97100..97199.
