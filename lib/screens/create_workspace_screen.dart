import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/onboarding_models.dart';
import 'plan_selection_screen.dart';

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.uid,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String uid;

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

// Fallback local si l'API ne renvoie rien ou échoue.
const Map<String, List<String>> _postalFallback = {
  '06600': ['Antibes', 'Juan-les-Pins'],
  '06460': ['Caussols', 'Escragnolles', 'Saint-Vallier-de-Thiey'],
  '75001': ['Paris'],
  '13001': ['Marseille'],
  '69001': ['Lyon'],
  '33000': ['Bordeaux'],
  '31000': ['Toulouse'],
  '59000': ['Lille'],
};

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final siretController = TextEditingController();
  final addressController = TextEditingController();
  final postalCodeController = TextEditingController();
  final cityController = TextEditingController();
  List<String> citySuggestions = [];
  bool isFetchingCities = false;
  String? _lastPostalLookup;

  @override
  void dispose() {
    nameController.dispose();
    siretController.dispose();
    addressController.dispose();
    postalCodeController.dispose();
    cityController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!formKey.currentState!.validate()) return;
    final data = OnboardingData(
      companyName: nameController.text.trim(),
      siret: siretController.text.trim(),
      address: addressController.text.trim(),
      postalCode: postalCodeController.text.trim(),
      city: cityController.text.trim(),
    )
      ..adminEmail = widget.email
      ..adminUid = widget.uid
      ..creatorFirstName = widget.firstName
      ..creatorLastName = widget.lastName
      ..tradeKey = 'menuiserie_aluminium';

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlanSelectionScreen(data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF07090D);
    const accent = Color(0xFF00E676);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepProgress(current: 2, total: 3),
              const SizedBox(height: 28),
              const Text(
                'Mon entreprise',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ces informations s\'afficheront sur vos devis et métrés.',
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 28),
              _DarkField(
                controller: nameController,
                label: 'Nom de l\'entreprise',
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 14),
              _DarkField(
                controller: siretController,
                label: 'SIRET (optionnel)',
                keyboardType: TextInputType.number,
                maxLength: 14,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (v.length != 14) return '14 chiffres requis';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _DarkField(
                controller: addressController,
                label: 'Adresse du siège',
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Adresse requise' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _DarkField(
                      controller: postalCodeController,
                      label: 'Code postal',
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onPostalCodeChanged,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requis';
                        if (v.length != 5) return '5 chiffres';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _DarkField(
                      controller: cityController,
                      label: 'Ville',
                      readOnly: true,
                      onTap: () {
                        if (citySuggestions.length > 1) {
                          _showCitySelector(citySuggestions);
                        }
                      },
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Ville requise' : null,
                      hintText: isFetchingCities ? 'Chargement...' : 'Auto (CP)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _continue,
                  child: const Text('Continuer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Étape $current sur $total',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(total, (i) {
            final done = i < current;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF00E676)
                      : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.maxLength,
    this.readOnly = false,
    this.onChanged,
    this.onTap,
    this.hintText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool readOnly;
  final void Function(String)? onChanged;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLength: maxLength,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: const Color(0xFF0F1422),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

extension on _CreateWorkspaceScreenState {
  Future<void> _onPostalCodeChanged(String value) async {
    final postalCode = value.trim();
    if (postalCode.length == 5 && RegExp(r'^\d{5}$').hasMatch(postalCode)) {
      if (postalCode == _lastPostalLookup) return;
      _lastPostalLookup = postalCode;
      await _fetchCitiesForPostalCode(postalCode);
    } else {
      setState(() {
        cityController.clear();
        citySuggestions = [];
      });
    }
  }

  Future<void> _fetchCitiesForPostalCode(String postalCode) async {
    setState(() {
      isFetchingCities = true;
      citySuggestions = [];
      cityController.clear();
    });

    try {
      final url = Uri.parse(
        'https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data =
            json.decode(response.body) as List<dynamic>;
        final List<String> cities =
            data.map((c) => c['nom'].toString()).toSet().toList()..sort();

        if (!mounted) return;
        setState(() {
          citySuggestions = cities;
          if (cities.isNotEmpty) cityController.text = cities.first;
        });

        if (cities.length > 1 && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showCitySelector(cities);
          });
        }
      } else {
        if (!mounted) return;
        _applyFallbackCity(postalCode);
      }
    } catch (e) {
      if (!mounted) return;
      _applyFallbackCity(postalCode);
    } finally {
      if (mounted) setState(() => isFetchingCities = false);
    }
  }

  void _applyFallbackCity(String postalCode) {
    final fallbackCities = _postalFallback[postalCode] ?? [];
    setState(() {
      citySuggestions = fallbackCities;
      if (fallbackCities.isNotEmpty) cityController.text = fallbackCities.first;
    });

    if (fallbackCities.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCitySelector(fallbackCities);
      });
    }
  }

  void _showCitySelector(List<String> cities) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final maxHeight = MediaQuery.of(context).size.height * 0.6;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sélectionnez votre commune',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemBuilder: (_, index) {
                        final city = cities[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            city,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            setState(() => cityController.text = city);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Colors.white12),
                      itemCount: cities.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
