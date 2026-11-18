import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:oral_health_ai/screens/camera_screen_web.dart';
import 'package:oral_health_ai/screens/result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _successBody = '{"prob_percent":15.3,"level":"Normal"}';
const _redPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
const _greenPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg+M8AAAICAQB7CYF4AAAAAElFTkSuQmCC';

XFile _photo(String name, String png) =>
    XFile.fromData(base64Decode(png), name: name, mimeType: 'image/png');

class _Picker extends ImagePickerPlatform {
  _Picker(List<XFile?> files) : _files = files.iterator;
  final Iterator<XFile?> _files;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => _files.moveNext() ? _files.current : null;
}

void _mockPicker(List<XFile?> files) {
  final original = ImagePickerPlatform.instance;
  ImagePickerPlatform.instance = _Picker(files);
  addTearDown(() => ImagePickerPlatform.instance = original);
}

Future<void> _press(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.scrollUntilVisible(
    button,
    100,
    scrollable: find.byType(Scrollable),
  );
  await tester.tap(button);
}

Future<void> _openScan(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CameraScreen()),
            ),
            child: const Text('Start scan'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Start scan'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'access_token': 'test'}));

  testWidgets('reselects and confirms only the displayed photo', (
    tester,
  ) async {
    _mockPicker([
      _photo('first.png', _redPng),
      _photo('second.png', _greenPng),
      null,
    ]);
    final uploads = <http.Request>[];
    await http.runWithClient(
      () async {
        await _openScan(tester);
        expect(find.text('Use This Photo'), findsNothing);
        await _press(tester, 'Choose photo');
        await tester.pumpAndSettle();
        await _press(tester, 'Choose Another');
        await tester.pumpAndSettle();
        await _press(
          tester,
          'Choose Another',
        ); // Cancel keeps the selected photo.
        await tester.pumpAndSettle();
        expect(uploads, isEmpty);
        final preview = tester.widget<Image>(find.byType(Image));
        expect((preview.image as MemoryImage).bytes, base64Decode(_greenPng));

        await _press(tester, 'Use This Photo');
        await tester.pumpAndSettle();
        expect(uploads.single.url.path, '/scans/predict');
        expect(
          latin1.decode(uploads.single.bodyBytes),
          contains(latin1.decode(base64Decode(_greenPng))),
        );
        expect(find.text('Try again later'), findsOneWidget);
        expect(find.text('Use This Photo'), findsOneWidget);

        await _press(tester, 'Use This Photo');
        await tester.pumpAndSettle();
        expect(uploads, hasLength(2));
        expect(find.byType(ResultScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Choose photo'), findsOneWidget);
        expect(find.text('Use This Photo'), findsNothing);
      },
      () => MockClient((request) async {
        uploads.add(request);
        return uploads.length == 1
            ? http.Response('{"detail":"Try again later"}', 503)
            : http.Response(_successBody, 200);
      }),
    );
  });

  testWidgets(
    'at 360 px, pending upload stays visible and blocks back and repeat taps',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 360);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _mockPicker([_photo('scan.png', _redPng)]);
      final pending = Completer<http.Response>();
      final uploads = <http.Request>[];
      await http.runWithClient(
        () async {
          await _openScan(tester);
          await _press(tester, 'Choose photo');
          await tester.pumpAndSettle();
          await _press(tester, 'Use This Photo');
          // Tap again before Flutter rebuilds and hides the confirmation button.
          await tester.tap(find.text('Use This Photo'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(uploads, hasLength(1));
          expect(uploads.single.method, 'POST');

          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(
            find.text('Analyzing your photo…').hitTestable(),
            findsOneWidget,
          );
          expect(find.text('Use This Photo'), findsNothing);
          expect(find.text('Start scan'), findsNothing);
          expect(uploads, hasLength(1));
          expect(tester.takeException(), isNull);

          pending.complete(http.Response(_successBody, 200));
          await tester.pumpAndSettle();
          expect(find.byType(ResultScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) {
          uploads.add(request);
          return pending.future;
        }),
      );
    },
  );
}
