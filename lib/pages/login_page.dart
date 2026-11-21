import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/api_config.dart';
import '../config/environment_config.dart';
import '../services/app_update_service.dart';
import '../services/notification_service.dart';
import 'technician_dashboard_page.dart';

/// Production-ready Paradesk Technician Login Screen.
/// Clean, executive aesthetic:
/// - Crisp white background
/// - Left-aligned professional brand header (logo emblem + high-contrast title)
/// - Elevated floating form card with soft ambient shadow
/// - Centered "Sign in" headline
/// - 4 interactive states (Default, Active Focus Glow, Authenticating Loader, Validation Error)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkAndShowUpdateDialog(context);
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _clearErrorOnTyping() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  void _togglePasswordVisibility() {
    setState(() => _hidePassword = !_hidePassword);
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xff2563eb)),
            SizedBox(width: 8),
            Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Technician accounts are managed centrally.\n\nPlease contact your Paramount Desk Support or Helpdesk administrator to reset your login credentials.',
          style: TextStyle(fontSize: 13.5, color: Color(0xff475569), height: 1.4),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff2563eb),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.headset_mic_outlined, color: Color(0xff2563eb)),
            SizedBox(width: 8),
            Text('Paramount Support Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For technical assistance, connectivity issues, or portal access requests:',
              style: TextStyle(fontSize: 13, color: Color(0xff475569)),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.email_outlined, size: 16, color: Color(0xff2563eb)),
                SizedBox(width: 8),
                Text('support@paramountindia.co.in', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.corporate_fare_rounded, size: 16, color: Color(0xff2563eb)),
                SizedBox(width: 8),
                Text('Paramount Office Systems', style: TextStyle(fontSize: 12.5, color: Color(0xff334155), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _error = 'Please fill in both fields to continue.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    var currentUrl = await ApiConfig.getBaseUrl();
    if (!currentUrl.endsWith('/')) {
      currentUrl = '$currentUrl/';
    }

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: currentUrl,
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 25),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

      final response = await dio.post(
        'login',
        data: {'username': username, 'password': password},
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final token = data['token'] as String;
      final userData = Map<String, dynamic>.from(data['user'] as Map);

      await ApiConfig.setBaseUrl(currentUrl);
      await ApiConfig.setToken(token);
      await ApiConfig.setUser(userData);

      // Register device FCM push notification token with backend
      NotificationService.syncTokenWithServer();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TechnicianDashboardPage(user: userData),
        ),
      );
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map ? responseData['message'] : null;

      if (error.response?.statusCode == 400 || error.response?.statusCode == 401) {
        setState(() {
          _error = message?.toString() ?? 'Invalid credentials. Please verify your username or password.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = message?.toString() ??
            'Unable to connect to server ($currentUrl). Please check your internet or local backend.';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to sign in. Please verify your credentials and network connection.';
          _loading = false;
        });
      }
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Professional Brand Header (Left-aligned, properly padded from screen edge)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: _LoginBrandHeader(),
                          ),

                          const SizedBox(height: 20),

                          // 2. Elevated Floating Card Container (Option B: Balanced Portrait Proportions)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: const Color(0xffe2e8f0), width: 1.2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0e0f172a),
                                  blurRadius: 36,
                                  offset: Offset(0, 14),
                                ),
                                BoxShadow(
                                  color: Color(0x050f172a),
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Centered "Sign in" Headline & Helper Subtitle
                              const _LoginHeadlineSection(),

                              const SizedBox(height: 26),

                              // Username or Employee ID Input Field (Taller 56px Touch Target)
                              _LoginInputField(
                                controller: _usernameController,
                                focusNode: _usernameFocusNode,
                                label: 'Username or Employee ID',
                                hintText: 'e.g., EMP409 or john.doe',
                                prefixIcon: Icons.badge_outlined,
                                textInputAction: TextInputAction.next,
                                enabled: !_loading,
                                hasError: _error != null,
                                onChanged: (_) => _clearErrorOnTyping(),
                                onSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                                },
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your username or employee ID';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),

                              const SizedBox(height: 18),

                              // Password Input Field (Taller 56px Touch Target with Show/Hide Toggle)
                              _LoginInputField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                label: 'Password',
                                hintText: '••••••••••••',
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.done,
                                enabled: !_loading,
                                hasError: _error != null,
                                onChanged: (_) => _clearErrorOnTyping(),
                                onSubmitted: (_) => _signIn(),
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                                  onPressed: _loading ? null : _togglePasswordVisibility,
                                  icon: Icon(
                                    _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: const Color(0xff94a3b8),
                                    size: 20,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

                              // Right-Aligned "Forgot Password?" Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: InkWell(
                                    onTap: _loading ? null : _showForgotPasswordDialog,
                                    borderRadius: BorderRadius.circular(6),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xff475569),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Inline Validation / Network Error Banner
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                _LoginErrorBanner(message: _error!),
                              ],

                              const SizedBox(height: 24),

                              // Primary 54px Action Button (with Loading & Disabled States)
                              _LoginSubmitButton(
                                loading: _loading,
                                onPressed: _signIn,
                              ).animate().fadeIn(delay: 250.ms),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),

                        const SizedBox(height: 22),

                        // 3. Secondary Assistance Link
                        Center(
                          child: InkWell(
                            onTap: _showSupportDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Text(
                                'Need assistance? Contact Desk Support',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff2563eb),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // 4. Bottom Copyright Footer (with Secret Debug Switcher on Long-Press)
                        Center(
                          child: _LoginFooter(
                            onLongPress: kDebugMode ? _showServerConfigDialog : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  }

  void _showServerConfigDialog() async {
    if (!kDebugMode) return;

    final currentUrl = await ApiConfig.getBaseUrl();
    final customIpController = TextEditingController(text: currentUrl);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _ServerConfigDialog(
        currentUrl: currentUrl,
        customIpController: customIpController,
        onSelectUrl: (url) async {
          await ApiConfig.setBaseUrl(url);
          if (mounted && ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Switched server API to: $url')),
            );
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modular Sub-Widgets (Clean Architecture)
// ---------------------------------------------------------------------------

/// Brand header with squircle logo emblem on left and high-contrast brand title stack.
class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Squircle Logo Emblem Container (62px)
        const _ParadeskBrandMark(),

        const SizedBox(width: 14),

        // Brand Typography Stack
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Paradesk',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  color: Color(0xff0f172a),
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'PARAMOUNT OFFICE SYSTEMS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xff334155), // High-contrast, sharp slate
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

/// Squircle brand mark that renders the emblem asset or crisp vector wave fallback.
class _ParadeskBrandMark extends StatelessWidget {
  const _ParadeskBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.all(8.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xfff1f5f9), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100f172a),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/app_icon_emblem.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/paramount_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => CustomPaint(
            painter: _ParadeskWavePainter(),
          ),
        ),
      ),
    );
  }
}

/// Precise vector painter for Paramount Tri-Color Wave Ribbon (Grey, Cyan, Royal Blue).
class _ParadeskWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Grey Top Triangle Ribbon
    final greyPaint = Paint()
      ..color = const Color(0xff94a3b8)
      ..style = PaintingStyle.fill;
    final greyPath = Path()
      ..moveTo(w * 0.15, h * 0.80)
      ..lineTo(w * 0.50, h * 0.25)
      ..lineTo(w * 0.65, h * 0.45)
      ..quadraticBezierTo(w * 0.45, h * 0.60, w * 0.15, h * 0.80)
      ..close();
    canvas.drawPath(greyPath, greyPaint);

    // 2. Cyan Middle Ribbon
    final cyanPaint = Paint()
      ..color = const Color(0xff38bdf8)
      ..style = PaintingStyle.fill;
    final cyanPath = Path()
      ..moveTo(w * 0.22, h * 0.83)
      ..quadraticBezierTo(w * 0.55, h * 0.52, w * 0.85, h * 0.56)
      ..quadraticBezierTo(w * 0.60, h * 0.72, w * 0.22, h * 0.83)
      ..close();
    canvas.drawPath(cyanPath, cyanPaint);

    // 3. Royal Blue Bottom Ribbon
    final bluePaint = Paint()
      ..color = const Color(0xff1d4ed8)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(w * 0.28, h * 0.89)
      ..quadraticBezierTo(w * 0.65, h * 0.73, w * 0.95, h * 0.75)
      ..quadraticBezierTo(w * 0.65, h * 0.93, w * 0.28, h * 0.89)
      ..close();
    canvas.drawPath(bluePath, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Centered "Sign in" headline with helper subtitle inside the card.
class _LoginHeadlineSection extends StatelessWidget {
  const _LoginHeadlineSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        Text(
          'Sign in',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xff0f172a),
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Enter your credentials to access the workspace.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xff64748b),
          ),
        ),
      ],
    );
  }
}

