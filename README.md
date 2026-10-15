[العربية](README.ar.md)

<p align="center"><img src="https://raw.githubusercontent.com/youssef336/flutter_a11y_check/main/screenshots/banner.png" alt="flutter_a11y_check banner" width="100%"></p>

<h1 align="center">flutter_a11y_check</h1>

<p align="center">
  One line in a widget test audits a whole screen for accessibility and prints a report you can actually act on.
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_a11y_check"><img src="https://img.shields.io/pub/v/flutter_a11y_check?style=for-the-badge&logo=dart&label=pub.dev" alt="pub.dev"/></a>
  <img src="https://img.shields.io/badge/Flutter-%E2%89%A53.35-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%5E3.9-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/WCAG-2.x%20AA%20%2F%20AAA-6A1B9A?style=for-the-badge" alt="WCAG">
  <img src="https://img.shields.io/badge/Tests-flutter__test-2ea44f?style=for-the-badge" alt="Tests">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT">
</p>

> **English summary.** `flutter_a11y_check` is a dev dependency for widget tests. After you pump a
> screen, `await expectAccessible(tester)` checks it for tap targets under 48x48 (or 44x44 on
> iOS), tappable widgets with no label, text contrast below WCAG AA/AAA measured from the
> rendered frame, images with no `semanticLabel`, layouts that overflow, cut text or ignore the
> setting at 200% font size, repeated or meaningless labels ("Remove" x3, "Click here"), and,
> if you turn it on, screen-reader order that jumps against the visual (RTL-aware) order. It
> collects **every** violation, not only the first, and each finding comes with a severity,
> a rule id, the widget and its ancestor path (`BadScreen > Scaffold > AppBar > IconButton`),
> its rect, the measured values and a concrete fix. The report prints as colored console
> text, Markdown (for PR comments) or JSON (for CI). You can ignore findings by rule, finder,
> key or label, run at several text scales and in RTL, and choose which severity fails the
> test. It builds on the logic of `flutter_test`'s `androidTapTargetGuideline`,
> `labeledTapTargetGuideline` and `textContrastGuideline`, and adds the rest.

One line inside a widget test audits the whole screen for accessibility. Instead of the terse
`meetsGuideline` message that stops at the first mistake, you get a report with every problem: the
widget, its place in the tree, its size, the measured values, and how to fix it.

## ✨ What it does

```dart
testWidgets('login is accessible', (tester) async {
  await tester.pumpWidget(const MyApp());
  await expectAccessible(tester);                   // بيفشل التست ومعاه التقرير كامل
});
```

Or, if you want the report without failing the test:

```dart
final report = await auditAccessibility(tester);
debugPrint(report.toMarkdown());                    // أو toText() أو toJsonString()
```

| Rule | Severity | What it catches |
|---|---|---|
| `tap-target` | 🔴 error | Anything tappable smaller than 48x48 (or 44x44 with `minTapTarget: 44`) |
| `missing-label` | 🔴 error | An `IconButton` with no `tooltip`, or a `GestureDetector`/`InkWell` around an icon or image with no `Semantics` |
| `contrast` | 🔴 error | Text whose contrast is below WCAG AA (4.5:1 for normal text, 3:1 for large), measured from the image that was actually rendered |
| `image-label` | 🟡 warning | An `Image` with no `semanticLabel` that is not marked as decorative (`excludeFromSemantics`) |
| `text-scale` | 🔴 / 🟡 | The screen breaks at 200%: overflow, text that gets cut (ellipsis), or text that does not grow at all |
| `duplicate-label` | 🟡 warning | Several buttons on the same screen with the same name (three "Remove" buttons) |
| `generic-label` | 🟡 warning | A label that says nothing: "Button", "Icon", "Click here" |
| `focus-order` | 🔵 info | (Optional) the screen reader / switch access order jumps backwards against the reading order; RTL-aware |

- 🧭 **Every finding** has: a severity, a rule id, a message in English, a fix suggestion, the widget
  type, its path (`BadScreen > Scaffold > AppBar > IconButton`), the rect, and the values (size,
  contrast ratio, colors, suggested color).
- 🔁 **It runs over several states**: every entry in `textScales` (by default 100% and 200%), every
  extra locale, and `rtl: true`. The same problem, if it shows up in more than one state, is written
  once, with a note of where it appeared.
