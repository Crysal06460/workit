import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/dynamic_dropdown_field.dart';

const Map<String, String> _metierOptions = {
  'menuiserie_aluminium': 'Menuiserie Aluminium / PVC / Bois / Mixte',
  'platrerie_isolation_cloisons': 'Plâtrerie – Isolation – Cloisons',
  'electricite_courants_faibles': 'Électricité – Courants faibles',
  'chauffage_climatisation_ventilation': 'Chauffage – Clim – Ventilation',
  'plomberie_sanitaire': 'Plomberie – Sanitaire',
  'peinture_revetements': 'Peinture – Revêtements',
  'carrelage_maconnerie_fine': 'Carrelage – Maçonnerie fine',
  'cuisine_amenagement_interieur': 'Cuisine – Aménagement intérieur',
  'salle_de_bain_etancheite': 'Salle de bain – Étanchéité',
  'sols_exterieurs_amenagements': 'Sols extérieurs – Aménagements',
  'vitrerie_miroiterie': 'Vitrerie – Miroiterie',
  'automatismes_portails': 'Automatismes – Portails',
};

const Color _commercialBg = Color(0xFF07090D);
const Color _commercialCard = Color(0xFF0F1422);
const Color _commercialAccent = Color(0xFF00F795);

class CommercialHomeScreen extends StatefulWidget {
  const CommercialHomeScreen({super.key});

  @override
  State<CommercialHomeScreen> createState() => _CommercialHomeScreenState();
}

class _CommercialHomeScreenState extends State<CommercialHomeScreen> {
  final List<_QuoteItem> _newItems = [];

  @override
  Widget build(BuildContext context) {

    final waitingItems = const [
      _QuoteItem(
        client: 'Société Vernet',
        address: '8 quai du Port, Marseille',
        number: '#8399',
        date: 'Envoyé il y a 2h',
        tag: 'Transmission envoyée',
      ),
    ];

    final measuringItems = const [
      _MeasureItem(
        client: 'Hector Immobilier',
        address: '45 bd Carnot, Nice',
        status: 'Dimensions en saisie',
        assignee: 'Léa Martin',
      ),
    ];

    final validatedItems = const [
      _QuoteItem(
        client: 'Opti Veranda',
        address: 'Rue des Fleurs, Nantes',
        number: '#8320',
        date: 'Validé hier',
        tag: 'Validé',
      ),
    ];

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: _commercialBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Bonjour, Alex',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Commercial',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E1424), Color(0xFF0B111D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: TabBar(
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _commercialAccent.withOpacity(0.5)),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: [
                    Tab(
                      child: _TabPill(
                        label: 'Nouveaux',
                        count: _newItems.length,
                        color: Colors.deepPurpleAccent,
                        icon: Icons.upload_file,
                      ),
                    ),
                    Tab(
                      child: _TabPill(
                        label: 'En attente',
                        count: waitingItems.length,
                        color: Colors.amberAccent,
                        icon: Icons.schedule_send,
                      ),
                    ),
                    Tab(
                      child: _TabPill(
                        label: 'En cours',
                        count: measuringItems.length,
                        color: Colors.lightBlueAccent,
                        icon: Icons.straighten,
                      ),
                    ),
                    Tab(
                      child: _TabPill(
                        label: 'Validés',
                        count: validatedItems.length,
                        color: _commercialAccent,
                        icon: Icons.verified_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SearchBar(),
              ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AddQuoteButton(
                    onPressed: () async {
                      final newItem = await Navigator.of(context).push<_QuoteItem>(
                        MaterialPageRoute(builder: (_) => const _AddQuoteScreen()),
                      );
                      if (newItem != null) {
                        setState(() => _newItems.add(newItem));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TabBarView(
                      children: [
                        _NewQuotesList(
                          items: _newItems,
                          onDelete: (item) {
                            setState(() => _newItems.remove(item));
                          },
                          onEdit: (item) async {
                            final edited = await _showEditDialog(context, item);
                            if (edited != null) {
                              setState(() {
                                final idx = _newItems.indexOf(item);
                                if (idx >= 0) _newItems[idx] = edited;
                              });
                            }
                          },
                        ),
                        _WaitingForMeasureList(items: waitingItems),
                        _MeasuringList(items: measuringItems),
                        _ValidatedList(items: validatedItems),
                      ],
                    ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_QuoteItem?> _showEditDialog(BuildContext context, _QuoteItem item) async {
    final clientController = TextEditingController(text: item.client);
    final addressController = TextEditingController(text: item.address);
    return showDialog<_QuoteItem>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _commercialCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Modifier le devis', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clientController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Client',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _commercialAccent, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.of(ctx).pop(
                  item.copyWith(
                    client: clientController.text.trim().isEmpty ? item.client : clientController.text.trim(),
                    address: addressController.text.trim().isEmpty ? item.address : addressController.text.trim(),
                  ),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Rechercher un devis, un client…',
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _commercialAccent, width: 1.3),
        ),
      ),
    );
  }
}

class _AddQuoteButton extends StatelessWidget {
  const _AddQuoteButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _commercialCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _commercialAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.upload_file),
        label: const Text('Ajouter un devis'),
      ),
    );
  }
}

class _NewQuotesList extends StatelessWidget {
  const _NewQuotesList({required this.items, required this.onDelete, required this.onEdit});
  final List<_QuoteItem> items;
  final ValueChanged<_QuoteItem> onDelete;
  final ValueChanged<_QuoteItem> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = items[index];
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: '${item.number} • ${item.date}',
          badgeLabel: item.tag,
          badgeColor: Colors.deepPurpleAccent,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                onPressed: () => onEdit(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                onPressed: () => onDelete(item),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaitingForMeasureList extends StatelessWidget {
  const _WaitingForMeasureList({required this.items});
  final List<_QuoteItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = items[index];
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: item.number,
          badgeLabel: item.tag,
          badgeColor: Colors.blueGrey,
          trailing: TextButton(
            onPressed: () {},
            child: const Text('Relancer le métreur', style: TextStyle(color: Colors.white)),
          ),
        );
      },
    );
  }
}

