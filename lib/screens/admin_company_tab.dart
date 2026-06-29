import '../core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminCompanyTab extends StatefulWidget {
  const AdminCompanyTab({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  State<AdminCompanyTab> createState() => _AdminCompanyTabState();
}

class _AdminCompanyTabState extends State<AdminCompanyTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _siretController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _siretController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = (data['companyName'] ?? '').toString();
        _addressController.text = (data['address'] ?? '').toString();
        _siretController.text = (data['siret'] ?? '').toString();
        _phoneController.text = (data['phone'] ?? '').toString();
        // Fallback : adminEmail est le champ écrit à l'inscription
        _emailController.text = (data['email']?.toString().isNotEmpty == true
                ? data['email']
                : data['adminEmail'] ?? '')
            .toString();
      }
    } catch (_) {
      // Silently ignore load errors
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId)
          .set(
        {
          'companyName': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'siret': _siretController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informations mises à jour.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations entreprise',
              style: TextStyle(
                color: AppColors.grey900,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ces informations s\'affichent sur vos devis.',
              style: TextStyle(color: AppColors.grey300, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _DarkField(
              controller: _nameController,
              label: 'Nom de l\'entreprise',
              icon: Icons.business_outlined,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Le nom est requis';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _DarkField(
              controller: _addressController,
              label: 'Adresse du siège',
              icon: Icons.location_on_outlined,
              maxLines: 2,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'L\'adresse est requise';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _DarkField(
              controller: _siretController,
              label: 'SIRET',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Le SIRET est requis';
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Coordonnées publiques',
              style: TextStyle(color: AppColors.grey600, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ces informations apparaîtront sur vos devis.',
              style: TextStyle(color: AppColors.grey300, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _DarkField(
              controller: _phoneController,
              label: 'Téléphone (optionnel)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            _DarkField(
              controller: _emailController,
              label: 'Email de contact (optionnel)',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Text(
                        'Enregistrer les modifications',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.label,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: AppColors.grey900),
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.grey400),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.grey300, size: 20) : null,
        counterText: '',
        filled: true,
        fillColor: AppColors.grey100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.grey200),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
