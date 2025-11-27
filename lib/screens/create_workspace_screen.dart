import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/onboarding_models.dart';
import 'plan_selection_screen.dart';

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key, this.journeyType, this.trialSessionId});

  final String? journeyType;
  final String? trialSessionId;

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
      companyName: nameController.text,
      siret: siretController.text,
      address: addressController.text,
      postalCode: postalCodeController.text,
      city: cityController.text,
      journeyType: widget.journeyType,
      trialSessionId: widget.trialSessionId,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlanSelectionScreen(data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Créer mon entreprise',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E1726), Color(0xFF0A1A2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.business, color: Color(0xFF00E676)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Identité de l’entreprise',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Ces informations s’affichent sur vos devis, métrés et fiches chantiers.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _DarkField(
                controller: nameController,
                label: 'Nom de l’entreprise',
                validator: (value) => value == null || value.isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 14),
              _DarkField(
                controller: siretController,
                label: 'SIRET (optionnel)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              _DarkField(
                controller: addressController,
                label: 'Adresse du siège',
                validator: (value) => value == null || value.isEmpty ? 'Adresse requise' : null,
              ),
              const SizedBox(height: 14),
              Row(
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Code postal requis';
                        if (value.length != 5 || !RegExp(r'^\d{5}$').hasMatch(value)) return '5 chiffres';
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Ville requise';
                        return null;
                      },
                      hintText: 'Auto (selon CP)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      inherit: false,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 0.1,
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF0F1422),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
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
      final url =
          Uri.parse('https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final List<String> cities =
            data.map((city) => city['nom'].toString()).toSet().toList()..sort();

        if (!mounted) return;
        setState(() {
          citySuggestions = cities;
          if (cities.isNotEmpty) {
            cityController.text = cities.first;
          } else {
            cityController.clear();
          }
        });

        if (cities.length > 1 && mounted) {
          // Ouvrir la sélection après le build pour éviter les conflits de contexte.
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
      if (mounted) {
        setState(() {
          isFetchingCities = false;
        });
      }
    }
  }

  void _applyFallbackCity(String postalCode) {
    final fallbackCities = _postalFallback[postalCode] ?? [];
    setState(() {
      citySuggestions = fallbackCities;
      if (fallbackCities.isNotEmpty) {
        cityController.text = fallbackCities.first;
      } else {
        cityController.clear();
      }
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                ...cities.map(
                  (city) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      city,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      setState(() => cityController.text = city);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}