// Cross-platform file save: triggers a browser download on web,
// writes to the app documents directory on Android/desktop.
// Returns the saved file path, or null on web (download already happened).
export 'platform_file_stub.dart'
    if (dart.library.html) 'platform_file_web.dart'
    if (dart.library.io) 'platform_file_native.dart';
