import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = true;
  bool _obscure = true;
  bool _loading = false;

  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _setMode(bool isRegister) {
    if (_isRegister == isRegister || _loading) return;
    HapticFeedback.selectionClick();
    setState(() => _isRegister = isRegister);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (phone.isEmpty) {
      _showError('Telefon raqamingizni kiriting');
      return;
    }
    if (password.isEmpty) {
      _showError('Parolingizni kiriting');
      return;
    }

    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      if (_isRegister) {
        await AuthService.instance.registerWithPhone(phone, password);
      } else {
        await AuthService.instance.loginWithPhone(phone, password);
      }
      // Muvaffaqiyatli bo'lsa AuthGate avtomatik MainShell'ga o'tkazadi.
    } on FormatException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: _AnimatedEntry(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildModeSwitch(),
                        const SizedBox(height: 22),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            _isRegister
                                ? "Sevimlilar va boshqa imkoniyatlardan\nfoydalanish uchun ro'yxatdan o'ting"
                                : 'Davom etish uchun akkountingizga kiring',
                            key: ValueKey(_isRegister),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildPhoneField(),
                        const SizedBox(height: 14),
                        _buildPasswordField(),
                        const SizedBox(height: 26),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(36),
        bottomRight: Radius.circular(36),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 28, bottom: 34),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryLight, AppTheme.primaryDark],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -46,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'NatureGo',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "O'zbekiston tabiati siz bilan",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment:
                _isRegister ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildModeTab("Ro'yxatdan o'tish", true),
              ),
              Expanded(
                child: _buildModeTab('Kirish', false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, bool isRegisterTab) {
    final isActive = _isRegister == isRegisterTab;
    return GestureDetector(
      onTap: () => _setMode(isRegisterTab),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? AppTheme.primaryDark : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneCtrl,
      focusNode: _phoneFocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
        _PhoneGroupFormatter(),
      ],
      decoration: const InputDecoration(
        labelText: 'Telefon raqam',
        hintText: '90 123 45 67',
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 16, right: 8),
          child: Center(
            widthFactor: 1,
            child: Text('+998',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMain)),
          ),
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordCtrl,
      focusNode: _passwordFocus,
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'Parol',
        hintText: 'Kamida 6 belgi',
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            size: 20, color: AppTheme.textSecondary),
        suffixIcon: IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              _obscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              key: ValueKey(_obscure),
              size: 20,
              color: AppTheme.textSecondary,
            ),
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppTheme.primary, AppTheme.primaryDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: _loading ? null : _submit,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        key: ValueKey(_isRegister),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isRegister ? "Ro'yxatdan o'tish" : 'Kirish',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "90 123 45 67" ko'rinishida guruhlab yozadi (2-3-2-2).
class _PhoneGroupFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 4 || i == 6) {
        if (i != digits.length - 1) buffer.write(' ');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Ekran birinchi ochilganda yumshoq fade+slide bilan kiritadi.
class _AnimatedEntry extends StatelessWidget {
  final Widget child;
  const _AnimatedEntry({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 24),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
