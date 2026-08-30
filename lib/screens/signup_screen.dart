import 'package:flutter/material.dart';

import '../services/app_localizations.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final phoneController = TextEditingController();

  bool loading = false;

  Future<void> signup() async {
    // ============================================================
    // PHONE NUMBER VALIDATION
    // ============================================================
    final phone = phoneController.text.trim();

    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      final l10n = AppLocalizations.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invalidPhoneNumber),
        ),
      );

      return;
    }

    // ============================================================
    // SIGNUP
    // ============================================================
    setState(() => loading = true);

    final error = await AuthService.register(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      name: nameController.text.trim(),
      age: ageController.text.trim(),
      phone: phone,
    );

    if (!mounted) return;

    setState(() => loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.signupSuccessful),
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],

      // Prevents keyboard from causing bottom overflow.
      resizeToAvoidBottomInset: true,

      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,

          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),

          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  40,
            ),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ========================================================
                // ICON
                // ========================================================
                const Icon(
                  Icons.person_add,
                  size: 80,
                  color: Colors.blue,
                ),

                const SizedBox(height: 20),

                // ========================================================
                // TITLE
                // ========================================================
                Text(
                  l10n.createAccount,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                // ========================================================
                // NAME
                // ========================================================
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: l10n.fullName,
                  ),
                ),

                const SizedBox(height: 10),

                // ========================================================
                // AGE
                // ========================================================
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: l10n.age,
                  ),
                ),

                const SizedBox(height: 10),

                // ========================================================
                // PHONE NUMBER
                // ========================================================
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,

                  // Maximum 10 characters from the UI.
                  maxLength: 10,

                  decoration: InputDecoration(
                    hintText: l10n.phoneNumber,

                    // Hide "0/10" counter.
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 10),

                // ========================================================
                // EMAIL
                // ========================================================
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: l10n.email,
                  ),
                ),

                const SizedBox(height: 10),

                // ========================================================
                // PASSWORD
                // ========================================================
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: l10n.password,
                  ),
                ),

                const SizedBox(height: 20),

                // ========================================================
                // SIGN UP BUTTON
                // ========================================================
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : signup,
                    child: loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l10n.signUp),
                  ),
                ),

                const SizedBox(height: 10),

                // ========================================================
                // LOGIN
                // ========================================================
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.alreadyHaveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}