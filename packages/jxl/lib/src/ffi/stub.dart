import 'package:jxl/src/bridge_generated.dart';

/// Represents the external library for jxl
///
/// Will be a DynamicLibrary for dart:io or WasmModule for dart:html
typedef ExternalLibrary = Object;

Jxl createWrapperImpl(ExternalLibrary lib) => throw UnimplementedError();
