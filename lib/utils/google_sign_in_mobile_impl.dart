import 'package:google_sign_in/google_sign_in.dart';

Future<Map<String, String?>?> mobileGoogleSignIn() async {
  final googleUser = await GoogleSignIn().signIn();
  if (googleUser == null) return null;
  final auth = await googleUser.authentication;
  return {'accessToken': auth.accessToken, 'idToken': auth.idToken};
}

Future<void> mobileGoogleSignOut() async {
  await GoogleSignIn().signOut();
}