class _MeasuringList extends StatelessWidget {
  const _MeasuringList({required this.items});
  final List<_MeasureItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = items[index];
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: item.status,
          badgeLabel: item.assignee,
          badgeColor: Colors.lightBlueAccent,
          trailing: const Icon(Icons.straighten, color: Colors.white70),
        );
      },
    );
  }
}

class _ValidatedList extends StatelessWidget {
  const _ValidatedList({required this.items});
  final List<_QuoteItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = items[index];
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: '${item.number} • ${item.date}',
          badgeLabel: item.tag,
          badgeColor: _commercialAccent,
          trailing: const Icon(Icons.verified_outlined, color: _commercialAccent),
        );
      },
    );
  }
}

class _AddQuoteScreen extends StatefulWidget {
  const _AddQuoteScreen();

  @override
  State<_AddQuoteScreen> createState() => _AddQuoteScreenState();
}

class _AddQuoteScreenState extends State<_AddQuoteScreen> {
  final pageController = PageController();
  final clientNameController = TextEditingController();
  final clientFirstNameController = TextEditingController();
  final clientStreetController = TextEditingController();
  final clientPostalController = TextEditingController();
  final clientCityController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final commentaireController = TextEditingController();
  final chantierNotesController = TextEditingController();
  final quantiteController = TextEditingController(text: '1');
  final largeurController = TextEditingController();
  final hauteurController = TextEditingController();
  int currentStep = 0;
  Map<String, dynamic>? dictionary;
  bool loadingDictionary = true;
  bool loadingTrade = true;
  String? tradeKey;
  String? tradeLabel;
  List<String> selectedFiles = [];
  String? chantierType;
  String? urgence;
  String? accessibilite;
  DateTime? selectedDate;
  List<_ProductFormData> products = [const _ProductFormData()];
  String? uploadLabel;
  List<String> citySuggestions = [];
  bool isFetchingCities = false;
  String? _lastPostalLookup;
  static const Map<String, List<String>> _postalFallback = {
    '06600': ['Antibes', 'Juan-les-Pins'],
    '06460': ['Caussols', 'Escragnolles', 'Saint-Vallier-de-Thiey'],
    '75001': ['Paris'],
    '13001': ['Marseille'],
    '69001': ['Lyon'],
    '33000': ['Bordeaux'],
    '31000': ['Toulouse'],
    '59000': ['Lille'],
  };

