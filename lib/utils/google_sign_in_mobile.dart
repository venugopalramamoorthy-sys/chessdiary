// Conditionally exports the real GoogleSignIn helpers on Android/desktop
// and no-op stubs on web (web uses signInWithPopup via Firebase Auth directly).
export 'google_sign_in_mobile_stub.dart'
    if (dart.library.io) 'google_sign_in_mobile_impl.dart';
