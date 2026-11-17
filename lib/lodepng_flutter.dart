import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'lodepng_flutter_bindings_generated.dart';

const String _libName = 'lodepng_flutter';

/// The dynamic library in which the symbols for [LodepngFlutterBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid ||
      Platform.isLinux ||
      Platform.operatingSystem == 'ohos') {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final LodepngFlutterBindings _bindings = LodepngFlutterBindings(_dylib);

class Image {
  /// The image data. Each pixel is represented by four bytes in the order of RGBA.
  final Uint8List data;

  final int width;

  final int height;

  /// Creates an image with the given [data], [width], and [height].
  const Image(this.data, this.width, this.height);
}

/// Decodes a PNG image from [data].
Image decodePng(Uint8List data) {
  final (buffer, width, height) = _decodePng(data);
  try {
    final pixels =
        Pointer<Uint8>.fromAddress(buffer.address).asTypedList(buffer.length);
    return Image(Uint8List.fromList(pixels), width, height);
  } finally {
    _bindings.freePtr(Pointer.fromAddress(buffer.address));
  }
}

/// The caller owns the returned native buffer; release it with [ByteBuffer.finalizer].
ByteBuffer decodePngToPointer(Uint8List data) => _decodePng(data).$1;

(ByteBuffer, int, int) _decodePng(Uint8List data) {
  if (data.isEmpty) throw const FormatException('Empty PNG data');
  final out = calloc<Pointer<UnsignedChar>>();
  final w = calloc<UnsignedInt>();
  final h = calloc<UnsignedInt>();
  final input = malloc<Uint8>(data.length);
  try {
    input.asTypedList(data.length).setAll(0, data);
    final error =
        _bindings.lodepng_decode32(out, w, h, input.cast(), data.length);
    if (error != 0) {
      _bindings.freePtr(out.value.cast());
      throw FormatException('PNG decode failed ($error)');
    }
    return (
      ByteBuffer(out.value.address, w.value * h.value * 4),
      w.value,
      h.value
    );
  } finally {
    calloc.free(out);
    calloc.free(w);
    calloc.free(h);
    malloc.free(input);
  }
}

/// Encodes [image] to a PNG image.
Uint8List encodePng(Image image) {
  final buffer = encodePngToPointer(image);
  try {
    final data =
        Pointer<Uint8>.fromAddress(buffer.address).asTypedList(buffer.length);
    return Uint8List.fromList(data);
  } finally {
    _bindings.freePtr(Pointer.fromAddress(buffer.address));
  }
}

class ByteBuffer {
  final int address;

  final int length;

  ByteBuffer(this.address, this.length);

  static Pointer<NativeFinalizerFunction> get finalizer =>
      _dylib.lookup('freePtr');
}

ByteBuffer encodePngToPointer(Image image) {
  // Validate before native unsigned conversion and multiplication.
  if (image.width <= 0 ||
      image.width > 0xffffffff ||
      image.height <= 0 ||
      image.height > 0xffffffff ||
      image.width > image.data.length ~/ 4 ~/ image.height) {
    throw ArgumentError(
        'Image requires positive dimensions and complete RGBA data');
  }
  final out = calloc<Pointer<UnsignedChar>>();
  final outsize = calloc<Size>();
  final input = malloc<Uint8>(image.data.length);
  try {
    input.asTypedList(image.data.length).setAll(0, image.data);
    final error = _bindings.lodepng_encode32(
      out,
      outsize,
      input.cast(),
      image.width,
      image.height,
    );
    if (error != 0) {
      _bindings.freePtr(out.value.cast());
      throw StateError('PNG encode failed ($error)');
    }
    return ByteBuffer(out.value.address, outsize.value);
  } finally {
    calloc.free(out);
    calloc.free(outsize);
    malloc.free(input);
  }
}
