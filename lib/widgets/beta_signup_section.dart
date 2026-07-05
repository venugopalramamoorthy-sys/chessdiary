// Android beta tester signup form embedded at the top of the web landing page.
// The section itself is plain HTML/CSS/JS (Web3Forms + hCaptcha need a real DOM,
// which Flutter widgets can't host directly), so it's mounted via a platform
// view on web and is a no-op on Android.
export 'beta_signup_section_stub.dart'
    if (dart.library.html) 'beta_signup_section_web.dart';