  @override
  void initState() {
    super.initState();
    _loadDictionary();
    _loadTradeFromPrefs();
  }

  Future<void> _loadDictionary() async {
    try {
      final raw = await rootBundle.loadString('assets/dictionnaire_workit/workit_dictionary.json');
      setState(() {
        dictionary = json.decode(raw) as Map<String, dynamic>;
        loadingDictionary = false;
      });
    } catch (_) {
      setState(() {
        dictionary = {};
        loadingDictionary = false;
      });
    }
  }

  Future<void> _loadTradeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('workit_trade_key');
    setState(() {
      tradeKey = key;
      tradeLabel = _metierOptions[key] ?? key;
      loadingTrade = false;
    });
  }

  @override
  void dispose() {
    clientNameController.dispose();
    clientFirstNameController.dispose();
    clientStreetController.dispose();
    clientPostalController.dispose();
    clientCityController.dispose();
    phoneController.dispose();
    emailController.dispose();
    commentaireController.dispose();
    chantierNotesController.dispose();
    quantiteController.dispose();
    largeurController.dispose();
    hauteurController.dispose();
    super.dispose();
  }

  List<String> _ralChoices() {
    final trade = _currentTradeNode();
    final couleurs = trade?['options']?['couleurs'] ?? dictionary?['couleurs'];
    if (couleurs is Map && couleurs['ral'] is List) {
      return (couleurs['ral'] as List).map((e) => 'RAL $e').toList();
    }
    return const [];
  }

  Map<String, dynamic>? _currentTradeNode() {
    final key = tradeKey;
    if (key == null) return null;
    final metiers = dictionary?['metiers'];
    if (metiers is Map && metiers[key] is Map<String, dynamic>) {
      return metiers[key] as Map<String, dynamic>;
    }
    return null;
  }

  List<_Choice> _categoryChoices() {
    final trade = _currentTradeNode();
    final cats = trade?['categories'];
    if (cats is Map<String, dynamic>) {
      return cats.entries
          .map((e) => _Choice(e.key, e.value['label']?.toString() ?? e.key))
          .toList();
    }
    return const [];
  }

  List<String> _sousCategories(String? categoryKey) {
    if (categoryKey == null) return const [];
    final trade = _currentTradeNode();
    final cat = trade?['categories']?[categoryKey];
    if (cat is Map && cat['sous_categories'] is List) {
      return (cat['sous_categories'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  List<_Choice> _typeChoices(String? categoryKey) {
    if (categoryKey == null) return const [];
    final trade = _currentTradeNode();
    final cat = trade?['categories']?[categoryKey];
    if (cat is Map && cat['types'] is Map) {
      return (cat['types'] as Map<String, dynamic>)
          .entries
          .map((e) => _Choice(e.key, e.value['label']?.toString() ?? e.key))
          .toList();
    }
    return const [];
  }

  List<String> _variantForType(String? categoryKey, String? typeKey) {
    if (categoryKey == null || typeKey == null) return const [];
    final trade = _currentTradeNode();
    final type = trade?['categories']?[categoryKey]?['types']?[typeKey];
    if (type is Map && type['variantes'] is List) {
      return (type['variantes'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<void> _onPostalCodeChanged(String value) async {
    final postalCode = value.trim();
    // Utilise la même logique que create_workspace_screen.dart
    if (postalCode.length != 5 || !RegExp(r'^\d{5}$').hasMatch(postalCode)) {
      setState(() {
        clientCityController.clear();
        citySuggestions = [];
      });
      return;
    }

    if (postalCode == _lastPostalLookup) return;
    _lastPostalLookup = postalCode;

    // Pré-remplir avec un fallback immédiat (comme l'écran de création compte).
    final fallback = _postalFallback[postalCode];
    if (fallback != null && fallback.isNotEmpty) {
      setState(() {
        citySuggestions = fallback;
        clientCityController.text = fallback.first;
      });
      if (fallback.length > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showCitySelector(fallback);
        });
      }
    } else {
      setState(() {
        citySuggestions = [];
        clientCityController.clear();
      });
    }

    await _fetchCitiesForPostalCode(postalCode);
  }

  Future<void> _fetchCitiesForPostalCode(String postalCode) async {
    setState(() {
      isFetchingCities = true;
      citySuggestions = [];
      clientCityController.clear();
    });

    try {
      final url = Uri.parse('https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final List<String> cities = data.map((city) => city['nom'].toString()).toSet().toList()..sort();

        if (!mounted) return;
        if (cities.isEmpty) {
          _applyFallbackCity(postalCode);
        } else {
          setState(() {
            citySuggestions = cities;
            clientCityController.text = cities.first;
          });

          if (cities.length > 1 && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showCitySelector(cities);
            });
          }
        }
      } else {
        if (!mounted) return;
        _applyFallbackCity(postalCode);
      }
    } catch (_) {
      if (!mounted) return;
      _applyFallbackCity(postalCode);
    } finally {
      if (mounted) {
        setState(() => isFetchingCities = false);
      }
    }
  }

  void _applyFallbackCity(String postalCode) {
    final cities = _postalFallback[postalCode] ?? const [];
    setState(() {
      citySuggestions = cities;
      if (cities.isNotEmpty) clientCityController.text = cities.first;
    });

    if (cities.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCitySelector(cities);
      });
    }
  }

  void _showCitySelector(List<String> cities) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _commercialCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.75;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
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
                        'Sélectionnez la commune',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (_, index) {
                          final city = cities[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(city, style: const TextStyle(color: Colors.white)),
                            onTap: () {
                              setState(() => clientCityController.text = city);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                        itemCount: cities.length,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _uploadFile(String path) async {
    try {
      setState(() => uploadLabel = 'Envoi du devis…');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(path)}';
      final ref = FirebaseStorage.instance.ref().child('devis_uploads/$fileName');
      await ref.putFile(File(path));
      await ref.getDownloadURL();
      setState(() => uploadLabel = 'Devis stocké pour le reste de l’équipe.');
    } catch (e) {
      _showPickerError(context, 'Envoi impossible : $e');
      setState(() => uploadLabel = null);
    }
  }

  Future<void> _pickFiles() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (picked == null || picked.files.isEmpty) return;
      final firstPath = picked.files.first.path;
      if (firstPath == null) {
        _showPickerError(context, 'Impossible de lire ce fichier.');
        return;
      }
      setState(() => selectedFiles = picked.files.map((f) => f.name).toList());
      await _uploadFile(firstPath);
    } on PlatformException catch (e) {
      _showPickerError(context, 'Sélection de fichier impossible (${e.code}).');
    } catch (e) {
      _showPickerError(context, 'Sélection de fichier impossible.');
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final picker = ImagePicker();
      final photos = await picker.pickMultiImage();
      if (photos.isEmpty) return;
      final firstPath = photos.first.path;
      setState(() => selectedFiles = photos.map((f) => f.name ?? 'Photo').toList());
      await _uploadFile(firstPath);
    } on PlatformException catch (e) {
      _showPickerError(context, 'Accès appareil photo impossible (${e.code}).');
    } catch (e) {
      _showPickerError(context, 'Accès appareil photo impossible.');
    }
  }

  Widget _stepHeader() {
    const labels = ['Client', 'Chantier', 'Éléments', 'Date', 'Commentaires', 'Upload devis'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101728), Color(0xFF0A1221)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final active = index == currentStep;
            final done = index < currentStep;
            return Row(
              children: [
                _StepBadge(
                  index: index,
                  label: labels[index],
                  active: active,
                  done: done,
                ),
                if (index != labels.length - 1)
                  Container(
                    width: 32,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: done ? _commercialAccent : Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _clientForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Coordonnées client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Nom',
          controller: clientNameController,
          keyboardType: TextInputType.name,
          required: true,
        ),
        _LabeledField(
          label: 'Prénom',
          controller: clientFirstNameController,
          keyboardType: TextInputType.name,
        ),
        _LabeledField(
          label: 'Adresse (rue)',
          controller: clientStreetController,
          keyboardType: TextInputType.streetAddress,
          required: true,
        ),
        Row(
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Code postal',
                controller: clientPostalController,
                keyboardType: TextInputType.number,
                required: true,
                maxLength: 5,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onPostalCodeChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LabeledField(
                label: 'Ville',
                controller: clientCityController,
                keyboardType: TextInputType.text,
                readOnly: true,
                onTap: () {
                  if (citySuggestions.length > 1) _showCitySelector(citySuggestions);
                },
                hintText: isFetchingCities ? 'Chargement…' : 'Selon code postal',
              ),
            ),
          ],
        ),
        _LabeledField(
          label: 'Téléphone',
          controller: phoneController,
          keyboardType: TextInputType.phone,
          required: true,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        _LabeledField(
          label: 'Email',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _chantierForm() {
    final fields = dictionary?['workit_commercial']?['part2_infos_generales']?['fields']
        as Map<String, dynamic>? ??
        {};
    String? typeChantier = chantierType;
    String? urgenceVal = urgence;
    String? accessVal = accessibilite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text('Infos générales chantier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            if (tradeLabel != null)
              Chip(
                label: Text(
                  tradeLabel!,
                  style: const TextStyle(color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: _commercialAccent.withOpacity(0.85),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DynamicDropdownField(
          label: 'Type de chantier',
          value: typeChantier,
          required: true,
          choices: fields['type_chantier']?['choices']?.cast<String>() ?? const [],
          onChanged: (v) => setState(() => chantierType = v),
        ),
        DynamicDropdownField(
          label: 'Urgence',
          value: urgenceVal,
          choices: fields['urgence']?['choices']?.cast<String>() ?? const [],
          onChanged: (v) => setState(() => urgence = v),
        ),
        DynamicDropdownField(
          label: 'Accessibilité',
          value: accessVal,
          choices: fields['site_accessibilite']?['choices']?.cast<String>() ?? const [],
          onChanged: (v) => setState(() => accessibilite = v),
        ),
        _LabeledField(
          label: 'Commentaires',
          controller: chantierNotesController,
          keyboardType: TextInputType.multiline,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _productCard(int index) {
    final product = products[index];
    final categories = _categoryChoices();
    final sousCategories = _sousCategories(product.categoryKey);
    final types = _typeChoices(product.categoryKey);
    final variants = _variantForType(product.categoryKey, product.typeProduit);
    final ral = _ralChoices();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Élément ${index + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              if (products.length > 1)
                IconButton(
                  onPressed: () => setState(() => products.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                ),
            ],
          ),
          _DropdownField(
            label: 'Catégorie',
            value: product.categoryKey,
            required: true,
            items: categories,
            onChanged: (v) => setState(() {
              products[index] = products[index].copyWith(
                categoryKey: v,
                sousCategorie: null,
                typeProduit: null,
                variante: null,
              );
            }),
          ),
          _DropdownField(
            label: 'Sous-catégorie',
            value: product.sousCategorie,
            items: sousCategories,
            onChanged: (v) => setState(() => products[index] = products[index].copyWith(sousCategorie: v)),
          ),
          _DropdownField(
            label: 'Type',
            value: product.typeProduit,
            items: types,
            onChanged: (v) => setState(() => products[index] = products[index].copyWith(typeProduit: v, variante: null)),
          ),
          _DropdownField(
            label: 'Spécificité / variante',
            value: product.variante,
            items: variants.isEmpty ? const ['Standard'] : variants,
            onChanged: (v) => setState(() => products[index] = products[index].copyWith(variante: v)),
          ),
         _DropdownField(
            label: 'Couleur',
            value: product.couleur,
            items: ral.isEmpty ? const ['Standard'] : ral,
            onChanged: (v) => setState(() => products[index] = products[index].copyWith(couleur: v)),
          ),
          Row(
            children: [
              Expanded(
                child: _IntField(
                  label: 'Largeur',
                  value: product.largeur,
                  onChanged: (v) => setState(() => products[index] = products[index].copyWith(largeur: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntField(
                  label: 'Hauteur',
                  value: product.hauteur,
                  onChanged: (v) => setState(() => products[index] = products[index].copyWith(hauteur: v)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: _DropdownField(
                  label: 'Unité',
                  value: product.unite,
                  items: const ['mm', 'cm', 'm'],
                  onChanged: (v) => setState(() => products[index] = products[index].copyWith(unite: v ?? 'mm')),
                ),
              ),
            ],
          ),
          _IntField(
            label: 'Quantité',
            value: product.quantite,
            onChanged: (v) => setState(() => products[index] = products[index].copyWith(quantite: v)),
          ),
        ],
      ),
    );
  }

  Widget _productForm() {
    if (_currentTradeNode() == null) {
      return const Text(
        'Aucun corps de métier sélectionné. Définissez-le lors de l’onboarding pour charger les choix produits.',
        style: TextStyle(color: Colors.white70),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Éléments du devis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...List.generate(products.length, _productCard),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => products.add(const _ProductFormData())),
            icon: const Icon(Icons.add, color: _commercialAccent),
            label: const Text(
              'Ajouter un élément',
              style: TextStyle(color: _commercialAccent, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Planification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  selectedDate != null
                      ? 'Chantier prévu : ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                      : 'Choisir une date estimative',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _commercialAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 2),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: _commercialAccent,
                          surface: _commercialCard,
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
                if (picked != null) setState(() => selectedDate = picked);
              },
              child: const Text('Choisir'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _commentsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Commentaires', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Notes supplémentaires',
          controller: commentaireController,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _uploadStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uploader le devis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text(
          'Ajoutez un PDF ou des photos. Le devis sera stocké et accessible aux métreurs/poseurs.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        if (selectedFiles.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedFiles
                .map(
                  (f) => Chip(
                    label: Text(f, style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.white.withOpacity(0.08),
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.folder_open,
          label: 'Uploader un PDF / JPEG',
          description: 'Depuis vos fichiers ou Drive',
          primary: true,
          onTap: _pickFiles,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.photo_camera_outlined,
          label: 'Prendre photo (plusieurs pages)',
          description: 'Ajoutez toutes les pages en une fois',
          primary: false,
          onTap: _pickPhotos,
        ),
        if (uploadLabel != null) ...[
          const SizedBox(height: 10),
          Text(uploadLabel!, style: const TextStyle(color: Colors.white70)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _clientForm(),
      _chantierForm(),
      _productForm(),
      _dateForm(),
      _commentsForm(),
      _uploadStep(),
    ]
        .map(
          (w) => SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: w,
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: _commercialBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Nouveau devis', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: loadingDictionary
            ? const Center(child: CircularProgressIndicator(color: _commercialAccent))
            : loadingTrade
                ? const Center(child: CircularProgressIndicator(color: _commercialAccent))
                : Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepHeader(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: PageView(
                        controller: pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: steps,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (currentStep > 0)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            onPressed: () {
                              currentStep = (currentStep - 1).clamp(0, steps.length - 1);
                              pageController.animateToPage(
                                currentStep,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                              setState(() {});
                            },
                            child: const Text('Précédent'),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _commercialAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          onPressed: () {
                            if (currentStep < steps.length - 1) {
                              currentStep++;
                              pageController.animateToPage(
                                currentStep,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                              setState(() {});
                              return;
                            }
                          final newItem = _QuoteItem(
                            client: clientNameController.text.isNotEmpty
                                ? '${clientNameController.text}${clientFirstNameController.text.isNotEmpty ? ' ${clientFirstNameController.text}' : ''}'
                                : 'Nouveau client',
                            address: '${clientStreetController.text}, ${clientPostalController.text} ${clientCityController.text}',
                            number: '#${DateTime.now().millisecondsSinceEpoch % 10000}',
                            date: 'Ajouté aujourd’hui',
                            tag: 'À classer',
                          );
                          Navigator.of(context).pop(newItem);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Devis enregistré et partagé avec l’équipe.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          },
                          child: Text(currentStep == steps.length - 1 ? 'Soumettre' : 'Suivant'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? _commercialAccent : Colors.white.withOpacity(0.04);
    final fg = primary ? Colors.black : Colors.white;
    final border = primary ? Colors.transparent : Colors.white24;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: fg.withOpacity(0.78),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: fg.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final Color fill = done
        ? _commercialAccent
        : active
            ? _commercialAccent.withOpacity(0.85)
            : Colors.white.withOpacity(0.08);
    final Color textColor = done || active ? Colors.black : Colors.white70;
    final Color labelColor = done
        ? _commercialAccent
        : active
            ? Colors.white
            : Colors.white54;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(active ? 0.05 : 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? _commercialAccent.withOpacity(0.6) : Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: fill,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

void _showPickerError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.redAccent,
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.required = false,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.hintText,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool required;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.white),
            onChanged: onChanged,
            readOnly: readOnly,
            onTap: onTap,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white38),
              counterText: maxLength != null ? '' : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _commercialAccent, width: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.required = false,
  });

  final String label;
  final List<dynamic> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final List<String> itemValues = items.map(_itemValue).toList();
    final String? currentValue =
        (value != null && itemValues.contains(value)) ? value : (itemValues.isNotEmpty ? itemValues.first : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              dropdownColor: _commercialCard,
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              items: items
                    .map(
                      (e) => DropdownMenuItem(
                        value: _itemValue(e),
                        child: Text(_itemLabel(e)),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _itemValue(dynamic e) {
    if (e is _Choice) return e.key;
    return e.toString();
  }

  String _itemLabel(dynamic e) {
    if (e is _Choice) return e.label;
    return e.toString();
  }
}

class _IntField extends StatelessWidget {
  const _IntField({required this.label, this.value, this.onChanged});

  final String label;
  final int? value;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            onChanged: (text) {
              final parsed = int.tryParse(text);
              onChanged?.call(parsed);
            },
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _commercialAccent, width: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormData {
  const _ProductFormData({
    this.categoryKey,
    this.sousCategorie,
    this.typeProduit,
    this.variante,
    this.couleur,
    this.largeur,
    this.hauteur,
    this.quantite,
    this.unite = 'mm',
  });

  final String? categoryKey;
  final String? sousCategorie;
  final String? typeProduit;
  final String? variante;
  final String? couleur;
  final int? largeur;
  final int? hauteur;
  final int? quantite;
  final String unite;

  _ProductFormData copyWith({
    String? categoryKey,
    String? sousCategorie,
    String? typeProduit,
    String? variante,
    String? couleur,
    int? largeur,
    int? hauteur,
    int? quantite,
    String? unite,
  }) {
    return _ProductFormData(
      categoryKey: categoryKey ?? this.categoryKey,
      sousCategorie: sousCategorie ?? this.sousCategorie,
      typeProduit: typeProduit ?? this.typeProduit,
      variante: variante ?? this.variante,
      couleur: couleur ?? this.couleur,
      largeur: largeur ?? this.largeur,
      hauteur: hauteur ?? this.hauteur,
      quantite: quantite ?? this.quantite,
      unite: unite ?? this.unite,
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.18),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _TrailingPill extends StatelessWidget {
  const _TrailingPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice {
  const _Choice(this.key, this.label);
  final String key;
  final String label;
}

class _QuoteItem {
  const _QuoteItem({
    required this.client,
    required this.address,
    required this.number,
    required this.date,
    required this.tag,
  });

  final String client;
  final String address;
  final String number;
  final String date;
  final String tag;

  _QuoteItem copyWith({
    String? client,
    String? address,
    String? number,
    String? date,
    String? tag,
  }) {
    return _QuoteItem(
      client: client ?? this.client,
      address: address ?? this.address,
      number: number ?? this.number,
      date: date ?? this.date,
      tag: tag ?? this.tag,
    );
  }
}

class _MeasureItem {
  const _MeasureItem({
    required this.client,
    required this.address,
    required this.status,
    required this.assignee,
    this.photoUrl,
  });

  final String client;
  final String address;
  final String status;
  final String assignee;
  final String? photoUrl;
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.badgeLabel,
    required this.badgeColor,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String badgeLabel;
  final Color badgeColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _commercialCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description_outlined, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(meta, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.w800, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: trailing!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
