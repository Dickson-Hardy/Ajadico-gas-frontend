import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_profile.dart';

class LoginScreen extends StatefulWidget {
  final Function(UserProfile user) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserProfile? _selectedUser;
  String _pin = '';

  void _onKeyPress(String key) {
    if (_pin.length < 6) {
      setState(() {
        _pin += key;
      });
    }
  }

  void _onClear() {
    setState(() {
      _pin = '';
    });
  }

  void _onSubmit() {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your name first')),
      );
      return;
    }
    if (_pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 4 digits for your PIN')),
      );
      return;
    }

    widget.onLoginSuccess(_selectedUser!);
  }

  @override
  Widget build(BuildContext context) {
    final staffList = UserProfile.demoStaff
        .where((u) => u.role != UserRole.director)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'Lekki Road Station · Tablet',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who is using the tablet?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick your name, then enter your PIN.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // Staff selection buttons grid
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.8,
                      children: staffList.map((user) {
                        final isSelected = _selectedUser?.id == user.id;
                        return OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedUser = user;
                              _pin = '';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isSelected
                                ? AppColors.ink.withOpacity(0.08)
                                : Colors.transparent,
                            side: BorderSide(
                              color: isSelected ? AppColors.bank : AppColors.line,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            user.displayName,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // PIN Pad Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'PIN for ${_selectedUser?.displayName ?? "—"}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // PIN dots / mask display
                        Container(
                          width: 260,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            _pin.isEmpty
                                ? '• • • •'
                                : '• ' * _pin.length,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Numeric Keypad
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Column(
                            children: [
                              _buildKeypadRow(['1', '2', '3']),
                              const SizedBox(height: 10),
                              _buildKeypadRow(['4', '5', '6']),
                              const SizedBox(height: 10),
                              _buildKeypadRow(['7', '8', '9']),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _onClear,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 60),
                                      ),
                                      child: const Text('Clear'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _onKeyPress('0'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 60),
                                      ),
                                      child: const Text(
                                        '0',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _onSubmit,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 60),
                                      ),
                                      child: const Text(
                                        'Log in',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please contact your Branch Manager for PIN reset.'),
                              ),
                            );
                          },
                          child: const Text(
                            'Forgot PIN? Ask your manager',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: OutlinedButton(
              onPressed: () => _onKeyPress(key),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 60),
              ),
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
