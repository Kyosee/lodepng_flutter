# lodepng_flutter

PNG encoder and decoder

flutter binding for [lodepng](https://github.com/lvandeve/lodepng/tree/master)

The convenience methods return Dart-owned bytes. Pointer methods transfer
ownership to the caller: attach `ByteBuffer.finalizer` to the returned typed-data
view exactly once. The HarmonyOS loader expects the application to bundle
`liblodepng_flutter.so` from `src/`.

Run `flutter test test/png_buffer_test.dart` with the native library on the
platform library search path (`PATH` on Windows, `LD_LIBRARY_PATH` on Linux).
The tests cover non-square dimensions, byte lifetime, invalid input and the
pointer/finalizer API. They require the real native codec.
