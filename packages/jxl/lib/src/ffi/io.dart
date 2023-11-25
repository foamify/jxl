import 'dart:ffi';
import 'dart:io';

import 'package:jxl/src/bridge_generated.dart';

typedef ExternalLibrary = DynamicLibrary;

Jxl createWrapperImpl(ExternalLibrary dylib) => JxlImpl(dylib);

DynamicLibrary createLibraryImpl() {
  const base = 'jxl';

  if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.executable();
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('$base.dll');
  } else {
    return DynamicLibrary.open('lib$base.so');
  }
}
