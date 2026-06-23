import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/common_widgets.dart';
import '../widgets/glass_container.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  bool _canCheckBiometrics = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometrics();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _biometricEnabled = prefs.getBool('biometric_auth_enabled') ?? false;
    });
  }

  Future<void> _checkBiometrics() async {
    try {
      final isSupported = await _auth.isDeviceSupported() || await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();
      setState(() {
        _canCheckBiometrics = isSupported && available.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Error checking biometrics support: $e');
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      // Prompt user to set a PIN
      final pinSet = await _showSetPinDialog(context);
      if (pinSet != null) {
        await prefs.setBool('app_lock_enabled', true);
        await prefs.setString('app_lock_pin', pinSet);
        setState(() {
          _appLockEnabled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App Lock enabled successfully!')),
        );
      } else {
        // User cancelled PIN setup
        setState(() {
          _appLockEnabled = false;
        });
      }
    } else {
      // Prompt for confirmation using PIN
      final verified = await _showVerifyPinDialog(context);
      if (verified) {
        await prefs.setBool('app_lock_enabled', false);
        await prefs.setBool('biometric_auth_enabled', false);
        setState(() {
          _appLockEnabled = false;
          _biometricEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App Lock disabled.')),
        );
      }
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      // First verify with current PIN before enabling biometrics
      final verified = await _showVerifyPinDialog(context);
      if (verified) {
        await prefs.setBool('biometric_auth_enabled', true);
        setState(() {
          _biometricEnabled = true;
        });
      }
    } else {
      await prefs.setBool('biometric_auth_enabled', false);
      setState(() {
        _biometricEnabled = false;
      });
    }
  }

  Future<void> _changePin() async {
    // First verify current PIN
    final verified = await _showVerifyPinDialog(context);
    if (verified && mounted) {
      final newPin = await _showSetPinDialog(context, title: 'Change PIN');
      if (newPin != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_lock_pin', newPin);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated successfully!')),
        );
      }
    }
  }

  Future<String?> _showSetPinDialog(BuildContext context, {String title = 'Setup PIN'}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PinSetupDialog(title: title),
    );
  }

  Future<bool> _showVerifyPinDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_lock_pin') ?? '';
    if (savedPin.isEmpty) return true; // Safe fallback if no PIN was saved

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PinVerifyDialog(correctPin: savedPin),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'App Security Settings',
          subtitle: 'Secure your invoices and clients using PIN and biometric protection.',
        ),
        const SizedBox(height: 24),
        GlassContainer(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: Colors.white.withOpacity(0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle App Lock Switch
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.security, color: Color(0xFF007AFF)),
                ),
                title: const Text(
                  'App Lock Security',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                subtitle: const Text(
                  'Require authentication to access the app',
                  style: TextStyle(color: Color(0xFF4B5563)),
                ),
                trailing: Switch.adaptive(
                  value: _appLockEnabled,
                  activeColor: const Color(0xFF007AFF),
                  onChanged: _toggleAppLock,
                ),
              ),
              if (_appLockEnabled) ...[
                const Divider(height: 32),
                // Change PIN button
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.password, color: Colors.orange),
                  ),
                  title: const Text(
                    'Change 4-Digit PIN',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Change the current PIN code',
                    style: TextStyle(color: Color(0xFF4B5563)),
                  ),
                  trailing: OutlinedButton(
                    onPressed: _changePin,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF007AFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(color: Color(0xFF007AFF)),
                    ),
                  ),
                ),
                if (_canCheckBiometrics) ...[
                  const Divider(height: 32),
                  // Biometric Toggle Switch
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fingerprint, color: Colors.green),
                    ),
                    title: const Text(
                      'Biometric Authentication',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    subtitle: const Text(
                      'Use fingerprint or face ID to unlock',
                      style: TextStyle(color: Color(0xFF4B5563)),
                    ),
                    trailing: Switch.adaptive(
                      value: _biometricEnabled,
                      activeColor: Colors.green,
                      onChanged: _toggleBiometrics,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog({required this.title});
  final String title;

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isConfirmStep = false;
  String _errorText = '';

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final pin = _pinController.text;
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() {
        _errorText = 'PIN must be exactly 4 digits';
      });
      return;
    }
    setState(() {
      _isConfirmStep = true;
      _errorText = '';
    });
  }

  void _save() {
    final pin = _pinController.text;
    final confirm = _confirmController.text;
    if (pin != confirm) {
      setState(() {
        _errorText = 'PINs do not match. Try again.';
      });
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        color: Colors.white.withOpacity(0.9),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isConfirmStep ? 'Confirm PIN' : widget.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              _isConfirmStep
                  ? 'Re-enter your 4-digit PIN to confirm'
                  : 'Enter a 4-digit PIN code to secure your app access',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _isConfirmStep ? _confirmController : _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: TextStyle(letterSpacing: 10),
              ),
              onSubmitted: (_) {
                if (_isConfirmStep) {
                  _save();
                } else {
                  _nextStep();
                }
              },
            ),
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_errorText, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isConfirmStep ? _save : _nextStep,
                  child: Text(_isConfirmStep ? 'Save' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PinVerifyDialog extends StatefulWidget {
  const _PinVerifyDialog({required this.correctPin});
  final String correctPin;

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  final _controller = TextEditingController();
  String _errorText = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    if (_controller.text == widget.correctPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _controller.clear();
        _errorText = 'Incorrect PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        color: Colors.white.withOpacity(0.9),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter PIN',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter your current PIN to confirm action',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: TextStyle(letterSpacing: 10),
              ),
              onSubmitted: (_) => _verify(),
            ),
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_errorText, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _verify,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
