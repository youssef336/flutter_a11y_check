[English](README.md)

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

<div dir="rtl">

سطر واحد جوه الـ widget test بيفحص الشاشة كلها من ناحية الـ accessibility، وبدل
رسالة `meetsGuideline` المختصرة اللي بتقف عند أول غلطة، بيطلعلك تقرير فيه كل
المشاكل: الويدجت، ومكانه في الشجرة، ومقاسه، والأرقام اللي اتقاست، وتصلّحها إزاي.

## ✨ بيعمل إيه

```dart
testWidgets('login is accessible', (tester) async {
  await tester.pumpWidget(const MyApp());
  await expectAccessible(tester);                   // بيفشل التست ومعاه التقرير كامل
});
```

أو لو عايز التقرير من غير ما التست يفشل:

```dart
final report = await auditAccessibility(tester);
debugPrint(report.toMarkdown());                    // أو toText() أو toJsonString()
```

| القاعدة | الخطورة | بتمسك إيه |
|---|---|---|
| `tap-target` | 🔴 error | أي حاجة بتتداس أصغر من 48x48 (أو 44x44 لو `minTapTarget: 44`) |
| `missing-label` | 🔴 error | `IconButton` من غير `tooltip`، أو `GestureDetector`/`InkWell` حوالين أيقونة أو صورة من غير `Semantics` |
| `contrast` | 🔴 error | نص التباين بتاعه أقل من WCAG AA (4.5:1 للنص العادي، 3:1 للكبير)، متقاس من الصورة اللي اترسمت فعلًا |
| `image-label` | 🟡 warning | `Image` من غير `semanticLabel` ومش متعلّمة إنها ديكور (`excludeFromSemantics`) |
| `text-scale` | 🔴 / 🟡 | الشاشة بتتكسر على 200%: overflow، أو نص بيتقص (ellipsis)، أو نص مش بيكبر خالص |
| `duplicate-label` | 🟡 warning | كذا زرار على نفس الشاشة اسمهم واحد (تلات زراير «Remove») |
| `generic-label` | 🟡 warning | label مبيقولش حاجة: «Button»، «Icon»، «Click here» |
| `focus-order` | 🔵 info | (اختياري) ترتيب الـ screen reader / switch access بيرجع لورا عكس ترتيب القراية، ويعرف الـ RTL |

- 🧭 **كل finding** فيه: severity، و rule id، ورسالة بالإنجليزي، واقتراح تصليح، ونوع الويدجت،
  والـ path بتاعه (`BadScreen > Scaffold > AppBar > IconButton`)، والـ rect، والأرقام (المقاس،
  نسبة التباين، الألوان، اللون المقترح).
- 🔁 **بيلف على أكتر من حالة**: كل `textScales` (الافتراضي 100% و 200%)، وكل locale إضافي، و `rtl: true`.
  نفس المشكلة لو ظهرت في أكتر من حالة بتتكتب مرة واحدة، ومكتوب جنبها ظهرت فين.
- 🙈 **تجاهل** بالقاعدة، أو بـ `Finder`، أو بـ `Key`، أو بالـ label.
- 🎨 **التقرير**: نص ملوّن للـ console، و Markdown لكومنت الـ PR، و JSON للـ CI.
- ♻️ بيرجّع الـ text scale والـ locale زي ما كانوا بعد الفحص.

## 📦 التسطيب

من GitHub كـ git dependency في `dev_dependencies`:

