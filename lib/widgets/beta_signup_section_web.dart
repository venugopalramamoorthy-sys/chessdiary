// Web implementation of the Android beta signup section.
// Builds a real DOM <section> (form + Web3Forms script + hCaptcha widget) and
// mounts it into the Flutter web page via a platform view, since hCaptcha and
// the Web3Forms client script need genuine DOM/JS that Flutter widgets can't host.
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

const String _viewType = 'chessdiary-beta-signup-form';
bool _viewFactoryRegistered = false;

const String _fontsHref =
    'https://fonts.googleapis.com/css2?family=Anton&family=Lora:ital,wght@0,400;0,600;1,400&display=swap';

const String _css = '''
#beta-signup {
  max-width: 640px;
  margin: 0 auto;
  font-family: 'Lora', Georgia, serif;
  color: #F4F3EF;
}
#beta-signup h2 {
  font-family: 'Anton', Impact, sans-serif;
  font-size: 34px;
  letter-spacing: 1px;
  line-height: 1.05;
  color: #FFFFFF;
  margin: 0 0 14px;
}
#beta-signup .beta-signup-p {
  font-size: 15px;
  color: #AAAAAA;
  line-height: 1.65;
  max-width: 480px;
  margin: 0 0 24px;
}
#beta-signup form {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 12px;
}
#beta-signup .beta-signup-input {
  flex: 1 1 260px;
  min-width: 220px;
  padding: 12px 16px;
  font-size: 14px;
  font-family: 'Lora', Georgia, serif;
  background: #1A1A1A;
  border: 1px solid #2E2E2E;
  border-radius: 4px;
  color: #F4F3EF;
}
#beta-signup .beta-signup-input::placeholder { color: #666666; }
#beta-signup .beta-signup-input:focus { outline: none; border-color: #66BB6A; }
#beta-signup .beta-signup-captcha { flex-basis: 100%; }
#beta-signup .beta-signup-btn {
  padding: 12px 26px;
  font-family: 'Lora', Georgia, serif;
  font-size: 14px;
  font-weight: 700;
  color: #0C0C0C;
  background: #66BB6A;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background 0.15s ease;
}
#beta-signup .beta-signup-btn:hover { background: #7FCB83; }
#beta-signup .beta-signup-btn:disabled { opacity: 0.6; cursor: default; }
#beta-signup .beta-signup-status {
  flex-basis: 100%;
  font-size: 13px;
  margin: 4px 0 0;
  min-height: 18px;
}
#beta-signup .beta-signup-status.success { color: #66BB6A; }
#beta-signup .beta-signup-status.error { color: #E57373; }
#beta-signup .beta-signup-status.pending { color: #AAAAAA; }
@media (max-width: 480px) {
  #beta-signup h2 { font-size: 26px; }
  #beta-signup form { flex-direction: column; align-items: stretch; }
}
''';

void _ensureHeadAssetsInjected() {
  if (html.document.getElementById('beta-signup-fonts') == null) {
    html.document.head!.append(
      html.LinkElement()
        ..id = 'beta-signup-fonts'
        ..rel = 'stylesheet'
        ..href = _fontsHref,
    );
  }
  if (html.document.getElementById('beta-signup-style') == null) {
    html.document.head!.append(
      html.StyleElement()
        ..id = 'beta-signup-style'
        ..text = _css,
    );
  }
  if (html.document.getElementById('beta-signup-web3forms-script') == null) {
    html.document.body!.append(
      html.ScriptElement()
        ..id = 'beta-signup-web3forms-script'
        ..src = 'https://web3forms.com/client/script.js'
        ..async = true
        ..defer = true,
    );
  }
}

