import 'package:budget/skins/skin.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/watchAllWallets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Probe extends StatefulWidget {
  const Probe({required this.onInit, super.key});
  final VoidCallback onInit;

  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => SizedBox.shrink();
}

void main() {
  // Turning Boho Glass off used to remount everything below the app's
  // backdrop, which made wallets disappear until the app was restarted
  testWidgets('switching skins keeps the state below the backdrop',
      (tester) async {
    int inits = 0;
    Widget app() => MaterialApp(
          home: SkinBackdrop(child: Probe(onInit: () => inits++)),
        );
    for (String skin in ["bohoGlass", "none", "bohoGlass", "none"]) {
      appStateSettings["skin"] = skin;
      await tester.pumpWidget(app());
    }
    expect(inits, 1);
  });

  test('legacy bohoGlass setting picks the skin', () {
    appStateSettings.remove("skin");
    appStateSettings["bohoGlass"] = false;
    expect(activeSkin().id, "none");
    appStateSettings["bohoGlass"] = true;
    expect(activeSkin().id, "bohoGlass");
    appStateSettings["skin"] = "none";
    expect(activeSkin().id, "none");
    appStateSettings["skin"] = "removed-skin";
    expect(activeSkin().id, "none");
  });

  test('the selected wallet stream can be listened to again', () async {
    var first = selectedWalletPkController.stream.listen((_) {});
    await first.cancel();
    expect(
      () => selectedWalletPkController.stream.listen((_) {}).cancel(),
      returnsNormally,
    );
  });
}
