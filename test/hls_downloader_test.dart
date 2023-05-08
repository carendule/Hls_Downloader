import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hls_downloader/hls_downloader.dart';

void main() {
  const MethodChannel channel = MethodChannel('hls_downloader');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

}