/// Reusable input field ensuring 52px touch targets, dynamic focus glow, and smooth error states.
class _LoginInputField extends StatefulWidget {
  const _LoginInputField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.focusNode,
    this.obscureText = false,
    this.hasError = false,
    this.enabled = true,
    this.textInputAction,
    this.suffixIcon,
    this.onSubmitted,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool hasError;
  final bool enabled;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  State<_LoginInputField> createState() => _LoginInputFieldState();
}

class _LoginInputFieldState extends State<_LoginInputField> {
  late FocusNode _focusNode;
  bool _internalFocus = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _internalFocus = true;
    } else {
      _focusNode = widget.focusNode!;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_internalFocus) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != _focusNode.hasFocus) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasErr = widget.hasError;
    final isFocused = _isFocused && widget.enabled;

    Color iconColor;
    if (hasErr) {
      iconColor = const Color(0xffe11d48);
    } else if (isFocused) {
      iconColor = const Color(0xff2563eb);
    } else {
      iconColor = const Color(0xff64748b);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: hasErr ? const Color(0xffbe123c) : const Color(0xff1e293b),
          ),
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: hasErr
                ? const [
                    BoxShadow(
                      color: Color(0x18e11d48),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : isFocused
                    ? const [
                        BoxShadow(
                          color: Color(0x1a2563eb),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            obscureText: widget.obscureText,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            validator: widget.validator,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xff0f172a),
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Color(0xff94a3b8),
              ),
              prefixIcon: Icon(widget.prefixIcon, size: 21, color: iconColor),
              suffixIcon: widget.suffixIcon,
              filled: true,
              fillColor: hasErr
                  ? const Color(0xfffff1f2)
                  : (widget.enabled ? Colors.white : const Color(0xfff8fafc)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xffcbd5e1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasErr ? const Color(0xfffb7185) : const Color(0xffcbd5e1),
                  width: hasErr ? 1.5 : 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasErr ? const Color(0xffe11d48) : const Color(0xff2563eb),
                  width: 2.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xffe11d48), width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xffe11d48), width: 2.0),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xffe2e8f0)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 54px prominent primary action button supporting normal, authenticating, and disabled states.
