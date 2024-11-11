import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';

Future<void> main() async {
  await runFermiApp(appWidget: const App());
}

// This widget is the root of the application.

class App extends StatelessWidget {
  const App({super.key});

  static const _title = 'Fermilab Controls Demo';

  // At the very least, the root widget should be `StandardApp`, which
  // provides a common look and feel. In this case, we wrap the
  // `StandardApp` with an `ACSysProvider`, which allows our app to
  // access the control system.
  //
  // By wrapping the `StandardApp` it also allows the `AppBar` to pull info
  // from the control system (not used in this demo, but it's good to keep in
  // mind.)

  @override
  Widget build(BuildContext context) => ACSysProvider(
      child: StandardApp(
          title: _title,
          appBar: AppBar(title: const Text(_title)),
          body: _BaseWidget()));
}

// This is the body of the application. Typically the body will be implemented
// by widgets defined in other modules.
//
// You may wonder why, with such a simple example, this wasn't placed in the
// `App` widget. It's because, in `App's` `build` method, the 'context' points
// to where in the widget tree `App` will be mounted. But it hasn't yet been
// added to the tree so, when we call `ACSys.api(context)`, it won't find any
// `ACSysProvider` in the tree.
//
// Making a new widget means, when the `build()` method is called, the widgets
// higher in the tree will have been added and `ACSys.api(context)` will
// succeed.

class _BaseWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
      child: StreamBuilder(
          stream: ACSys.api(context).monitorDevices(["G:SCTIME@P,15H"]),
          builder: (context, snapshot) => snapshot.hasData
              ? Text(
                  'Supercycle time: ${snapshot.data!.value!.toStringAsFixed(2)}')
              : const Text('Loading...')));
}
