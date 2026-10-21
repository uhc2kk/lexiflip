// Picks the right "save file" implementation per platform at compile time:
//  - Android / Windows / macOS / Linux -> file_bridge_io.dart (dart:io)
//  - Web                               -> file_bridge_web.dart (browser download)
export 'file_bridge_io.dart'
    if (dart.library.js_interop) 'file_bridge_web.dart';
