import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/network/supabase_repository.dart';
import '../../core/widgets/company_onboarding_card.dart';
import '../../core/widgets/operations_policy_setup_card.dart';
import '../../models/company_onboarding.dart';
import '../../models/station.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';
import '../admin/price_change_screen.dart';
import '../admin/staff_management_screen.dart';
import '../admin/station_setup_screen.dart';

/// Director-only, resumable setup. No local flag can declare live readiness.
class CompanySetupScreen extends StatefulWidget {
  const CompanySetupScreen(
      {super.key, required this.onContinue, required this.onSignOut})
      : _statusLoader = null;
  CompanySetupScreen._test(
      {required this.onContinue,
      required this.onSignOut,
      required Future<CompanyOnboarding> Function() statusLoader})
      : _statusLoader = statusLoader;
  @visibleForTesting
  factory CompanySetupScreen.forTesting(
      {required VoidCallback onContinue,
      required VoidCallback onSignOut,
      required Future<CompanyOnboarding> Function() statusLoader}) {
    if (kReleaseMode)
      throw StateError('Test setup loaders are disabled in release builds');
    return CompanySetupScreen._test(
        onContinue: onContinue,
        onSignOut: onSignOut,
        statusLoader: statusLoader);
  }
  final Future<CompanyOnboarding> Function()? _statusLoader;
  final VoidCallback onContinue, onSignOut;
  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  static const titles = [
    'Company details',
    'Approval policy',
    'Stations',
    'Pumps, tanks & opening values',
    'People & account access',
    'Station tablets',
    'Readiness review'
  ];
  final repo = SupabaseRepository.instance;
  final state = StationAppState.instance;
  CompanyOnboarding? status;
  List<Station> stations = [];
  String? selectedStation, error;
  int? selectedStep;
  int requestGeneration = 0;
  bool loading = true, openingPage = false;

