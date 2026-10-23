import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config.dart';
import '../../data/providers/call_provider.dart';
import '../../data/services/rtc_call_service.dart';
import 'audio_call_screen.dart';
import 'rtc_debug_log_screen.dart';

class RtcConnectionScreen extends ConsumerStatefulWidget {
  const RtcConnectionScreen({super.key});

  @override
  ConsumerState<RtcConnectionScreen> createState() => _RtcConnectionScreenState();
}

class _RtcConnectionScreenState extends ConsumerState<RtcConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseUrlController;
  late TextEditingController _dbController;
  late TextEditingController _loginController;
  late TextEditingController _passwordController;
  late TextEditingController _channelIdController;

  bool _isLoggingIn = false;
  bool _isJoiningCall = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: CallConfig.defaultBaseUrl);
    _dbController = TextEditingController(text: CallConfig.defaultDb);
    _loginController = TextEditingController(text: CallConfig.defaultLogin);
    _passwordController = TextEditingController(text: CallConfig.defaultPassword);
    _channelIdController = TextEditingController(text: CallConfig.defaultChannelId.toString());
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _dbController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _channelIdController.dispose();
    super.dispose();
  }

  void _loadDefaults() {
    setState(() {
      _baseUrlController.text = CallConfig.defaultBaseUrl;
      _dbController.text = CallConfig.defaultDb;
      _loginController.text = CallConfig.defaultLogin;
      _passwordController.text = CallConfig.defaultPassword;
      _channelIdController.text = CallConfig.defaultChannelId.toString();
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoggingIn = true);
    final odooApi = ref.read(odooApiProvider);

    final success = await odooApi.authenticate(
      baseUrl: _baseUrlController.text.trim(),
      db: _dbController.text.trim(),
      login: _loginController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoggingIn = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged in successfully as ${odooApi.userName ?? _loginController.text}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Check credentials and server URL in Debug Logs.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _handleJoinCall() async {
    final odooApi = ref.read(odooApiProvider);
    if (odooApi.sessionCookie == null || odooApi.sessionCookie!.isEmpty) {
      // Auto-authenticate first
      final loginSuccess = await odooApi.authenticate(
        baseUrl: _baseUrlController.text.trim(),
        db: _dbController.text.trim(),
        login: _loginController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!loginSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in before joining the call.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }
    }

    final channelId = int.tryParse(_channelIdController.text.trim()) ?? CallConfig.defaultChannelId;

    setState(() => _isJoiningCall = true);
    final rtcCallService = ref.read(rtcCallServiceProvider);

    final joined = await rtcCallService.joinCall(channelId: channelId);
    setState(() => _isJoiningCall = false);

    if (joined && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AudioCallScreen(
            extra: {
              'channel_id': channelId,
              'callee_name': 'Channel #$channelId Voice Call',
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final odooApi = ref.watch(odooApiProvider);
    final rtcCallService = ref.watch(rtcCallServiceProvider);
    final isAuthenticated = odooApi.sessionCookie != null && odooApi.sessionCookie!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Odoo Voice Call (Buddy)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Live Diagnostics',
            icon: const Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RtcDebugLogScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection status header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAuthenticated ? const Color(0xFF059669) : const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          isAuthenticated ? const Color(0xFF059669).withValues(alpha: 0.2) : const Color(0xFF334155),
                      child: Icon(
                        isAuthenticated ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                        color: isAuthenticated ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAuthenticated
                                ? 'Authenticated (${odooApi.userName ?? 'User'})'
                                : 'Not Authenticated',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isAuthenticated
                                ? 'Cookie: session_id=${odooApi.sessionCookie!.substring(0, 8)}...'
                                : 'Enter credentials to connect',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: _loadDefaults,
                      child: const Text('Defaults', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Server URL Field
              _buildTextField(
                controller: _baseUrlController,
                label: 'Odoo Base URL (HTTPS ngrok)',
                icon: Icons.link_rounded,
                hint: 'https://xxx.ngrok-free.dev',
              ),
              const SizedBox(height: 14),

              // Database Field
              _buildTextField(
                controller: _dbController,
                label: 'Database Name',
                icon: Icons.storage_rounded,
                hint: 'test18',
              ),
              const SizedBox(height: 14),

              // Login Field
              _buildTextField(
                controller: _loginController,
                label: 'Login Email / Username',
                icon: Icons.person_rounded,
                hint: 'buddy@example.com',
              ),
              const SizedBox(height: 14),

              // Password Field
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_rounded,
                obscureText: true,
              ),
              const SizedBox(height: 14),

              // Channel ID Field
              _buildTextField(
                controller: _channelIdController,
                label: 'Discuss Channel ID',
                icon: Icons.tag_rounded,
                keyboardType: TextInputType.number,
                hint: '1',
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoggingIn ? null : _handleLogin,
                      icon: _isLoggingIn
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded, color: Colors.white),
                      label: Text(
                        _isLoggingIn ? 'Logging In...' : '1. Login',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isJoiningCall ? null : _handleJoinCall,
                      icon: _isJoiningCall
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.call_rounded, color: Colors.white),
                      label: Text(
                        _isJoiningCall ? 'Connecting...' : '2. Join Voice Call',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Debug screen button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RtcDebugLogScreen()),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Open Real-Time Diagnostics & Copy Logs'),
              ),

              const SizedBox(height: 24),
              // Call status info if active
              if (rtcCallService.status != CallStatus.idle) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors_rounded, color: Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      Text(
                        'Call Status: ${rtcCallService.status.name.toUpperCase()} (Duration: ${rtcCallService.callDuration}s)',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF38BDF8)),
        ),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }
}
