import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Mandatory first-login password change. Deliberately has no back button
/// and no skip option — an employee logging in with a temporary password
/// must set a real one before reaching the rest of the app.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final state = context.read<AppState>();
    if (state.isChangingPassword) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    state.submitNewPassword(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return PopScope(
      canPop: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.7, -0.85),
            radius: 1.1,
            colors: [Color(0x332FE0A0), AppColors.bg],
            stops: [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 40, 26, 26),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset, color: AppColors.accent, size: 30),
                ),
                Text('Buat Password Baru', style: AppText.heading(size: 22)),
                const SizedBox(height: 6),
                Text(
                  'Demi keamanan, silakan buat password baru untuk akun Anda.',
                  style: AppText.body(size: 13, color: AppColors.mut),
                ),
                const SizedBox(height: 30),
                _label('Password Baru'),
                const SizedBox(height: 6),
                _field(
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Password minimal 8 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _label('Konfirmasi Password Baru'),
                const SizedBox(height: 6),
                _field(
                  controller: _confirmController,
                  obscure: _obscureConfirm,
                  onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Konfirmasi password tidak sama.';
                    }
                    return null;
                  },
                ),
                if (state.changePasswordError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0x1FEF4444),
                      border: Border.all(color: const Color(0x66EF4444)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 17, color: Color(0xFFEF4444)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          state.changePasswordError!,
                          style: AppText.body(size: 12.5, color: const Color(0xFFEF4444)),
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: state.isChangingPassword ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: const Color(0xFF06231A),
                      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: state.isChangingPassword
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF06231A)),
                          )
                        : Text('Simpan Password', style: AppText.heading(size: 17, color: const Color(0xFF06231A))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: AppText.body(size: 12, color: AppColors.mut));

  Widget _field({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required FormFieldValidator<String> validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card2,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Padding(
          padding: EdgeInsets.only(left: 13, right: 10),
          child: Icon(Icons.lock_outline, size: 17, color: AppColors.mut),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            style: AppText.body(size: 14),
            cursorColor: AppColors.accent,
            validator: validator,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
              errorStyle: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: AppColors.mut,
          ),
          onPressed: onToggleObscure,
        ),
      ]),
    );
  }
}
