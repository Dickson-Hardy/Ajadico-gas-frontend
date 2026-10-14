import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ajadico_gas/core/theme/app_theme.dart';
import 'package:ajadico_gas/core/widgets/forecourt_tank_gauge.dart';

void main() {
  test('capacity ratios do not hide invalid or over-capacity measurements', () {
    const normal = ForecourtTankGauge(
        tankCode: 'T1',
        productName: 'PMS',
        capacityLitres: 45000,
        currentLitres: 23850,
        calculatedStockLitres: 24000);
    expect(normal.fillRatio, 0.53);
    expect(normal.ullageLitres, 21150);
    expect(normal.varianceLitres, -150);
    const invalid = ForecourtTankGauge(
        tankCode: 'T1',
        productName: 'PMS',
        capacityLitres: 0,
        currentLitres: double.nan);
    expect(invalid.hasCapacity, isFalse);
    expect(invalid.hasReading, isFalse);
    expect(invalid.fillRatio, 0);
    const over = ForecourtTankGauge(
        tankCode: 'T1',
        productName: 'PMS',
        capacityLitres: 100,
        currentLitres: 120);
    expect(over.exceedsCapacity, isTrue);
    expect(over.fillRatio, 1);
    expect(over.ullageLitres, 0);
  });

  testWidgets(
      'capacity card is readable, honest and interactive at small widths',
      (tester) async {
    await tester.runAsync(() async {
      final cache =
          File(Platform.resolvedExecutable).parent.parent.parent.parent;
      final root = Platform.environment['FLUTTER_ROOT'];
      final fonts = root == null
          ? '${cache.path}/artifacts/material_fonts'
          : '$root/bin/cache/artifacts/material_fonts';
      final loader = FontLoader('Roboto');
      for (final weight in ['regular', 'medium', 'bold']) {
        final font = File('$fonts/roboto-$weight.ttf');
        if (await font.exists())
          loader.addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())));
      }
      await loader.load();
    });
    final capture = GlobalKey();
    var tapped = false;
    Future<void> mount(Widget gauge,
        {bool dark = false, double width = 320}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: RepaintBoundary(key: capture, child: gauge))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> screenshot(String name) async {
      const directory = String.fromEnvironment('TANK_GAUGE_CAPTURE_DIR');
      if (directory.isEmpty) return;
      await tester.runAsync(() async {
        final boundary = capture.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final rendered = await boundary.toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File('$directory/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
    }

    for (final dark in [false, true]) {
      await mount(
          ForecourtTankGauge(
              tankCode: 'T1',
              productName: 'PMS',
              capacityLitres: 45000,
              currentLitres: 23850,
              calculatedStockLitres: 24000,
              lastDipTime: DateTime(2026, 10, 13, 11, 30),
              onTap: () => tapped = true),
          dark: dark);
      expect(find.text('23,850.0 L'), findsOneWidget);
      expect(find.text('53.0% of capacity'), findsOneWidget);
      expect(find.text('21,150.0 L'), findsOneWidget);
      expect(find.text('−150.0 L'), findsOneWidget);
      expect(find.text('SAFE OPERATING LEVEL'), findsNothing);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('tank-capacity-bar')));
      expect(bar.value, 0.53);
      expect(bar.semanticsValue, '53.0');
      await screenshot(
          dark ? '02-capacity-dark-phone' : '01-capacity-light-phone');
      await tester.tap(find.text('Tank T1'));
      expect(tapped, isTrue);
    }
    await mount(
        const ForecourtTankGauge(
            tankCode: 'T2',
            productName: 'AGO',
            capacityLitres: 100,
            currentLitres: 120,
            isCompact: true,
            isDraft: true),
        width: 700);
    expect(find.text('120.0% of capacity'), findsOneWidget);
    expect(find.textContaining('exceeds capacity'), findsOneWidget);
    expect(find.text('Unsaved measurement'), findsOneWidget);
    await mount(const ForecourtTankGauge(
        tankCode: 'T3',
        productName: 'PMS',
        capacityLitres: 0,
        currentLitres: double.nan,
        calculatedStockLitres: -1));
    expect(find.text('Capacity not configured'), findsOneWidget);
    expect(find.text('Measurement unavailable'), findsOneWidget);
    expect(find.text('Fill percentage unavailable'), findsOneWidget);
    expect(find.text('Reading time not recorded'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
