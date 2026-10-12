import 'package:flutter/widgets.dart';

/// A widget named for humans: its type and a short ancestor path.
@immutable
class WidgetDescription {
  /// Creates a description.
  const WidgetDescription({required this.widget, required this.path, this.element});

  /// Widget type, e.g. `IconButton`.
  final String widget;

  /// Ancestor path, e.g. `LoginScreen > Scaffold > AppBar > IconButton`.
  final String path;

  /// The element described.
  final Element? element;
}

/// Turns elements into readable names and paths.
abstract final class WidgetPaths {
  /// Widgets users recognise as "the thing" a semantics node is about.
  static const Set<String> controls = <String>{
    'IconButton',
    'ElevatedButton',
    'FilledButton',
    'OutlinedButton',
    'TextButton',
    'FloatingActionButton',
    'BackButton',
    'CloseButton',
    'DrawerButton',
    'EndDrawerButton',
    'Checkbox',
    'Switch',
    'Radio',
    'Slider',
    'RangeSlider',
    'ListTile',
    'CheckboxListTile',
    'SwitchListTile',
    'RadioListTile',
    'ExpansionTile',
    'Chip',
    'ActionChip',
    'ChoiceChip',
    'FilterChip',
    'InputChip',
    'PopupMenuButton',
    'PopupMenuItem',
    'DropdownButton',
    'DropdownMenu',
    'MenuItemButton',
    'SegmentedButton',
    'TextField',
    'TextFormField',
    'Tab',
    'NavigationDestination',
    'CupertinoButton',
    'CupertinoSwitch',
    'Image',
    'Text',
    'Icon',
  };

  /// Low-level gesture widgets, used when no [controls] widget is found.
  static const Set<String> gestures = <String>{
    'InkWell',
    'InkResponse',
    'GestureDetector',
    'RawMaterialButton',
    'MaterialButton',
    'RawGestureDetector',
  };

  /// Layout and structure widgets worth showing in a path.
  static const Set<String> landmarks = <String>{
    'Scaffold',
    'AppBar',
    'SliverAppBar',
    'BottomAppBar',
    'BottomNavigationBar',
    'NavigationBar',
    'NavigationRail',
    'NavigationDrawer',
    'Drawer',
    'TabBar',
    'Dialog',
    'AlertDialog',
    'SimpleDialog',
    'BottomSheet',
    'Card',
    'ListTile',
    'ListView',
    'GridView',
    'PageView',
    'CustomScrollView',
    'SingleChildScrollView',
    'Row',
    'Column',
    'Stack',
    'Wrap',
    'Form',
    'Table',
    'Toolbar',
    'CupertinoNavigationBar',
    'CupertinoPageScaffold',
    'CupertinoTabBar',
  };

  static const List<String> _screenSuffixes = <String>['Screen', 'Page', 'View', 'Dialog', 'Sheet'];

  static const Set<String> _notScreens = <String>{'View', 'RawView', 'ScrollView', 'PageView'};

  /// `IconButton` for an `IconButton` widget, `Foo` for `Foo<int>`.
  static String nameOf(Widget widget) {
    final String raw = widget.runtimeType.toString();
    final int generic = raw.indexOf('<');
    return generic < 0 ? raw : raw.substring(0, generic);
  }

  static bool _isLandmark(String name, Set<String> extra) {
    if (name.startsWith('_')) {
      return false;
    }
    if (landmarks.contains(name) || extra.contains(name)) {
      return true;
    }
    if (_notScreens.contains(name)) {
      return false;
    }
    return _screenSuffixes.any(name.endsWith);
  }

  static Rect? _rectOf(Element element) {
    final RenderObject? ro = element.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
  }

  static bool _within(Rect inner, Rect outer) =>
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;

  /// Describes [element].
  ///
  /// With [exact] the element itself is the subject. Otherwise the subject is the most
  /// recognisable widget around it (an `IconButton` rather than the `Semantics` inside it) that
  /// still fits [nodeRect] (plus a 12px margin, so padded buttons are found).
  static WidgetDescription describe(
    Element element, {
    Rect? nodeRect,
    Set<String> landmarks = const <String>{},
    bool exact = false,
  }) {
    Element subject = element;
    if (!exact) {
      final Rect? limit = nodeRect?.inflate(12);
      Element? control;
      Element? gesture;
      Element? public;
      var depth = 0;
      void consider(Element e) {
        final String name = nameOf(e.widget);
        if (controls.contains(name)) {
          control = e;
        } else if (gesture == null && gestures.contains(name)) {
          gesture = e;
        } else if (public == null && !name.startsWith('_')) {
          public = e;
        }
      }

      consider(element);
      element.visitAncestorElements((Element ancestor) {
        depth++;
        final Rect? rect = _rectOf(ancestor);
        if (limit != null && rect != null && !_within(rect, limit)) {
          return false;
        }
        consider(ancestor);
        return depth < 60;
      });
      subject = control ?? gesture ?? public ?? element;
    }

    final List<String> segments = <String>[];
    var truncated = false;
    subject.visitAncestorElements((Element ancestor) {
      final String name = nameOf(ancestor.widget);
      if (_isLandmark(name, landmarks)) {
        if (segments.length == 5) {
          truncated = true;
          return false;
        }
        segments.add(name);
      }
      return true;
    });
    final String name = nameOf(subject.widget);
    final List<String> ordered = <String>[if (truncated) '…', ...segments.reversed, name];
    return WidgetDescription(widget: name, path: ordered.join(' > '), element: subject);
  }

  /// Whether [text] is made only of icon-font glyphs (Unicode private use areas) and spaces.
  static bool isIconGlyphs(String text) {
    var glyphs = 0;
    for (final int rune in text.runes) {
      if (rune == 0x20 || rune == 0x0A || rune == 0x09) {
        continue;
      }
      final bool privateUse =
          (rune >= 0xE000 && rune <= 0xF8FF) || (rune >= 0xF0000 && rune <= 0x10FFFF);
      if (!privateUse) {
        return false;
      }
      glyphs++;
    }
    return glyphs > 0;
  }

  /// Whether the `RichText` [element] draws an icon rather than words.
  static bool isIconText(Element element, String text) {
    if (isIconGlyphs(text)) {
      return true;
    }
    var icon = false;
    var depth = 0;
    element.visitAncestorElements((Element ancestor) {
      icon = ancestor.widget is Icon || ancestor.widget is ImageIcon;
      depth++;
      return !icon && depth < 8;
    });
    return icon;
  }

  /// The `Text` / `SelectableText` widget that built the `RichText` [element], or the element
  /// itself.
  static Element textWidgetOf(Element element) {
    Element subject = element;
    var depth = 0;
    element.visitAncestorElements((Element ancestor) {
      depth++;
      final String name = nameOf(ancestor.widget);
      if (name == 'Text' || name == 'SelectableText') {
        subject = ancestor;
        return false;
      }
      return depth < 3;
    });
    return subject;
  }
}
