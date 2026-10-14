# One APK, two device experiences

First use asks whether this is a personal management device or a shared station tablet. Only mode and station binding are saved in local preferences; identity, PIN and authenticated session are not remembered. Mode selection never grants a role.

Personal devices open a compact management form without a keypad, station selector, staff tabs or shared-tablet copy. Station tablets open a branch-labelled staff form with a numeric keypad, six-digit limit, clear/backspace controls and access help. Changing mode requires confirmation while signed out and clears entered credentials.

Staff must belong to the tablet's configured station. Managers use their actual account assignment after authentication. Directors enter the existing company workspace. Active profile and online PIN verification remain required. Email/password, MFA, biometric unlock and remembered authentication have not been introduced.

The idle policy follows the signed-in role: attendants/cashiers retain 60 seconds; managers/directors use 15 minutes. Signed-out screens do not run the inactivity watchdog. Authentication failure cooldown is unchanged.

## Design and visual review

The working concept was generated with the built-in image tool and saved as [login-concept.png](design/login-concept.png). Brief: one APK, remembered device setup, open unframed management form, station keypad, existing white/teal design tokens, restrained typography and no fictional records or marketing panels.

The frontend design skill shaped the complete-screen concept and comparison pass. The implementation uses native Flutter widgets and the existing Ajadico emblem, not a raster screenshot or a new brand asset.

| Check | Implementation / review |
| --- | --- |
| Copy | Setup, mode names, identity/PIN labels and primary actions follow the concept. |
| Layout | Separate full-screen experiences; no nested login cards or competing tabs. |
| Typography | 28px headings, 14px labels, 16px entered text; larger-text reflow checked. |
| Palette | White surface and existing teal; dark palette preserved and logo contrast corrected. |
| Controls | 8px primary-button radius corrected after render review; minimum 48px keypad buttons. |
| Responsive | 320×568, 390×844, 1024×900 and 1440×1000; keyboard resize, scrolling and 1.3× text tested. |
| Recovery | Working help dialog, honest offline errors, verified management unlock and PIN clearing. |

Intentional concept differences: preserve the existing emblem rather than the generated wordmark; use a real PIN input/hint instead of dots that could imply entered digits; allow compact forms to centre vertically; offer station selection only from real configured branches; move staff access help into the compact footer. Footer actions wrap cleanly when larger text requires it. Setup Continue is disabled until a mode is selected.

Accepted comparison evidence came from current Dart-rendered PNGs, inspected alongside the concept with the image viewer. Browser verification was not used for this Android-native Flutter change. The local Windows policy blocks Flutter's shader compiler; supported asset-independent widget rendering was used without changing that policy. This does not substitute for Android-device acceptance testing.

## Verification

- flutter analyze --no-pub
- flutter test --no-pub --no-test-assets --timeout 90s test/

The login test verifies remembered modes, confirmation, credential clearing, validation, offline rejection, keypad limits/backspace/clear, access help, responsive layouts, dark mode, keyboard insets and idle policies. Existing tests continue to cover all 19 screens and operational navigation. Live authentication, first-time station provisioning, assigned-branch data loading and APK installation require deployment/device acceptance checks.
