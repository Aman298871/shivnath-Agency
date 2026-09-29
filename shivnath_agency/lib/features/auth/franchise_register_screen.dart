import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../routes/app_routes.dart';
import 'package:file_picker/file_picker.dart' as import_file_picker;

class FranchiseRegisterScreen extends StatefulWidget {
  const FranchiseRegisterScreen({
    super.key,
  });

  @override
  State<FranchiseRegisterScreen> createState() =>
      _FranchiseRegisterScreenState();
}

class _FranchiseRegisterScreenState
    extends State<FranchiseRegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final ownerController = TextEditingController();
  final businessController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final cityController = TextEditingController();
  final addressController = TextEditingController();

  final territoryController = TextEditingController();
  final gstController = TextEditingController();
  final panController = TextEditingController();
  final aadhaarController = TextEditingController();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthService authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  String _selectedDocType = 'AADHAAR';
  String? _selectedFilePath;
  String? _selectedFileName;

  Future<void> _pickDocument() async {
    import_file_picker.FilePickerResult? result = await import_file_picker.FilePicker.platform.pickFiles(
      type: import_file_picker.FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _register() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedFilePath == null) {
      _message('Please upload a KYC Document');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final result = await authService.registerFranchise(
      ownerName: ownerController.text.trim(),
      businessName: businessController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
      city: cityController.text.trim(),
      address: addressController.text.trim(),
      territory: territoryController.text.trim(),
      gstNumber: gstController.text.trim(),
      panNumber: panController.text.trim(),
      aadhaarNumber: aadhaarController.text.trim(),
      documentType: _selectedDocType,
      documentFilePath: _selectedFilePath!,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result['success'] != true) {
      _message(
        result['message']?.toString() ??
            'Registration failed.',
      );
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Application Submitted',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your franchise registration request has been submitted successfully.\n\n'
          'Your account is currently pending Admin verification and approval. '
          'Once approved, you will be able to log in with your credentials.',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (_) => false,
                );
              },
              child: const Text(
                'Continue to Login',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _message(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  void dispose() {
    ownerController.dispose();
    businessController.dispose();
    phoneController.dispose();
    emailController.dispose();
    cityController.dispose();
    addressController.dispose();

    territoryController.dispose();
    gstController.dispose();
    panController.dispose();
    aadhaarController.dispose();

    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
            22,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(
                            context,
                          ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 36,
                    color: Color(0xFF059669),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                const Text(
                  'Franchise Registration',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                const Text(
                  'Submit your franchise application for admin approval',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(
                  height: 28,
                ),

                _field(
                  ownerController,
                  'Owner Name',
                  Icons.person_outline,
                ),

                _space(),

                _field(
                  businessController,
                  'Business / Franchise Name',
                  Icons.storefront_outlined,
                ),

                _space(),

                _field(
                  phoneController,
                  'Mobile Number',
                  Icons.phone_outlined,
                  keyboard:
                      TextInputType.phone,
                ),

                _space(),

                _field(
                  emailController,
                  'Email',
                  Icons.email_outlined,
                  keyboard:
                      TextInputType
                          .emailAddress,
                  email: true,
                ),

                _space(),

                _field(
                  cityController,
                  'City',
                  Icons.location_city_outlined,
                ),

                _space(),

                TextFormField(
                  controller:
                      addressController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(
                      Icons
                          .location_on_outlined,
                    ),
                    alignLabelWithHint:
                        true,
                  ),
                  validator: (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter address';
                    }

                    return null;
                  },
                ),

                _space(),

                TextFormField(
                  controller:
                      territoryController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Territory',
                    prefixIcon: Icon(
                      Icons.map_outlined,
                    ),
                    hintText:
                        'Example: Raipur North',
                  ),
                ),

                _space(),

                TextFormField(
                  controller:
                      gstController,
                  textCapitalization:
                      TextCapitalization
                          .characters,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'GST Number (Optional)',
                    prefixIcon: Icon(
                      Icons
                          .receipt_long_outlined,
                    ),
                  ),
                ),

                _space(),

                TextFormField(
                  controller:
                      panController,
                  textCapitalization:
                      TextCapitalization
                          .characters,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'PAN Number (Optional)',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                    ),
                  ),
                ),

                _space(),

                TextFormField(
                  controller:
                      aadhaarController,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Aadhaar Number (Optional)',
                    prefixIcon: Icon(
                      Icons
                          .credit_card_outlined,
                    ),
                  ),
                ),

                _space(),
                
                const Text('KYC Document', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedDocType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'AADHAAR', child: Text('Aadhaar Card')),
                    DropdownMenuItem(value: 'PAN', child: Text('PAN Card')),
                    DropdownMenuItem(value: 'GST', child: Text('GST Registration Certificate')),
                    DropdownMenuItem(value: 'AGREEMENT', child: Text('Distributor / Wholesale Agreement')),
                    DropdownMenuItem(value: 'TRADE_LICENSE', child: Text('Trade License')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other KYC Document')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDocType = val);
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDocument,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_selectedFileName ?? 'Upload Document (Image/PDF)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    alignment: Alignment.centerLeft,
                  ),
                ),

                _space(),

                TextFormField(
                  controller:
                      passwordController,
                  obscureText:
                      obscurePassword,
                  decoration:
                      InputDecoration(
                    labelText:
                        'Password',
                    prefixIcon:
                        const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword =
                              !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }

                    return null;
                  },
                ),

                _space(),

                TextFormField(
                  controller:
                      confirmPasswordController,
                  obscureText:
                      obscureConfirm,
                  decoration:
                      InputDecoration(
                    labelText:
                        'Confirm Password',
                    prefixIcon:
                        const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          obscureConfirm =
                              !obscureConfirm;
                        });
                      },
                      icon: Icon(
                        obscureConfirm
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value !=
                        passwordController
                            .text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 26,
                ),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isLoading
                        ? null
                        : _register,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Application',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                    ),
                    child: const Text(
                      'Already registered? Login',
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

  Widget _space() =>
      const SizedBox(
        height: 15,
      );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool email = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        final text =
            value?.trim() ?? '';

        if (text.isEmpty) {
          return 'Enter $label';
        }

        if (email &&
            !text.contains('@')) {
          return 'Enter valid email';
        }

        if (label ==
                'Mobile Number' &&
            text.length < 10) {
          return 'Enter valid mobile number';
        }

        return null;
      },
    );
  }
}