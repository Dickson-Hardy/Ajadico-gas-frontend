import 'package:flutter/material.dart';
import '../network/supabase_repository.dart';
import '../../models/company_onboarding.dart';

Future<void> showCompanyDetailsEditor(BuildContext context, {Map? workspace}) =>
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CompanyEditor(workspace: workspace));

/// Shows server-confirmed configuration, never a local 'production ready' flag.
class CompanyOnboardingCard extends StatefulWidget {
  const CompanyOnboardingCard({super.key});
  @override
  State<CompanyOnboardingCard> createState() => _CompanyOnboardingCardState();
}

class _CompanyOnboardingCardState extends State<CompanyOnboardingCard> {
  Map<String, dynamic>? status;
  bool loading = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    final repo = SupabaseRepository.instance;
    final actor = repo.authUserId;
    setState(() {
      loading = true;
      error = null;
      status = null;
    });
    try {
      final result = await repo.companyOnboardingStatus();
      if (mounted && request == generation && repo.authUserId == actor) {
        setState(() => status = result);
      }
    } catch (_) {
      if (mounted && request == generation)
        setState(() => error =
            'Company onboarding is unavailable. A verified director account and the onboarding migration are required.');
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = status?['workspace'] as Map?;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Company onboarding',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (loading)
                    const LinearProgressIndicator()
                  else if (error != null)
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))
                  else ...[
                    Text(workspace?['company_name'] as String? ??
                        'Company details not configured'),
                    if (workspace?['web_url'] is String)
                      Text(workspace!['web_url'] as String),
                    const SizedBox(height: 12),
                    Text(
                        'Approval policy: ${status?['policy_configured'] == true ? 'configured' : 'setup required'}'),
                    Text('Active stations: ${status?['active_stations']}'),
                    Text(
                        'Management accounts awaiting linking: ${status?['unlinked_management']}'),
                    const SizedBox(height: 12),
                    const Text(
                        'Before launch: invite and verify management accounts, enroll station tablets, and validate opening balances and access permissions. Configuration alone does not confirm launch readiness.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () async {
                          await showCompanyDetailsEditor(context,
                              workspace: workspace);
                          if (mounted) await load();
                        },
                        child: const Text('Configure company')),
                  ],
                  TextButton(
                      onPressed: loading ? null : load,
                      child: const Text('Refresh status')),
                ])));
  }
}

class _CompanyEditor extends StatefulWidget {
  const _CompanyEditor({this.workspace});
  final Map? workspace;
  @override
  State<_CompanyEditor> createState() => _CompanyEditorState();
}

class _CompanyEditorState extends State<_CompanyEditor> {
  late final TextEditingController name, url;
  final form = GlobalKey<FormState>();
  bool saving = false, dirty = false;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(
        text: widget.workspace?['company_name'] as String? ?? '');
    url = TextEditingController(
        text: widget.workspace?['web_url'] as String? ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    super.dispose();
  }

  void changed(String _) => setState(() {
        dirty = true;
        error = null;
      });
  Future<void> close() async {
    if (saving) return;
    if (dirty) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Discard company changes?'),
                content: const Text('These settings have not been saved.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep editing')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Discard')),
                ],
              ));
      if (confirmed != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> save() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    final repo = SupabaseRepository.instance;
    final actor = repo.authUserId;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await repo.configureCompanyWorkspace(name.text, url.text);
      if (mounted && repo.authUserId == actor) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Not saved. Verify your director session, connection and backend setup.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !saving && !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: AlertDialog(
            title: const Text('Company details'),
            content: SingleChildScrollView(
                child: Form(
                    key: form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          controller: name,
                          enabled: !saving,
                          maxLength: 150,
                          decoration: const InputDecoration(
                              labelText: 'Registered company name'),
                          onChanged: changed,
                          validator: (value) => (value?.trim().length ?? 0) < 2
                              ? 'Enter the company name.'
                              : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: url,
                          enabled: !saving,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                              labelText: 'Web URL (optional)',
                              helperText:
                                  'Leave blank for APK-only onboarding.'),
                          onChanged: changed,
                          validator: (value) {
                            return !CompanyOnboarding.validOptionalWebUrl(
                                    value ?? '')
                                ? 'Enter your deployed HTTPS web address.'
                                : null;
                          }),
                      const SizedBox(height: 12),
                      const Text(
                          'You can complete company details from this APK without a website. Add a web URL later when browser access is deployed.'),
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ]))),
            actions: [
              TextButton(
                  onPressed: saving ? null : close,
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving…' : 'Save company')),
            ]),
      );
}
