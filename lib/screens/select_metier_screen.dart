import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dictionary_service.dart';
import '../models/onboarding_models.dart';
import 'plan_selection_screen.dart';

class SelectMetierScreen extends StatefulWidget {
  const SelectMetierScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<SelectMetierScreen> createState() => _SelectMetierScreenState();
}

class _SelectMetierScreenState extends State<SelectMetierScreen> {
  String? selectedKey;
  Map<String, String> _metierOptions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    selectedKey = widget.data.tradeKey;
    _loadMetiers();
  }

  Future<void> _loadMetiers() async {
    final metiers = await DictionaryService.instance.metiers();
    if (!mounted) return;
    setState(() {
      _metierOptions = metiers;
      _loading = false;
      if (_metierOptions.length == 1 && selectedKey == null) {
        selectedKey = _metierOptions.keys.first;
      }
    });
  }

  Future<void> _saveAndContinue() async {
    if (selectedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez votre corps de métier')),
      );
      return;
    }
    widget.data.tradeKey = selectedKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workit_trade_key', selectedKey!);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlanSelectionScreen(data: widget.data)),
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
        title: const Text(
          'Corps de métier',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
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
                      child: const Icon(Icons.home_repair_service, color: accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Quel est votre corps de métier ?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Les formulaires devis et métrés seront adaptés automatiquement.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: accent))
                    : ListView.separated(
                  itemCount: _metierOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final entry = _metierOptions.entries.elementAt(index);
                    final active = selectedKey == entry.key;
                    return InkWell(
                      onTap: () => setState(() => selectedKey = entry.key),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: active ? accent.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active ? accent.withOpacity(0.6) : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              active ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: active ? accent : Colors.white54,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saveAndContinue,
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
