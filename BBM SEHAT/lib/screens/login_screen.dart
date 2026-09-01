import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _submit() {
    final state = context.read<AppState>();
    if (state.isLoggingIn) return;
    state.login(_idController.text, _pwController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.7, -0.85),
          radius: 1.1,
          colors: [Color(0x332FE0A0), AppColors.bg],
          stops: [0, 0.55],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(
                width: 84,
                height: 84,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: AppColors.accent.withValues(alpha: 0.15), blurRadius: 32),
                  ],
                ),
                child: Center(
                  child: Image.asset('assets/images/logo-bbm.png', height: 38),
                ),
              ),
              Text('Masuk ke BBM Sehat', style: AppText.heading(size: 20)),
              const SizedBox(height: 4),
              Text('Gunakan akun karyawan PT BBM',
                  style: AppText.body(size: 12.5, color: AppColors.mut)),
            ]),
            const SizedBox(height: 30),
            _label('ID Karyawan'),
            const SizedBox(height: 6),
            _field(controller: _idController, icon: Icons.person_outline),
            const SizedBox(height: 14),
            _label('Kata Sandi'),
            const SizedBox(height: 6),
            _field(
              controller: _pwController,
              icon: Icons.lock_outline,
              obscure: state.obscurePassword,
              trailing: IconButton(
                icon: Icon(
                  state.obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: AppColors.mut,
                ),
                onPressed: state.togglePasswordVisibility,
              ),
            ),
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(
                child: GestureDetector(
                  onTap: state.toggleRemember,
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 22,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: state.rememberMe ? AppColors.accent : const Color(0xFF3A3A3A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: state.rememberMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text('Ingat saya',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Text('Lupa sandi?', style: AppText.body(size: 13, color: AppColors.accent)),
            ]),
            if (state.loginError != null) ...[
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
                      state.loginError!,
                      style: AppText.body(size: 12.5, color: const Color(0xFFEF4444)),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: state.isLoggingIn ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: const Color(0xFF06231A),
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: state.isLoggingIn
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF06231A)),
                      )
                    : Text('Masuk', style: AppText.heading(size: 17, color: const Color(0xFF06231A))),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Divider(color: AppColors.line, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('atau', style: AppText.body(size: 11, color: AppColors.dim)),
              ),
              const Expanded(child: Divider(color: AppColors.line, height: 1)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Login biometrik belum tersedia.')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.line),
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.fingerprint, size: 19, color: AppColors.accent),
                label: Text('Masuk dengan biometrik', style: AppText.body(size: 14)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum punya akun? Hubungi admin SDM perusahaan.',
              textAlign: TextAlign.center,
              style: AppText.body(size: 11.5, color: AppColors.mut),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: AppText.body(size: 12, color: AppColors.mut));

  Widget _field({
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card2,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 13, right: 10),
          child: Icon(icon, size: 17, color: AppColors.mut),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: AppText.body(size: 14),
            cursorColor: AppColors.accent,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (trailing != null) trailing else const SizedBox(width: 6),
      ]),
    );
  }
}
