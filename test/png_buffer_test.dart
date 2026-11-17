import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lodepng_flutter/lodepng_flutter.dart' as png;

void main() {
  final pixels = Uint8List.fromList([
    255,
    0,
    0,
    255,
    0,
    255,
    0,
    255,
    0,
    0,
    255,
    255,
    255,
    255,
    255,
    255,
    0,
    0,
    0,
    255,
    32,
    64,
    128,
    255,
  ]);

  test('non-square images retain dimensions and pixels across allocations', () {
    final encoded = png.encodePng(png.Image(pixels, 3, 2));
    final decoded = png.decodePng(encoded);
    expect(decoded.width, 3);
    expect(decoded.height, 2);
    final encodedCopy = Uint8List.fromList(encoded);
    for (var i = 0; i < 64; i++) {
      png.encodePng(png.Image(Uint8List(24), 2, 3));
    }
    expect(decoded.data, pixels);
    expect(encoded, encodedCopy);
  });

  test('invalid PNG input reports a format error', () {
    for (final data in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3, 4])
    ]) {
      expect(() => png.decodePng(data), throwsFormatException);
      expect(() => png.decodePngToPointer(data), throwsFormatException);
    }
  });

  test('pointer APIs keep caller-owned buffers usable with native finalizers',
      () {
    final encoded = png.encodePngToPointer(png.Image(pixels, 3, 2));
    final bytes = Pointer<Uint8>.fromAddress(encoded.address)
        .asTypedList(encoded.length, finalizer: png.ByteBuffer.finalizer);
    final decoded = png.decodePngToPointer(bytes);
    final restored = Pointer<Uint8>.fromAddress(decoded.address)
        .asTypedList(decoded.length, finalizer: png.ByteBuffer.finalizer);
    expect(restored, pixels);
    expect(
      () => png.decodePng(Uint8List.sublistView(bytes, 0, bytes.length ~/ 2)),
      throwsFormatException,
    );
  });

  test('invalid dimensions and short RGBA input are rejected before FFI', () {
    for (final image in [
      png.Image(pixels, 0, 2),
      png.Image(pixels, -1, 2),
      png.Image(pixels, 3, 3),
      png.Image(pixels, 0x100000000, 1),
      png.Image(pixels, 0xffffffff, 0xffffffff),
    ]) {
      expect(() => png.encodePngToPointer(image), throwsArgumentError);
    }
  });
}
