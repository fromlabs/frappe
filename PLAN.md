# Piano: Monorepo frappe

## Obiettivo

Trasformare il progetto `frappe` in un monorepo Dart workspace con 4 package:

| Package | Tipo | Dipendenze |
|---|---|---|
| `frappe` | Puro Dart | — |
| `flutter_frappe` | Flutter | `frappe` |
| `brew` | Puro Dart | `frappe` |
| `flutter_brew` | Flutter | `brew`, `flutter_frappe` |

---

## Step 1 — Dart workspace root

Creare `pubspec.yaml` root con workspace:

```yaml
name: _frappe_workspace
publish_to: none

environment:
  sdk: '>=3.5.0 <4.0.0'

workspace:
  - packages/frappe
  - packages/flutter_frappe
  - packages/brew
  - packages/flutter_brew
```

---

## Step 2 — Spostare `frappe` in `packages/frappe`

- Spostare `lib/`, `test/`, `pubspec.yaml`, `analysis_options.yaml`, `CHANGELOG.md`, `LICENSE`, `README.md` in `packages/frappe/`
- Aggiungere `resolution: workspace` al pubspec.yaml del package
- Verificare che i test passino dopo lo spostamento

---

## Step 3 — Creare `packages/brew`

Package puro Dart con la classe base `Brew`:

```
packages/brew/
├── lib/
│   ├── brew.dart              # export file
│   └── src/
│       └── brew.dart          # classe base Brew
├── test/
│   └── brew_test.dart
├── pubspec.yaml
├── analysis_options.yaml
├── CHANGELOG.md
└── README.md
```

**pubspec.yaml:**
```yaml
name: brew
description: Reactive business logic units built on frappe.
version: 0.1.0
homepage: https://github.com/fromlabs/frappe

environment:
  sdk: '>=3.5.0 <4.0.0'

resolution: workspace

dependencies:
  frappe:

dev_dependencies:
  test: ^1.25.0
  lints: ^5.0.0
```

**Classe `Brew` (bozza):**
```dart
import 'package:frappe/frappe.dart';

abstract class Brew {
  Brew() {
    onBind();
  }

  /// Override per definire il wiring reattivo.
  void onBind();

  /// Disposer per tutte le reference create dal Brew.
  final FrappeReferenceCollector _collector = FrappeReferenceCollector();

  /// Registra una FrappeReference per auto-dispose.
  void collect(FrappeReference reference) {
    _collector.add(reference);
  }

  /// Rilascia tutte le risorse.
  void dispose() {
    _collector.dispose();
  }
}
```

---

## Step 4 — Creare `packages/flutter_frappe`

Bridge minimo tra frappe e Flutter:

```
packages/flutter_frappe/
├── lib/
│   ├── flutter_frappe.dart    # export file
│   └── src/
│       └── observe.dart       # widget Observe
├── test/
├── pubspec.yaml
├── analysis_options.yaml
├── CHANGELOG.md
└── README.md
```

**pubspec.yaml:**
```yaml
name: flutter_frappe
description: Flutter widgets for observing frappe reactive primitives.
version: 0.1.0
homepage: https://github.com/fromlabs/frappe

environment:
  sdk: '>=3.5.0 <4.0.0'

resolution: workspace

dependencies:
  flutter:
    sdk: flutter
  frappe:

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^5.0.0
```

**Widget `Observe` (bozza):**
```dart
import 'package:flutter/widgets.dart';
import 'package:frappe/frappe.dart';

class Observe<V> extends StatefulWidget {
  const Observe({
    super.key,
    required this.state,
    required this.builder,
  });

  final ValueState<V> state;
  final Widget Function(BuildContext context, V value) builder;

  @override
  State<Observe<V>> createState() => _ObserveState<V>();
}

class _ObserveState<V> extends State<Observe<V>> {
  late V _value;
  ListenSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(Observe<V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    _value = widget.state.getValue();
    _subscription = widget.state.listen((value) {
      setState(() => _value = value);
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
```

---

## Step 5 — Creare `packages/flutter_brew`

Integrazione Brew + Flutter:

```
packages/flutter_brew/
├── lib/
│   ├── flutter_brew.dart      # export file
│   └── src/
│       └── brew_provider.dart # InheritedWidget per Brew
├── test/
├── pubspec.yaml
├── analysis_options.yaml
├── CHANGELOG.md
└── README.md
```

**pubspec.yaml:**
```yaml
name: flutter_brew
description: Flutter integration for Brew reactive business logic.
version: 0.1.0
homepage: https://github.com/fromlabs/frappe

environment:
  sdk: '>=3.5.0 <4.0.0'

resolution: workspace

dependencies:
  flutter:
    sdk: flutter
  brew:
  flutter_frappe:

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^5.0.0
```

**BrewProvider (bozza):**
```dart
import 'package:flutter/widgets.dart';
import 'package:brew/brew.dart';

class BrewProvider<B extends Brew> extends StatefulWidget {
  const BrewProvider({
    super.key,
    required this.create,
    required this.child,
  });

  final B Function() create;
  final Widget child;

  static B of<B extends Brew>(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_BrewInherited<B>>();
    assert(provider != null, 'No BrewProvider<$B> found in context');
    return provider!.brew;
  }

  @override
  State<BrewProvider<B>> createState() => _BrewProviderState<B>();
}

class _BrewProviderState<B extends Brew> extends State<BrewProvider<B>> {
  late final B brew = widget.create();

  @override
  void dispose() {
    brew.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BrewInherited<B>(
      brew: brew,
      child: widget.child,
    );
  }
}

class _BrewInherited<B extends Brew> extends InheritedWidget {
  const _BrewInherited({
    required this.brew,
    required super.child,
  });

  final B brew;

  @override
  bool updateShouldNotify(_BrewInherited<B> oldWidget) => false;
}
```

---

## Step 6 — Configurazione condivisa

- `analysis_options.yaml` in ogni package (include `package:lints/recommended.yaml`)
- `.gitignore` aggiornato per struttura monorepo
- README.md root con overview del progetto

---

## Step 7 — Verifiche

- `dart pub get` nel root (workspace resolution)
- `dart test` in `packages/frappe` — tutti i test esistenti passano
- `dart test` in `packages/brew` — test base del Brew
- `dart analyze` su tutti i package — zero warning

---

## Ordine di esecuzione

1. Creare branch e struttura directory
2. Spostare `frappe` in `packages/frappe` (+ workspace root)
3. Verificare test frappe
4. Creare `packages/brew` con classe base
5. Creare `packages/flutter_frappe` con widget Observe
6. Creare `packages/flutter_brew` con BrewProvider
7. Verifiche finali e commit