  bool get authorized =>
      state.currentUser.isActive && state.currentUser.role == UserRole.director;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final generation = ++requestGeneration;
    final actor = repo.authUserId;
    final profile = state.currentUser.id;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!authorized || (actor == null && widget._statusLoader == null))
        throw StateError('Verified director required');
      final data = widget._statusLoader == null
          ? CompanyOnboarding.fromJson(await repo.companyOnboardingStatus())
          : await widget._statusLoader!();
      final branches = await repo.fetchAllStations();
      await state.refreshAuthenticatedPolicy();
      if (!mounted ||
          generation != requestGeneration ||
          repo.authUserId != actor ||
          state.currentUser.id != profile ||
          !authorized) return;
      if (branches.length != data.stationCount)
        throw StateError('Station list changed; refresh');
      setState(() {
        status = data;
        stations = branches;
        selectedStep ??= data.resumeStep;
        if (!branches.any((s) => s.id == selectedStation))
          selectedStation = branches.firstOrNull?.id;
      });
    } catch (_) {
      if (mounted && generation == requestGeneration)
        setState(() => error =
            'Setup could not be loaded. Your administrator must activate the verified director account and onboarding backend. Connect and retry; a website is not required.');
    } finally {
      if (mounted && generation == requestGeneration)
        setState(() => loading = false);
    }
  }

  Future<void> closeEntry(BuildContext pageContext) async {
    if (ShellBackGuard.hasUnsavedWork) {
      final discard = await showDialog<bool>(
          context: pageContext,
          builder: (ctx) => AlertDialog(
                title: const Text('Discard unsaved entries?'),
                content: const Text(
                    'Saved configuration will remain. Unsubmitted entries will be discarded.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep editing')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Discard')),
                ],
              ));
      if (discard != true || !pageContext.mounted) return;
    }
    if (pageContext.mounted) Navigator.pop(pageContext);
  }

  Future<void> openPage(Widget Function(VoidCallback close) builder,
      {bool stationRequired = false}) async {
    if (openingPage || loading || !authorized) return;
    setState(() {
      openingPage = true;
      error = null;
    });
    final actor = repo.authUserId;
    try {
      if (stationRequired) {
        final station =
            stations.where((s) => s.id == selectedStation).firstOrNull;
        if (station == null || state.isSyncingWithRemote)
          throw StateError('Station unavailable');
        state.switchStation(station, refresh: false);
        await state.syncWithSupabase();
        if (state.currentStationId != station.id)
          throw StateError('Station changed');
      }
      if (!mounted || repo.authUserId != actor || !authorized) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (pageContext) => PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) closeEntry(pageContext);
              },
              child: builder(() => closeEntry(pageContext)))));
      if (mounted && authorized && repo.authUserId == actor) await load();
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Could not open station setup. Wait for station loading, check your connection and retry.');
    } finally {
      if (mounted) setState(() => openingPage = false);
    }
  }

  Future<void> addStation() async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _NewStationDialog());
    if (mounted && authorized) await load();
  }

  Widget stationSelector() => DropdownButtonFormField<String>(
        key: ValueKey(selectedStation),
        initialValue: selectedStation,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Station to configure'),
        items: stations
            .map((s) => DropdownMenuItem(
                value: s.id, child: Text('${s.name} · ${s.code}')))
            .toList(),
        onChanged: openingPage || loading
            ? null
            : (value) => setState(() => selectedStation = value),
      );

  Widget stepContent(int step) {
    switch (step) {
      case 0:
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'Enter the registered company name. This APK connects directly to the backend; browser hosting can be added later.'),
              const SizedBox(height: 16),
              if (status!.workspace != null)
                Text(status!.workspace!['company_name'] as String),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () async {
                    await showCompanyDetailsEditor(context,
                        workspace: status!.workspace);
                    if (mounted && authorized) await load();
                  },
                  child: Text(status!.workspace == null
                      ? 'Enter company details'
                      : 'Edit company details')),
            ]);
      case 1:
        return OperationsPolicySetupCard(onChanged: load);
      case 2:
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'Register each real branch. Existing branches are retained; do not recreate them.'),
              const SizedBox(height: 16),
              for (final station in stations)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_gas_station_outlined),
                    title: Text(station.name),
                    subtitle: Text(station.code)),
              OutlinedButton.icon(
                  onPressed: addStation,
                  icon: const Icon(Icons.add),
                  label: const Text('Add station')),
            ]);
      case 3:
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'For every station, configure tanks and pump routing, then verify physical dips, book stock, opening meters and fuel prices. Zero is valid only when it reflects an actual opening value.'),
              const SizedBox(height: 16),
              stationSelector(),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: stations.isEmpty
                      ? null
                      : () => openPage(
                          (close) => StationSetupScreen(onBack: close),
                          stationRequired: true),
                  child: const Text('Configure tanks, pumps & opening meters')),
              OutlinedButton(
                  onPressed: stations.isEmpty
                      ? null
                      : () => openPage(
                          (close) => PriceChangeScreen(
                              onBack: close, onSuccess: close),
                          stationRequired: true),
                  child: const Text('Configure fuel prices')),
              const SizedBox(height: 12),
              const Text(
                  'The configuration check does not certify that opening cash, customer credit or physical stock has been independently reconciled. Review those balances before launch.'),
            ]);
      case 4:
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  '${status!.staffCount} active staff records. ${status!.unlinkedStaff < 0 ? 'Account-link status unavailable' : '${status!.unlinkedStaff} accounts still need Auth linking'}.'),
              const SizedBox(height: 12),
              const Text(
                  'Add staff and assign stations/roles. Creating a staff record does not activate login. Management accounts must be pre-authorized and email-verified; station staff need the trusted PIN session service.'),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: () =>
                      openPage((close) => StaffManagementScreen(onBack: close)),
                  child: const Text('Manage staff records')),
              const SizedBox(height: 12),
              const Text(
                  'Invitations and Auth linking currently require trusted backend administration. No default passwords or automatic director access are created by this wizard.'),
            ]);
      case 5:
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.tablet_android_outlined, size: 44),
              const SizedBox(height: 16),
              const Text(
                  'Shared tablets must be authorized by management, bound to a station and individually revocable. A local device-mode preference cannot grant access.'),
              const SizedBox(height: 16),
              Text(status!.tabletAuthenticationAvailable
                  ? 'The backend reports tablet authentication is available. Enrollment still needs device-specific confirmation.'
                  : 'Blocked: the trusted tablet enrollment and PIN-to-Auth service has not been deployed. Staff sign-in remains unavailable.'),
              const SizedBox(height: 12),
              const Text(
                  'There is no “mark enrolled” shortcut. Enrollment cannot be completed from the current build.'),
            ]);
      default:
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < titles.length - 1; i++)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(status!.configuredSteps[i]
                        ? Icons.check_circle_outline
                        : Icons.pending_outlined),
                    title: Text(titles[i]),
                    subtitle: Text(status!.configuredSteps[i]
                        ? 'Configuration recorded'
                        : 'Action required'),
                    onTap: () => setState(() => selectedStep = i)),
              const SizedBox(height: 12),
              const Text(
                  'Not approved for live operations. Account provisioning, tablet enrollment, legacy access hardening and a complete reconciled pilot shift must be verified before APK distribution.'),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: widget.onContinue,
                  child: const Text('Open management — setup remains pending')),
            ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = selectedStep ?? 0;
    return Scaffold(
        appBar: AppBar(title: const Text('Company setup'), actions: [
          IconButton(
              onPressed: loading || openingPage ? null : load,
              tooltip: 'Refresh saved progress',
              icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: widget.onSignOut,
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout)),
        ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                                Text('Set up your company from this device',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: 8),
                                const Text(
                                    'Saved progress comes from the backend and can be resumed on another authorized device. A deployed website is optional.'),
                                if (error != null) ...[
                                  const SizedBox(height: 16),
                                  Text(error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                  TextButton(
                                      onPressed: load,
                                      child: const Text('Retry setup'))
                                ],
                                if (status != null && authorized) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                      'Step ${step + 1} of ${titles.length} · ${titles[step]}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                      value: status!.configuredSteps
                                              .take(6)
                                              .where((saved) => saved)
                                              .length /
                                          6),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Saved setup items: ${status!.configuredSteps.take(6).where((saved) => saved).length}/6. Live readiness is reviewed separately.'),
                                  const SizedBox(height: 24),
                                  IgnorePointer(
                                      ignoring: openingPage,
                                      child: stepContent(step)),
                                  if (openingPage)
                                    const LinearProgressIndicator(),
                                  const SizedBox(height: 24),
                                  Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        OutlinedButton(
                                            onPressed: step == 0 || openingPage
                                                ? null
                                                : () => setState(() =>
                                                    selectedStep = step - 1),
                                            child: const Text('Previous')),
                                        if (step < titles.length - 1)
                                          FilledButton(
                                              onPressed: openingPage
                                                  ? null
                                                  : () => setState(() =>
                                                      selectedStep = step + 1),
                                              child: const Text('Next step')),
                                      ]),
                                ],
                              ])))));
  }
}