</div>

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_a11y_check: ^0.1.1
```

<div dir="rtl">

وبعدين `flutter pub get`، و `import 'package:flutter_a11y_check/flutter_a11y_check.dart';` في التست.

## ⚙️ الإعدادات

</div>

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

<div dir="rtl">

## 🧾 شكل التقرير

ده جزء من التقرير بتاع الشاشة الوحشة اللي في `example/` (بالـ `toText(color: false)`):

</div>

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

<div dir="rtl">

## 🧪 المثال

`example/` فيه app بشاشتين: `BadScreen` فيها مثال لكل مشكلة، و `GoodScreen` نفس الشاشة بعد
التصليح. التستات في `example/test/rules_test.dart` بتثبت إن كل قاعدة بتمسك الشاشة الوحشة،
وإن الشاشة الكويسة بتعدّي كل القواعد على 100% و 200% وبالعربي RTL.

```bash
cd example && flutter test
```

## ❓ أسئلة

**ليه مش `meetsGuideline` وخلاص؟**
`meetsGuideline` بيقولك «فيه مشكلة» ويديك `SemanticsNode#42` ومقاس. هنا بتاخد كل المشاكل
مرة واحدة، والويدجت باسمه ومكانه في الشجرة، والتصليح. وفيه قواعد مش موجودة هناك: الصور، والـ
200%، والأسماء المكررة، وترتيب الـ focus.

**التست بقى أبطأ؟**
كل حالة (scale × locale) بتعمل pump وصورة للشاشة عشان التباين. لو عايز أسرع:
`textScales: [1.0]` أو `contrast: ContrastLevel.off`.

**الـ RTL مش بيشتغل؟**
الفحص بيغيّر الـ locale بتاع الـ test platform بس. لازم الـ app يكون فيه `Locale('ar')` في
`supportedLocales` ومعاه `GlobalMaterialLocalizations.delegates`. لو الشاشة فضلت LTR، التقرير
بيقولك في `notes` ومش بيعيد نفس الفحص على الفاضي.

**عندي warning مقبول (زي «Delete» في كل صف في لستة)؟**
`A11yIgnore.label('Delete', rules: {A11yRule.duplicateLabel})`، أو
`failOn: A11ySeverity.error` عشان الـ warnings تظهر من غير ما تفشّل التست.

**هل بيشتغل مع Cupertino؟**
أيوه، القواعد كلها على الـ semantics tree والـ render tree، مش على Material بس.
للـ iOS استخدم `minTapTarget: A11yConfig.iosTapTarget`.

## ⚖️ الحدود

- التباين بيتقاس من الصورة اللي اترسمت في التست. خط التست بيرسم مربعات، فالنتيجة دقيقة للون
  النص على الخلفية، بس مش بتشوف anti-aliasing الخط الحقيقي. ولو النص فوق صورة أو gradient،
  الخلفية بتتاخد من أكتر لون حوالين النص.
- «نص كبير» حسب WCAG: 24px، أو 18.66px لو bold (بعد الـ scale). ده أشد شوية من `flutter_test`
  اللي بيعتبر 18px كبير.
- الـ `text-scale` بيشوف الـ overflow اللي Flutter بيبلّغ عنه (`RenderFlex overflowed`) والنص
  اللي اتقص بـ `maxLines`. نص بيتقص بـ `ClipRect` أو container ارتفاعه ثابت من غير error مش
  بيبان. وكل `RenderFlex` بيبلّغ عن الـ overflow مرة واحدة بس، فبيتكتب عند أول scale كسرته.
- الـ widget path تقريبي: بيعرض widgets معروفة (Scaffold، AppBar، Row …) وأي widget اسمه
  بيخلص بـ `Screen`/`Page`/`View`/`Dialog`/`Sheet`. ضيف أسماءك في `pathLandmarks`.
- `focus-order` بيقارن ترتيب الـ semantics (اللي بيستخدمه TalkBack / VoiceOver / switch access)
  بترتيب القراية، ومش بيقرا `FocusTraversalPolicy` بتاع الكيبورد. وهو info واختياري لإن
  التصميمات اللي فيها أعمدة جنب بعض ممكن تطلّع ملاحظات مقصودة.
- مش بيفحص: الـ labels بلغة الـ app، ولا الـ live regions، ولا الـ custom actions، ولا تباين
  الأيقونات والعناصر اللي مش نص (WCAG 1.4.11).

</div>

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
