import 'package:jxl/src/bridge_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

typedef ExternalLibrary = WasmModule;

Jxl createWrapperImpl(ExternalLibrary module) => JxlImpl.wasm(module);
