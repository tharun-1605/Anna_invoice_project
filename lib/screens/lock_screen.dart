import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_container.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final List<int> _pin = [];
  String _savedPin = '';
  bool _biometricEnabled = false;
  bool _hasBiometrics = false;
  final LocalAuthentication _auth = LocalAuthentication();
  String _message = 'Enter your 4-digit PIN to unlock';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndAuthenticate();
  }

  Future<void> _loadSettingsAndAuthenticate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('app_lock_pin') ?? '';
      _biometricEnabled = prefs.getBool('biometric_auth_enabled') ?? false;
    });

    if (_biometricEnabled) {
      try {
        final canAuth = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
        if (canAuth) {
          final available = await _auth.getAvailableBiometrics();
          if (available.isNotEmpty) {
            setState(() {
              _hasBiometrics = true;
            });
            // Auto trigger biometric auth
            _authenticateWithBiometrics();
          }
        }
      } catch (e) {
        debugPrint('Biometrics error: $e');
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Unlock Anna Invoice Studio',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        widget.onUnlocked();
      }
    } catch (e) {
      setState(() {
        _message = 'Biometric authentication failed. Enter PIN.';
      });
    }
  }

  void _onKeyPress(int number) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin.add(number);
      _isError = false;
      _message = 'Enter your 4-digit PIN to unlock';
    });

    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin.removeLast();
      _isError = false;
    });
  }

  void _verifyPin() {
    final enteredPin = _pin.join();
    if (enteredPin == _savedPin) {
      widget.onUnlocked();
    } else {
      setState(() {
        _pin.clear();
        _isError = true;
        _message = 'Incorrect PIN. Please try again.';
      });
      // Vibrate or show visual shake
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _message == 'Incorrect PIN. Please try again.') {
          setState(() {
            _isError = false;
            _message = 'Enter your 4-digit PIN to unlock';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0EAFC),
              Color(0xFFCFDEF3),
              Color(0xFFFDEBEE),
              Color(0xFFE8F5E9),
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassContainer(
                width: 400,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                color: Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock Icon Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF007AFF).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _isError ? Icons.lock_outline : Icons.lock_open_outlined,
                        size: 40,
                        color: _isError ? Colors.red : const Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Anna Invoice Studio',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isError ? Colors.red : const Color(0xFF4B5563),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final filled = index < _pin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? (_isError ? Colors.red : const Color(0xFF007AFF))
                                : Colors.transparent,
                            border: Border.all(
                              color: _isError
                                  ? Colors.red
                                  : (filled ? const Color(0xFF007AFF) : const Color(0xFF9CA3AF)),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 48),
                    // Keypad
                    Column(
                      children: [
                        _buildRow([1, 2, 3]),
                        const SizedBox(height: 16),
                        _buildRow([4, 5, 6]),
                        const SizedBox(height: 16),
                        _buildRow([7, 8, 9]),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Biometric button or empty
                            _hasBiometrics
                                ? _buildKeyButton(
                                    icon: Icons.fingerprint,
                                    onTap: _authenticateWithBiometrics,
                                  )
                                : const SizedBox(width: 72, height: 72),
                            _buildKeyButton(
                              text: '0',
                              onTap: () => _onKeyPress(0),
                            ),
                            _buildKeyButton(
                              icon: Icons.backspace_outlined,
                              onTap: _onBackspace,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<int> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) {
        return _buildKeyButton(
          text: n.toString(),
          onTap: () => _onKeyPress(n),
        );
      }).toList(),
    );
  }

  Widget _buildKeyButton({String? text, IconData? icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: text != null
            ? Text(
                text,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              )
            : Icon(
                icon,
                size: 24,
                color: const Color(0xFF111827),
              ),
      ),
    );
  }
}
