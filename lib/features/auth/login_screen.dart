import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/supabase_repository.dart';
import '../../core/security/kiosk_security_manager.dart';
import '../../core/widgets/ajadico_logo.dart';
import '../../core/widgets/management_unlock_dialog.dart';
import '../../models/station.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';
import 'device_mode_preferences.dart';
import 'management_credentials.dart';

/// One application, with a remembered entry experience for each device.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});
  final void Function(UserProfile user) onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _preferences = DeviceModePreferences();
  final _state = StationAppState.instance;
  final _security = KioskSecurityManager.instance;
  final _identity = TextEditingController();
  final _pin = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _identityFocus = FocusNode();
  final _pinFocus = FocusNode();
  bool _loading = true;
  bool _choosingMode = false;
  bool _busy = false;
  bool _obscure = true;
  bool _submitted = false;
  DeviceMode? _selection;
  String? _selectedStationId;
  String? _error;
  String? _codeEmail;
  DateTime? _resendAfter;

  bool get _stationMode => _preferences.mode == DeviceMode.station;
  bool get _settingUp => _choosingMode || _preferences.mode == null;

  @override
  void initState() {
    super.initState();
    _state.addListener(_refresh);
    _security.addListener(_refresh);
    _loadMode();
  }

  Future<void> _loadMode() async {
    try {
      await _preferences.load();
      if (!mounted) return;
      _selection = _preferences.mode;
      _selectedStationId = _preferences.stationId;
      _applyStationContext();
    } catch (_) {
      if (mounted)
        _error = 'Could not load device settings. Choose a mode to continue.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Station? get _boundStation {
    final id = _preferences.stationId;
    for (final station in _state.stations) {
      if (station.id == id) return station;
    }
    return null;
  }

  void _applyStationContext() {
    if (_preferences.mode != DeviceMode.station) return;
    final branch = _boundStation;
    if (branch != null &&
        _state.currentStationId != branch.id &&
        !_state.isSyncingWithRemote) {
      _state.switchStation(branch);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_refresh);
    _security.removeListener(_refresh);
    _identity.dispose();
    _pin.dispose();
    _identityFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _saveMode() async {
    if (_busy || _selection == null) return;
    if (_selection == DeviceMode.station &&
        _state.stations.isNotEmpty &&
        !_state.stations.any((s) => s.id == _selectedStationId)) {
      setState(() => _error = 'Select the station this tablet belongs to.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _preferences.save(_selection!,
          stationId:
              _selection == DeviceMode.station ? _selectedStationId : null);
      if (!mounted) return;
      _identity.clear();
      _pin.clear();
      _codeEmail = null;
      _obscure = true;
      _submitted = false;
      _choosingMode = false;
      _applyStationContext();
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'Could not save this device mode. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeMode() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change device mode?'),
        content: const Text(
            'This changes the sign-in experience on this device. It does not change account permissions. Any entered PIN will be cleared.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change mode')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _identity.clear();
      _pin.clear();
      _codeEmail = null;
      _obscure = true;
      _submitted = false;
      _error = null;
      _selection = _preferences.mode;
      _selectedStationId = _preferences.stationId;
      _choosingMode = true;
    });
  }

  UserProfile? _profileFor(String identifier) {
    final normalized = identifier.trim().toLowerCase();
    final matches = _state.staff
        .where((user) =>
            user.isActive &&
            (user.id.toLowerCase() == normalized ||
                user.displayName.toLowerCase() == normalized ||
                user.fullName.toLowerCase() == normalized ||
                user.phone?.trim() == normalized))
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<void> _signIn() async {
    if (!_stationMode) {
      await _managementSignIn();
      return;
    }
    if (_busy || _security.isLockedOut || _settingUp) return;
    setState(() => _submitted = true);
    if (!(_form.currentState?.validate() ?? false)) return;
    final repo = SupabaseRepository.instance;
    if (repo.configurationError != null) {
      setState(() => _error =
          'This build is missing valid backend configuration. Contact your administrator.');
      return;
    }
    if (!repo.isConnected) {
      setState(() => _error =
          'You are offline. Connect to the internet to verify your PIN.');
      return;
    }
    if (_state.isSyncingWithRemote) {
      setState(() =>
          _error = 'Station records are loading. Please try again shortly.');
      return;
    }
    final user = _profileFor(_identity.text);
    if (user == null) {
      setState(() => _error =
          'Use your full registered name, staff ID or registered phone number.');
      return;
    }
    final isManagement =
        user.role == UserRole.manager || user.role == UserRole.director;
    if (isManagement == _stationMode) {
      setState(() => _error = _stationMode
          ? 'Management accounts use Personal device mode.'
          : 'Station staff accounts use Station tablet mode.');
      return;
    }
    if (_stationMode &&
        (_boundStation == null || user.stationId != _boundStation!.id)) {
      setState(() => _error =
          'This staff account is not assigned to the configured station. Contact your manager.');
      return;
    }
    Station? assignedStation;
    if (user.role != UserRole.director) {
      for (final station in _state.stations) {
        if (station.id == user.stationId) assignedStation = station;
      }
      if (assignedStation == null) {
        setState(() => _error =
            'Your account needs an active station assignment. Contact your administrator.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await repo.verifyAttendantPin(
          stationId: assignedStation?.id ?? _state.currentStationId,
          profileId: user.id,
          pin: _pin.text);
      if (!mounted) return;
      _pin.clear();
      if (result['success'] == true) {
        if (assignedStation != null &&
            _state.currentStationId != assignedStation.id) {
          if (_state.isSyncingWithRemote) {
            setState(() => _error =
                'Station records changed during sign-in. Please try again.');
            return;
          }
          _state.switchStation(assignedStation);
        }
        _security.recordSuccessfulPin(
            actorId: user.id,
            stationId: assignedStation?.id ?? _state.currentStationId);
        widget.onLoginSuccess(user);
      } else {
        final message = result['message']?.toString() ?? '';
        final serviceFault = [
          'Exception',
          'offline',
          'unavailable',
          'Station could not'
        ].any(message.contains);
        if (!serviceFault) {
          _security.recordFailedPinAttempt(
              actorId: user.id,
              stationId: assignedStation?.id ?? _state.currentStationId);
        }
        setState(() => _error = serviceFault
            ? 'Staff sign-in requires an enrolled tablet and a verified staff session. Ask your administrator to complete station access setup.'
            : 'PIN not accepted. Check your PIN and try again.');
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not verify your PIN. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _managementSignIn() async {
    if (_busy || _settingUp) return;
    setState(() => _submitted = true);
    if (!(_form.currentState?.validate() ?? false)) return;
    final repo = SupabaseRepository.instance;
    if (!repo.isConnected || repo.configurationError != null) {
      setState(() => _error = 'Connect to the configured service to sign in.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_codeEmail == null) {
        if (_resendAfter != null && DateTime.now().isBefore(_resendAfter!)) {
          setState(() => _error =
              'Please wait one minute before requesting another code.');
          return;
        }
        final email = _identity.text.trim().toLowerCase();
        await repo.requestManagementCode(email);
        if (!mounted) return;
        setState(() {
          _codeEmail = email;
          _resendAfter = DateTime.now().add(const Duration(minutes: 1));
          _submitted = false;
          _pin.clear();
        });
        _pinFocus.requestFocus();
      } else {
        final user = await repo.verifyManagementCode(_codeEmail!, _pin.text);
        _pin.clear();
        if (!mounted) {
          await repo.endAuthenticatedSession();
          return;
        }
        if (user.role == UserRole.manager) {
          final stations = _state.stations.where((s) => s.id == user.stationId);
          if (stations.isEmpty || _state.isSyncingWithRemote) {
            await repo.endAuthenticatedSession();
            throw StateError('Station assignment unavailable.');
          }
          _state.switchStation(stations.first);
        }
        widget.onLoginSuccess(user);
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = _codeEmail == null
            ? 'Could not request a code. Check your connection or ask your administrator to confirm your invitation.'
            : 'Could not sign in. Check the code, or ask your administrator to confirm your verified account and station assignment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _editPin(String key) {
    if (_busy || _security.isLockedOut) return;
    var value = _pin.text;
    if (key == 'Clear') {
      value = '';
    } else if (key == 'Backspace') {
      if (value.isNotEmpty) value = value.substring(0, value.length - 1);
    } else if (value.length < 6) {
      value += key;
    }
    _pin.value = TextEditingValue(
        text: value, selection: TextSelection.collapsed(offset: value.length));
    setState(() => _error = null);
  }

  void _accessHelp() {
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Need access help?'),
              content: Text(_stationMode
                  ? 'Ask your station manager to check your staff identity, station assignment or PIN. PINs cannot be reset from this device without authorized verification.'
                  : 'Your company administrator must invite your email and link it to an active management account. Sign in with the code sent to that email. There is no default password or master PIN.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(builder: (context, constraints) {
                final horizontal = constraints.maxWidth < 600 ? 24.0 : 40.0;
                return Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding:
                        EdgeInsets.fromLTRB(horizontal, 28, horizontal, 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                              alignment: Alignment.centerLeft,
                              child: AjadicoLogo.horizontal(
                                  size: 30,
                                  showSubtitle: false,
                                  textColor: colors.onSurface)),
                          SizedBox(
                              height:
                                  _settingUp ? 44 : (_stationMode ? 24 : 36)),
                          if (_settingUp) _deviceSetup() else _loginForm(),
                        ]),
                  ),
                ));
              }),
      ),
    );
  }

  Widget _heading(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
              header: true,
              child: Text(title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: -0.5))),
          const SizedBox(height: 10),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );

  Widget _deviceSetup() {
    final stations = _state.stations;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('How will you use this device?',
          'Choose once. You can change this when signed out.'),
      const SizedBox(height: 32),
      _modeOption(DeviceMode.personal, 'Personal device',
          'For managers and directors', Icons.person_outline),
      const SizedBox(height: 12),
      _modeOption(DeviceMode.station, 'Station tablet',
          'For attendants and cashiers', Icons.groups_outlined),
      if (_selection == DeviceMode.station && stations.isNotEmpty) ...[
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedStationId),
          initialValue: stations.any((s) => s.id == _selectedStationId)
              ? _selectedStationId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Assigned station'),
          items: stations
              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
              .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(() => _selectedStationId = value),
        ),
        const SizedBox(height: 8),
        Text('Use the station assigned to this shared tablet.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 20),
        _message(_error!, error: true)
      ],
      const SizedBox(height: 40),
      _primaryButton('Continue', _selection == null ? null : _saveMode),
      const SizedBox(height: 16),
      Text('Your account determines what you can access.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      if (_choosingMode)
        TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _choosingMode = false;
                      _error = null;
                    }),
            child: const Text('Keep current mode')),
    ]);
  }

  Widget _modeOption(
      DeviceMode mode, String title, String subtitle, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selection == mode;
    return Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? colors.primary.withValues(alpha: 0.05)
              : colors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  color: selected ? colors.primary : colors.outlineVariant,
                  width: selected ? 1.5 : 1)),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _busy
                ? null
                : () => setState(() {
                      _selection = mode;
                      _error = null;
                    }),
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Icon(icon,
                      size: 26,
                      color: selected ? colors.primary : colors.onSurface),
                  const SizedBox(width: 18),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 5),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: colors.onSurfaceVariant)),
                      ])),
                  const SizedBox(width: 8),
                  Icon(
                      selected
                          ? Icons.check_circle_outline
                          : Icons.chevron_right,
                      size: 22,
                      color:
                          selected ? colors.primary : colors.onSurfaceVariant),
                ])),
          ),
        ));
  }

  Widget _loginForm() {
    final colors = Theme.of(context).colorScheme;
    final enabled = !_busy && (!_stationMode || !_security.isLockedOut);
    final boundStation = _boundStation;
    return Form(
        key: _form,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (SupabaseRepository.instance.configurationError != null) ...[
            _message(
                'This build is missing valid backend configuration. Contact your administrator.',
                error: true),
            const SizedBox(height: 16),
          ],
          if (_stationMode) ...[
            _message(boundStation?.name ?? 'No station configured'),
            const SizedBox(height: 16),
          ],
          _heading(
              _stationMode ? 'Staff sign-in' : 'Sign in',
              _stationMode
                  ? 'Enter your identity and personal PIN.'
                  : 'Your management workspace, on your device.'),
          SizedBox(height: _stationMode ? 20 : 28),
          _fieldLabel(
              _stationMode ? 'Registered name or staff ID' : 'Work email'),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey('login-identity'),
            controller: _identity,
            focusNode: _identityFocus,
            enabled: enabled && (_stationMode || _codeEmail == null),
            style: const TextStyle(fontSize: 16),
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: !_stationMode && _codeEmail == null
                ? TextInputAction.done
                : TextInputAction.next,
            autofillHints: _stationMode ? null : const [AutofillHints.username],
            keyboardType:
                _stationMode ? TextInputType.text : TextInputType.emailAddress,
            decoration: InputDecoration(
                hintText: _stationMode
                    ? 'Enter your full name or staff ID'
                    : 'Enter your invited email'),
            onFieldSubmitted: (_) => !_stationMode && _codeEmail == null
                ? _signIn()
                : _pinFocus.requestFocus(),
            validator: (value) => value == null || value.trim().isEmpty
                ? (_stationMode
                    ? 'Enter your registered identity.'
                    : 'Enter your invited email.')
                : !_stationMode && !ManagementCredentials.validEmail(value)
                    ? 'Enter a valid email address.'
                    : null,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_stationMode || _codeEmail != null) ...[
            SizedBox(height: _stationMode ? 16 : 20),
            _fieldLabel(
                _stationMode ? 'Personal PIN' : 'Email verification code'),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey('login-pin'),
              controller: _pin,
              focusNode: _pinFocus,
              enabled: enabled,
              style: const TextStyle(fontSize: 16),
              obscureText: _stationMode || _obscure,
              enableSuggestions: false,
              autofillHints:
                  _stationMode ? null : const [AutofillHints.oneTimeCode],
              autocorrect: false,
              enableInteractiveSelection: !_stationMode,
              keyboardType:
                  _stationMode ? TextInputType.none : TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_stationMode ? 6 : 8)
              ],
              decoration: InputDecoration(
                  hintText: _stationMode
                      ? 'Enter PIN using the keypad'
                      : 'Code from your email',
                  suffixIcon: _stationMode
                      ? null
                      : IconButton(
                          tooltip: _obscure ? 'Show code' : 'Hide code',
                          onPressed: enabled
                              ? () => setState(() => _obscure = !_obscure)
                              : null,
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined))),
              validator: (value) => value == null ||
                      (_stationMode
                          ? !RegExp(r'^\d{4,6}$').hasMatch(value)
                          : !ManagementCredentials.validCode(value))
                  ? (_stationMode
                      ? 'Enter your 4–6 digit PIN.'
                      : 'Enter the 6–8 digit email code.')
                  : null,
              onFieldSubmitted: (_) => _signIn(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
          if (!_stationMode && _codeEmail != null) ...[
            const SizedBox(height: 12),
            _message(
                'If this email has an invited account, a code has been sent. Check your inbox and spam folder.'),
            TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _codeEmail = null;
                          _pin.clear();
                          _submitted = false;
                          _error = null;
                        }),
                child: const Text('Change email or request another code')),
          ],
          if (_stationMode) ...[const SizedBox(height: 12), _keypad(enabled)],
          if (_stationMode && _security.isLockedOut) ...[
            const SizedBox(height: 16),
            _message(
                'Sign-in locked. Try again in ${(_security.lockoutSecondsRemaining / 60).ceil()} minutes.',
                error: true),
            TextButton(
                onPressed: () => showManagementUnlockDialog(context),
                child: const Text('Authorized management unlock')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _message(_error!, error: true)
          ],
          SizedBox(height: _stationMode ? 16 : 24),
          _primaryButton(
              !_stationMode && _codeEmail == null
                  ? 'Send sign-in code'
                  : 'Sign in',
              enabled ? _signIn : null),
          if (!_stationMode)
            TextButton(
                onPressed: _busy ? null : _accessHelp,
                child: const Text('Need access help?')),
          if (_stationMode)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Shared device · Sign out after your shift.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: colors.onSurfaceVariant))),
          SizedBox(height: _stationMode ? 12 : 28),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (_stationMode)
                  IconButton(
                      tooltip: 'Need access help?',
                      onPressed: _busy ? null : _accessHelp,
                      icon: const Icon(Icons.help_outline, size: 20))
                else
                  Icon(Icons.person_outline,
                      size: 20, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(_stationMode ? 'Station tablet' : 'Personal device',
                    style: TextStyle(
                        fontSize: 12, color: colors.onSurfaceVariant)),
              ]),
              TextButton(
                  onPressed: _busy ? null : _changeMode,
                  child: const Text('Change device mode',
                      style: TextStyle(fontSize: 12))),
            ],
          ),
        ]));
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));

  Widget _primaryButton(String label, VoidCallback? onPressed) => SizedBox(
      height: 52,
      child: FilledButton(
          onPressed: _busy ? null : onPressed,
          style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          child: _busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600))));

  Widget _message(String text, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
        liveRegion: error,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: error ? colors.errorContainer : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(error ? Icons.info_outline : Icons.location_on_outlined,
                size: 20,
                color:
                    error ? colors.onErrorContainer : colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: error
                            ? colors.onErrorContainer
                            : colors.onSurfaceVariant))),
          ]),
        ));
  }

  Widget _keypad(bool enabled) => Column(children: [
        for (final keys in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['Clear', '0', 'Backspace']
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                for (var i = 0; i < keys.length; i++) ...[
                  if (i != 0) const SizedBox(width: 8),
                  Expanded(
                      child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                              key: ValueKey('pin-key-${keys[i]}'),
                              onPressed:
                                  enabled ? () => _editPin(keys[i]) : null,
                              child: keys[i] == 'Backspace'
                                  ? const Icon(Icons.backspace_outlined,
                                      semanticLabel: 'Delete last PIN digit',
                                      size: 20)
                                  : Text(keys[i],
                                      style: TextStyle(
                                          fontSize:
                                              keys[i] == 'Clear' ? 14 : 20,
                                          fontWeight: FontWeight.w500))))),
                ],
              ])),
      ]);
}