html.Element _buildSectionElement(int viewId) {
  _ensureHeadAssetsInjected();

  final heading = html.HeadingElement.h2()..text = 'Join the Android Beta';

  final subtext = html.ParagraphElement()
    ..className = 'beta-signup-p'
    ..text = "ChessDiary is in closed testing on Google Play. Enter the email "
        "linked to your Google Play account and we'll send you an invite.";

  // TODO: replace with the real Web3Forms access key from the dashboard before going live.
  final accessKeyInput = html.HiddenInputElement()
    ..name = 'access_key'
    ..value = 'WEB3FORMS_ACCESS_KEY_HERE';

  final subjectInput = html.HiddenInputElement()
    ..name = 'subject'
    ..value = 'New ChessDiary beta tester signup';

  final fromNameInput = html.HiddenInputElement()
    ..name = 'from_name'
    ..value = 'ChessDiary Website';

  final botcheck = html.CheckboxInputElement()
    ..name = 'botcheck'
    ..style.display = 'none';

  final emailInput = html.EmailInputElement()
    ..name = 'email'
    ..placeholder = 'Your Google account email'
    ..required = true
    ..className = 'beta-signup-input';

  final captchaDiv = html.DivElement()
    ..className = 'h-captcha beta-signup-captcha'
    ..setAttribute('data-captcha', 'true');

  final submitBtn = html.ButtonElement()
    ..type = 'submit'
    ..className = 'beta-signup-btn'
    ..text = 'Request Beta Access';

  final status = html.ParagraphElement()
    ..id = 'form-status'
    ..className = 'beta-signup-status'
    ..setAttribute('role', 'status');

  final form = html.FormElement()
    ..action = 'https://api.web3forms.com/submit'
    ..method = 'POST'
    ..id = 'beta-form'
    ..children.addAll([
      accessKeyInput,
      subjectInput,
      fromNameInput,
      botcheck,
      emailInput,
      captchaDiv,
      submitBtn,
      status,
    ]);

  form.onSubmit.listen((event) => _handleSubmit(event, form, status, submitBtn));

  return html.Element.section()
    ..id = 'beta-signup'
    ..children.addAll([heading, subtext, form]);
}

Future<void> _handleSubmit(
  html.Event event,
  html.FormElement form,
  html.ParagraphElement status,
  html.ButtonElement submitBtn,
) async {
  event.preventDefault();

  final captchaResponse =
      form.querySelector('textarea[name="h-captcha-response"]') as html.TextAreaElement?;
  if (captchaResponse == null || (captchaResponse.value ?? '').isEmpty) {
    status
      ..text = 'Please complete the captcha before submitting.'
      ..className = 'beta-signup-status error';
    return;
  }

  submitBtn.disabled = true;
  status
    ..text = 'Sending...'
    ..className = 'beta-signup-status pending';

  try {
    final request = await html.HttpRequest.request(
      form.action ?? 'https://api.web3forms.com/submit',
      method: 'POST',
      sendData: html.FormData(form),
      requestHeaders: const {'Accept': 'application/json'},
    );
    final ok = (request.status ?? 0) >= 200 && (request.status ?? 0) < 300;
    if (ok) {
      status
        ..text = "Thanks! We'll email your invite shortly."
        ..className = 'beta-signup-status success';
      form.reset();
    } else {
      status
        ..text = 'Something went wrong — please try again.'
        ..className = 'beta-signup-status error';
    }
  } catch (_) {
    status
      ..text = 'Something went wrong — please try again.'
      ..className = 'beta-signup-status error';
  } finally {
    submitBtn.disabled = false;
  }
}

class BetaSignupSection extends StatelessWidget {
  const BetaSignupSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!_viewFactoryRegistered) {
      _viewFactoryRegistered = true;
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => _buildSectionElement(viewId),
      );
    }
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Container(
      width: double.infinity,
      color: const Color(0xFF0C0C0C),
      padding: EdgeInsets.symmetric(
          horizontal: narrow ? 20 : 56, vertical: narrow ? 40 : 56),
      child: SizedBox(
        height: narrow ? 480 : 380,
        child: const HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
