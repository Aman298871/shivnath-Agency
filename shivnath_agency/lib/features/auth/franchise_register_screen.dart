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
  final fssaiNumberController = TextEditingController();
  final fssaiBusinessController = TextEditingController();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthService authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  String? _selectedFilePath;
  String? _selectedFileName;
  int? _selectedFileSize;

  Future<void> _pickDocument() async {
    import_file_picker.FilePickerResult? result = await import_file_picker.FilePicker.platform.pickFiles(
      type: import_file_picker.FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024) {
        _message('Certificate file must be under 10MB in size');
        return;
      }
      setState(() {
        _selectedFilePath = file.path;
        _selectedFileName = file.name;
        _selectedFileSize = file.size;
      });
    }
  }

  Future<void> _register() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final fssaiNum = fssaiNumberController.text.trim();
    if (!RegExp(r'^\d{14}$').hasMatch(fssaiNum)) {
      _message('Please enter a valid 14-digit FSSAI License/Registration Number');
      return;
    }

    if (_selectedFilePath == null) {
      _message('Please upload your FSSAI Certificate (PDF or Image)');
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
      fssaiNumber: fssaiNum,
      fssaiBusinessName: fssaiBusinessController.text.trim().isNotEmpty
          ? fssaiBusinessController.text.trim()
          : businessController.text.trim(),
      fssaiPremisesAddress: addressController.text.trim(),
      fssaiDistrict: cityController.text.trim(),
      documentType: 'FSSAI_CERTIFICATE',
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
    fssaiNumberController.dispose();
    fssaiBusinessController.dispose();

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

                // FSSAI Regulatory Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'FSSAI Details',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text(
                              'PENDING VERIFICATION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mandatory FoSCoS food safety compliance. Upload official FSSAI certificate (PDF/JPG/PNG, max 10MB).',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: fssaiNumberController,
                        keyboardType: TextInputType.number,
                        maxLength: 14,
                        decoration: const InputDecoration(
                          labelText: 'FSSAI License/Registration Number *',
                          hintText: '14-digit numeric FoSCoS number',
                          prefixIcon: Icon(Icons.assignment_turned_in_rounded),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'FSSAI License/Registration Number is required';
                          }
                          if (!RegExp(r'^\d{14}$').hasMatch(value.trim())) {
                            return 'FSSAI Number must be exactly 14 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: fssaiBusinessController,
                        decoration: const InputDecoration(
                          labelText: 'FSSAI Business Name (Optional)',
                          hintText: 'As registered on FoSCoS certificate',
                          prefixIcon: Icon(Icons.business_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'FSSAI Certificate *',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _pickDocument,
                        icon: Icon(
                          _selectedFilePath != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                          color: _selectedFilePath != null ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                        ),
                        label: Text(
                          _selectedFileName != null
                              ? '$_selectedFileName${_selectedFileSize != null ? ' (${(_selectedFileSize! / 1024).toStringAsFixed(1)} KB)' : ''}'
                              : 'Upload FSSAI Certificate (PDF / Image)',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          alignment: Alignment.centerLeft,
                          side: BorderSide(
                            color: _selectedFilePath != null ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                          ),
                          backgroundColor: _selectedFilePath != null ? const Color(0xFFF0FDF4) : Colors.white,
                        ),
                      ),
                    ],
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