- 🙈 **Ignore** by rule, by `Finder`, by `Key`, or by label.
- 🎨 **The report**: colored text for the console, Markdown for a PR comment, and JSON for CI.
- ♻️ It restores the text scale and the locale to what they were after the audit.

## 📦 Installation

From GitHub as a git dependency in `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_a11y_check: ^0.1.1
```

Then `flutter pub get`, and `import 'package:flutter_a11y_check/flutter_a11y_check.dart';` in the
test.

## ⚙️ Configuration

```dart
await expectAccessible(
  tester,
  config: A11yConfig(
    minTapTarget: A11yConfig.iosTapTarget,      // 44 (الافتراضي 48 بتاع Android)
    contrast: ContrastLevel.aa,                 // aa | aaa | off
    textScales: [1.0, 1.5, 2.0],                // 1.0 بيتضاف دايمًا
    rtl: true,                                  // يعيد الفحص بـ Locale('ar')
    rules: {...A11yRule.defaults, A11yRule.focusOrder},
    failOn: A11ySeverity.error,                 // الافتراضي warning
    severityOverrides: {A11yRule.imageLabel: A11ySeverity.error},
    ignoreRules: {A11yRule.genericLabel},
    ignore: [
      A11yIgnore.key(const Key('brand-logo'), rules: {A11yRule.imageLabel}),
      A11yIgnore.finder(find.byType(GoogleMap), reason: 'third-party view'),
      A11yIgnore.label('Remove', rules: {A11yRule.duplicateLabel}),
    ],
    pathLandmarks: {'ProductCard'},             // يظهر في الـ path
    colors: false,                              // من غير ANSI
  ),
);
```

## 🧾 What the report looks like

This is part of the report for the bad screen in `example/` (with `toText(color: false)`):

```text
Accessibility audit FAILED: 6 errors, 5 warnings, 0 info
runs: 100%, 200%, 100% ar (rtl), 200% ar (rtl)

ERROR  tap-target  GestureDetector is 24x24, smaller than the 48x48 minimum tap target.
       where BadScreen > Scaffold > ListView > Row > GestureDetector
       rect  (80, 188) 24x24 at 100%
       fix   Give the tappable area at least 48x48: add padding inside the gesture detector or wrap it in ConstrainedBox(constraints: BoxConstraints(minWidth: 48, minHeight: 48)).

ERROR  missing-label  IconButton can be tapped but has no label, so a screen reader announces only "button" (or nothing).
       where BadScreen > Scaffold > AppBar > Row > IconButton
       rect  (752, 4) 48x48 at 100%
       fix   Add tooltip: 'Describe the action' - Flutter uses the tooltip as the label.

ERROR  contrast  "Prices include VAT" has contrast 1.79:1 (#BDBDBD on #FEF7FF); WCAG AA needs 4.5:1 for normal text (14px).
       where BadScreen > Scaffold > ListView > Text
       rect  (16, 148) 768x20 at 100%
       fix   Use #737373 (or darker/stronger) for the text, or change the background, or make the text large (24px+, or 18.66px+ bold).

ERROR  text-scale  Breaks at 200% font size: Row overflows (A RenderFlex overflowed by 350 pixels on the right.).
       where BadScreen > Scaffold > ListView > Row
       rect  (16, 72) 768x40 at 200%
       fix   Wrap the text children in Expanded/Flexible so they can wrap, or switch to Wrap when the content does not fit on one line.

WARN   duplicate-label  3 tappable TextButton widgets on this screen are all labelled "Remove"; screen-reader users cannot tell them apart.
       where BadScreen > Scaffold > ListView > Row > TextButton
       rect  (675.4, 224) 108.6x48 at 100%
       also  BadScreen > Scaffold > ListView > Row > TextButton
       also  BadScreen > Scaffold > ListView > Row > TextButton
       fix   Make each label unique by adding context, e.g. 'Delete Invoice #12', or merge the repeated controls into one.
```

## 🧪 The example

`example/` contains an app with two screens: `BadScreen` has an example of every problem, and
`GoodScreen` is the same screen after the fixes. The tests in `example/test/rules_test.dart` prove
that every rule catches the bad screen, and that the good screen passes every rule at 100% and 200%
and in Arabic RTL.