class _NewStationDialog extends StatefulWidget {
  const _NewStationDialog();
  @override
  State<_NewStationDialog> createState() => _NewStationDialogState();
}

class _NewStationDialogState extends State<_NewStationDialog> {
  final code = TextEditingController(),
      name = TextEditingController(),
      address = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false, dirty = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    name.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (saving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Discard station details?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Keep editing')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Discard')),
                  ]));
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> save() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    final state = StationAppState.instance;
    final actor = SupabaseRepository.instance.authUserId;
    if (!state.currentUser.isActive ||
        state.currentUser.role != UserRole.director ||
        actor == null) {
      setState(() => error = 'A verified director session is required.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final station = await state.registerNewStation(
        code: code.text, name: name.text, address: address.text);
    if (!mounted) return;
    if (station == null || actor != SupabaseRepository.instance.authUserId) {
      setState(() {
        saving = false;
        error =
            'Not saved. Check your connection, station-code uniqueness and backend activation.';
      });
      return;
    }
    dirty = false;
    Navigator.pop(context);
  }

  void changed(String _) => setState(() {
        dirty = true;
        error = null;
      });
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !dirty && !saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: AlertDialog(
          title: const Text('Register station'),
          content: SingleChildScrollView(
              child: Form(
                  key: form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                        controller: code,
                        enabled: !saving,
                        maxLength: 20,
                        onChanged: changed,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                            labelText: 'Unique station code'),
                        validator: (value) =>
                            RegExp(r'^[A-Z0-9][A-Z0-9-]{0,19}$').hasMatch(
                                    (value ?? '').trim().toUpperCase())
                                ? null
                                : 'Use letters, numbers and hyphens.'),
                    TextFormField(
                        controller: name,
                        enabled: !saving,
                        maxLength: 100,
                        onChanged: changed,
                        decoration:
                            const InputDecoration(labelText: 'Station name'),
                        validator: (value) =>
                            CompanyOnboarding.validCompanyName(value ?? '')
                                ? null
                                : 'Enter a station name.'),
                    TextFormField(
                        controller: address,
                        enabled: !saving,
                        maxLength: 1000,
                        onChanged: changed,
                        decoration: const InputDecoration(
                            labelText: 'Address (optional)')),
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ]))),
          actions: [
            TextButton(
                onPressed: saving ? null : close, child: const Text('Cancel')),
            FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save station')),
          ]));
}
