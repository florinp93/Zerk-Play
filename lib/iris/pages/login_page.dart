import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../l10n/l10n.dart';

final class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final services = AppServicesScope.of(context);
      final u = await services.config.getEmbyUsername();
      final p = await services.config.getEmbyPassword();
      if (!mounted) return;
      if ((_usernameController.text.trim().isEmpty) && u != null) {
        _usernameController.text = u;
      }
      if ((_passwordController.text.isEmpty) && p != null) {
        _passwordController.text = p;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final services = AppServicesScope.of(context);
      await services.janus.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await services.config.setEmbyCredentials(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await services.apollo.registerCapabilities();
      try {
        await services.artemis.syncWithJanus(
          services.janus,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      } catch (_) {}

      if (!mounted) return;
      AppUiScope.of(context).isAuthenticated.value = true;
      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final l10n = context.l10n;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg,
                  Color.lerp(bg, Colors.black, 0.25) ?? bg,
                ],
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.loginWelcomeBack,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.loginSignInToContinue,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.82),
                          ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: l10n.username),
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: l10n.password),
                      obscureText: true,
                      onSubmitted: (_) => _isLoading ? null : _submit(),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.signIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
