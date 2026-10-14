import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../network/supabase_repository.dart';
import '../security/kiosk_security_manager.dart';
import '../../features/auth/management_credentials.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

Future<void> showManagementUnlockDialog(BuildContext context,
        {VoidCallback? onUnlocked}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ManagementUnlock(onUnlocked: onUnlocked),
    );

class _ManagementUnlock extends StatefulWidget {
  const _ManagementUnlock({this.onUnlocked});
  final VoidCallback? onUnlocked;
  @override
  State<_ManagementUnlock> createState() => _ManagementUnlockState();
}

class _ManagementUnlockState extends State<_ManagementUnlock> {
  final email = TextEditingController();
  final code = TextEditingController();
  SupabaseRepository? verifier;
  String? requestedEmail, error;
  bool busy = false;
  DateTime? resendAfter;
  final stationId = StationAppState.instance.currentStationId;

  @override
  void dispose() {
    verifier?.closeSessionSnapshot();
    email.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (busy) return;
    if (!ManagementCredentials.validEmail(email.text) ||
        (requestedEmail != null &&
            !ManagementCredentials.validCode(code.text))) {
      setState(
          () => error = 'Enter your invited email and a valid email code.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      verifier ??= SupabaseRepository.instance.managementVerifier();
      if (requestedEmail == null) {
        if (resendAfter != null && DateTime.now().isBefore(resendAfter!)) {
          throw StateError('Wait before requesting another code.');
        }
        await verifier!.requestManagementCode(email.text);
        if (!mounted) return;
        setState(() {
          requestedEmail = email.text.trim().toLowerCase();
          resendAfter = DateTime.now().add(const Duration(minutes: 1));
        });
      } else {
        final user =
            await verifier!.verifyManagementCode(requestedEmail!, code.text);
        await verifier!.endAuthenticatedSession();
        if (!mounted) return;
        if (StationAppState.instance.currentStationId != stationId ||
            (user.role != UserRole.director && user.stationId != stationId)) {
          throw StateError('Management must belong to this station.');
        }
        KioskSecurityManager.instance.unlockAfterManagerVerification(
            managerId: user.id, stationId: stationId);
        Navigator.pop(context);
        widget.onUnlocked?.call();
      }
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Unable to verify this station’s management account. Check your code, invitation and connection. Lockout remains active.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: const Text('Management unlock'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'An active manager for this station or a director must verify their invited email. This does not sign them into the attendant workspace.'),
            const SizedBox(height: 16),
            TextField(
                controller: email,
                enabled: !busy && requestedEmail == null,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration:
                    const InputDecoration(labelText: 'Management email')),
            if (requestedEmail != null) ...[
              const SizedBox(height: 12),
              TextField(
                  controller: code,
                  enabled: !busy,
                  obscureText: true,
                  maxLength: 8,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Email code'),
                  onSubmitted: (_) => verify()),
              TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            requestedEmail = null;
                            code.clear();
                            error = null;
                          }),
                  child: const Text('Change email or resend')),
            ],
            if (error != null)
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ])),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: busy ? null : verify,
                child: Text(busy
                    ? 'Verifying…'
                    : requestedEmail == null
                        ? 'Send code'
                        : 'Verify and unlock')),
          ],
        ),
      );
}
