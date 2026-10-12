# Changelog

## 0.1.0

First release.

- `expectAccessible(tester)` fails a widget test with a full, readable report;
  `auditAccessibility(tester)` returns the report without failing.
- Rules: `tap-target`, `missing-label`, `contrast`, `image-label`, `text-scale`,
  `duplicate-label`, `generic-label`, and opt-in `focus-order`.
- Every finding has a severity, rule id, message, fix suggestion, widget type, ancestor path
  and on-screen rect.
- Runs at several text scales (`textScales`, default 100% and 200%) and in extra locales
  (`locales`, `rtl: true`); the same problem is reported once.
- Reports as colored console text, Markdown or JSON.
- Ignores per rule, finder, key or label; severity overrides; `failOn` threshold.
- Example app with an inaccessible screen and its fixed twin.