```bash
cd example && flutter test
```

## ❓ FAQ

**Why not just `meetsGuideline`?**
`meetsGuideline` tells you "there is a problem" and gives you `SemanticsNode#42` and a size. Here you
get all the problems at once, with the widget by name, its place in the tree, and the fix. And there
are rules that do not exist there: images, 200%, duplicate names, and focus order.

**Did the test get slower?**
Every state (scale × locale) does a pump and an image of the screen for the contrast check. If you
want it faster: `textScales: [1.0]` or `contrast: ContrastLevel.off`.

**RTL does not work?**
The audit only changes the test platform's locale. The app must have `Locale('ar')` in
`supportedLocales` together with `GlobalMaterialLocalizations.delegates`. If the screen stays LTR,
the report tells you in `notes` and does not repeat the same audit for nothing.

**I have an acceptable warning (like "Delete" on every row in a list)?**
`A11yIgnore.label('Delete', rules: {A11yRule.duplicateLabel})`, or `failOn: A11ySeverity.error` so
warnings show up without failing the test.

**Does it work with Cupertino?**
Yes, all the rules work on the semantics tree and the render tree, not on Material only. For iOS use
`minTapTarget: A11yConfig.iosTapTarget`.

## ⚖️ Limitations

- Contrast is measured from the image rendered in the test. The test font draws boxes, so the result
  is accurate for the text color against the background, but it does not see the real font's
  anti-aliasing. And if the text is over an image or a gradient, the background is taken from the
  most common color around the text.
- "Large text" per WCAG: 24px, or 18.66px if bold (after scaling). That is a bit stricter than
  `flutter_test`, which treats 18px as large.
- `text-scale` sees the overflow that Flutter reports (`RenderFlex overflowed`) and text cut by
  `maxLines`. Text cut by a `ClipRect` or a fixed-height container without an error does not show up.
  And each `RenderFlex` reports its overflow only once, so it is recorded at the first scale that
  broke it.
- The widget path is approximate: it shows well-known widgets (Scaffold, AppBar, Row …) and any widget
  whose name ends in `Screen`/`Page`/`View`/`Dialog`/`Sheet`. Add your own names in `pathLandmarks`.
- `focus-order` compares the semantics order (the one TalkBack / VoiceOver / switch access use) with
  the reading order, and does not read the keyboard's `FocusTraversalPolicy`. It is info and
  optional because designs with side-by-side columns can produce intentional findings.
- It does not check: labels in the app's language, live regions, custom actions, or the contrast of
  icons and non-text elements (WCAG 1.4.11).

## 🛠 Tech stack

- Dart + Flutter, depends only on the Flutter SDK (`flutter`, `flutter_test`).
- Reads the semantics tree, the element/render trees, and the rendered frame (`OffsetLayer.toImage`)
  inside the normal `flutter test` environment; no golden files, no device.
- Tap-target, label and contrast logic adapted from `flutter_test`'s accessibility guidelines.

## 🏗 Project structure

| File | Role |
|---|---|
| `lib/flutter_a11y_check.dart` | public API |
| `lib/src/audit.dart` | `auditAccessibility` / `expectAccessible`, runs per text scale and locale, ignores, dedupe |
| `lib/src/config.dart` | `A11yConfig`, `ContrastLevel` |
| `lib/src/finding.dart`, `lib/src/report.dart` | findings, rules, severities; text / Markdown / JSON report |
| `lib/src/contrast.dart` | WCAG luminance and ratio, pixel histogram, suggested color |
| `lib/src/context.dart`, `lib/src/widget_path.dart` | semantics node → widget, ancestor paths, merged gestures |
| `lib/src/rules/` | one file per rule family |
| `example/` | bad and good checkout screens + tests for every rule |
| `test/` | unit tests: contrast math, report formatting, ignores, config |

## 🚀 Getting started

```bash
git clone https://github.com/youssef336/flutter_a11y_check.git
cd flutter_a11y_check
flutter pub get
flutter test                    # package tests
cd example && flutter test      # every rule on the bad screen, nothing on the good one
```

## 📄 License

[MIT](LICENSE)

## 👤 Author

**Youssef Belal Zakaria** · [GitHub @youssef336](https://github.com/youssef336)

⭐ If you like this project, give it a star!
