# Doqto

Flutter app in `doqto_app/`. Backend infra in `infra/`.

## Rules

### Keyboards must always have a way out

Every text input dismisses its own keyboard. No exceptions, no "the user can
swipe down".

- **Tap outside → keyboard goes.** Every `TextField` / `TextFormField` /
  `CupertinoTextField` sets `onTapOutside: (_) => focusNode.unfocus()` (or
  `FocusScope.of(context).unfocus()` where there's no local node). Flutter's
  default only unfocuses on desktop — on iOS and Android focus sticks and the
  keypad covers the screen. This is not optional boilerplate.
- **Fixed-length input complete → keyboard goes.** Phone, OTP, PIN, ZIP: the
  moment the value parses valid, unfocus. `AppTextField` does this via
  `dismissOnValid: true`; `PhoneField` does it in `_emit()`. Never on free
  text — a name validator passes at one character.
- Numeric keypads have no return key, so without the above the user is
  trapped. That is the bug this rule exists to prevent.

Prefer `AppTextField` and `PhoneField` — both already comply. If a screen
needs a raw `TextField`, it carries `onTapOutside` itself. Guarded by
`test/widgets/keyboard_dismiss_test.dart` and
`test/widgets/phone_field_keyboard_test.dart`; extend those when adding an
input pattern.

### Before claiming a UI change works

`flutter analyze lib test` and `flutter test` both clean. Screenshots or a
device run for anything touching layout or input.
