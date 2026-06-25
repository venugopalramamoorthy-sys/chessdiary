import 'package:google_sign_in/google_sign_in.dart';

Future<Map<String, String?>?> mobileGoogleSignIn() async {
  await GoogleSignIn.instance.initialize();
  try {
    final account = await GoogleSignIn.instance.authenticate();
    final auth = account.authentication;
    // v7 only exposes idToken from authentication (no accessToken).
    // Firebase Auth requires only idToken to sign in with Google.
    return {'idToken': auth.idToken, 'accessToken': null};
  } on GoogleSignInException {
    return null;
  }
}

Future<void> mobileGoogleSignOut() async {
  await GoogleSignIn.instance.signOut();
}