class _LoginSubmitButton extends StatelessWidget {
  const _LoginSubmitButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: loading
              ? [const Color(0xff1d4ed8), const Color(0xff1e40af)]
              : [const Color(0xff2563eb), const Color(0xff1d4ed8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: loading
            ? const [
                BoxShadow(
                  color: Color(0x201d4ed8),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x402563eb),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: loading
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Authenticating...',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('idle'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Sign In to Workspace',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Animated inline validation / API error banner.
class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xfffff1f2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xfffecdd3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xffbe123c)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xffbe123c),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).shake(duration: 350.ms);
  }
}

/// Copyright footer with secret debug developer switcher on long-press.
class _LoginFooter extends StatelessWidget {
  const _LoginFooter({this.onLongPress});
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          '© Paramount Office Systems • Paradesk v3.8',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xff94a3b8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Server connection switcher modal (available only during debug mode).
class _ServerConfigDialog extends StatelessWidget {
  const _ServerConfigDialog({
    required this.currentUrl,
    required this.customIpController,
    required this.onSelectUrl,
  });

  final String currentUrl;
  final TextEditingController customIpController;
  final ValueChanged<String> onSelectUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.tune, color: Color(0xff1e3a8a)),
          SizedBox(width: 8),
          Text(
            'Server Connection Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select which backend server your mobile app connects to (Debug only):',
            style: TextStyle(fontSize: 13, color: Color(0xff475569)),
          ),
          const SizedBox(height: 14),

          // Option 1: Live Production
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: currentUrl.contains('paradesk.cloud')
                    ? const Color(0xff2563eb)
                    : const Color(0xffcbd5e1),
              ),
            ),
            tileColor: currentUrl.contains('paradesk.cloud') ? const Color(0xffeff6ff) : null,
            leading: const Icon(Icons.cloud_done, color: Color(0xff2563eb)),
            title: const Text(
              'Live Production Server',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              EnvironmentConfig.productionBaseUrl,
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => onSelectUrl(EnvironmentConfig.productionBaseUrl),
          ),
          const SizedBox(height: 8),

          // Option 2: Local USB
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: (currentUrl.contains('127.0.0.1') || currentUrl.contains('localhost'))
                    ? const Color(0xff8b5cf6)
                    : const Color(0xffcbd5e1),
              ),
            ),
            tileColor: (currentUrl.contains('127.0.0.1') || currentUrl.contains('localhost'))
                ? const Color(0xfff5f3ff)
                : null,
            leading: const Icon(Icons.usb, color: Color(0xff8b5cf6)),
            title: const Text(
              'Local USB Cable Testing (ADB)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              EnvironmentConfig.defaultDevBaseUrl,
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => onSelectUrl(EnvironmentConfig.defaultDevBaseUrl),
          ),
          const SizedBox(height: 14),

          // Custom IP Input
          TextField(
            controller: customIpController,
            decoration: const InputDecoration(
              labelText: 'Custom API URL',
              hintText: 'http://192.168.1.X:4000/api or http://10.0.2.2:4000/api',
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff2563eb),
          ),
          onPressed: () {
            final val = customIpController.text.trim();
            if (val.isNotEmpty) onSelectUrl(val);
          },
          child: const Text('Save Custom URL'),
        ),
      ],
    );
  }
}
