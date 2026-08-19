part of 'commercial_home_screen.dart';

class _AddQuoteScreen extends StatefulWidget {
  const _AddQuoteScreen({this.existingItem});

  final _QuoteItem? existingItem;

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
  final montantHTController = TextEditingController();
  final List<_MetreurOption> _metreurs = [];
  bool loadingMetreurs = true;
  String? _selectedMetreurId;
  String? _selectedMetreurName;
  String? uploadedFileUrl;
  List<String> uploadedFileUrls = [];
  int currentStep = 0;
  Map<String, dynamic>? dictionary;
  bool loadingDictionary = true;
  bool loadingTrade = true;
  String? tradeKey;
  String? tradeLabel;
  String? _workspaceId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> selectedFiles = [];
  String? chantierType;
  String? typeHabitation;
  String? accessibilite;
  DateTime? selectedDate;
  // Éléments à métrer : liste conservée telle quelle si on édite un devis déjà
  // en cours (le métreur a pu déjà y saisir des mesures — surtout ne pas les
  // écraser), sinon reconstruite à la soumission à partir de _elementsCount
  // (ou de la détection IA si elle a tourné, voir _aiElements).
  List<_ProductFormData> products = const [];
  int? _soldDurationDays;
  int? _soldPoseurCountRequired;
  int _elementsCount = 1;
  List<_AiExtractedElement>? _aiElements;
  bool _analyzingWithAi = false;
  String? _aiError;
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
    _loadWorkspaceFromPrefs();
    _loadDictionary();
    _loadTradeFromPrefs();
    _loadMetreurs();
    _applyDraft(widget.existingItem?.draft);
    if (widget.existingItem != null && widget.existingItem!.draft == null) {
      _applyQuoteFallback(widget.existingItem!);
    }
  }

  Future<void> _loadWorkspaceFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workspaceId = prefs.getString(_workspaceIdKey);
    });
    await _loadMetreurs();
  }

  Future<void> _loadMetreurs() async {
    if (_workspaceId == null) {
      setState(() => loadingMetreurs = false);
      return;
    }
    try {
      final snap = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: _workspaceId)
          .where('role', isEqualTo: 'metreur')
          .get();
      _metreurs
        ..clear()
        ..addAll(snap.docs.map((doc) {
          final data = doc.data();
          final first = data['firstName']?.toString().trim() ?? '';
          final last = data['lastName']?.toString().trim() ?? '';
          final name = [first, last].where((e) => e.isNotEmpty).join(' ');
          return _MetreurOption(
            id: doc.id,
            name: name.isNotEmpty ? name : (data['email']?.toString() ?? 'Métreur'),
            email: data['email']?.toString(),
          );
        }));
      if (_metreurs.length == 1 && _selectedMetreurId == null) {
        _selectedMetreurId = _metreurs.first.id;
        _selectedMetreurName = _metreurs.first.name;
      }
      if (_metreurs.isNotEmpty && _selectedMetreurId == null) {
        _selectedMetreurId = 'any';
        _selectedMetreurName = 'Peu importe';
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => loadingMetreurs = false);
    }
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
    _workspaceId = prefs.getString(_workspaceIdKey);
    final key = prefs.getString('workit_trade_key');
    if (key != null) {
      setState(() {
        tradeKey = key;
        tradeLabel = _metierOptions[key] ?? key;
        loadingTrade = false;
      });
      return;
    }

    if (_workspaceId != null) {
      try {
        final doc = await _firestore.collection('workspaces').doc(_workspaceId).get();
        final data = doc.data();
        final workspaceTrade = data?['tradeKey']?.toString();
        if (workspaceTrade != null && workspaceTrade.isNotEmpty) {
          await prefs.setString('workit_trade_key', workspaceTrade);
          setState(() {
            tradeKey = workspaceTrade;
            tradeLabel = _metierOptions[workspaceTrade] ?? workspaceTrade;
            loadingTrade = false;
          });
          return;
        }
      } catch (_) {
        // ignore
      }
    }

    setState(() {
      tradeKey = key;
      tradeLabel = _metierOptions[key] ?? key;
      loadingTrade = false;
    });
  }

  void _applyDraft(_QuoteDraft? draft) {
    if (draft == null) return;
    clientNameController.text = draft.clientName ?? '';
    clientFirstNameController.text = draft.clientFirstName ?? '';
    clientStreetController.text = draft.street ?? '';
    clientPostalController.text = draft.postal ?? '';
    clientCityController.text = draft.city ?? '';
    phoneController.text = draft.phone ?? '';
    emailController.text = draft.email ?? '';
    chantierNotesController.text = draft.chantierNotes ?? '';
    commentaireController.text = draft.commentaire ?? '';
    chantierType = draft.chantierType;
    typeHabitation = draft.typeHabitation;
    accessibilite = draft.accessibilite;
    selectedDate = draft.date;
    _selectedMetreurId = draft.assignedMetreurId;
    _selectedMetreurName = draft.assignedMetreurName;
    _soldDurationDays = draft.soldEstimatedDurationDays;
    _soldPoseurCountRequired = draft.soldPoseurCountRequired;
    montantHTController.text = draft.montantHT != null ? draft.montantHT!.toStringAsFixed(2) : '';
    // Devis déjà existant (édition) : on garde les éléments tels quels — un
    // métreur a pu déjà y saisir des mesures, surtout ne pas les régénérer.
    // Sinon (nouveau devis) `products` reste vide, reconstruit à la
    // soumission depuis _elementsCount (voir _buildDraft).
    products = draft.products;
    _elementsCount = draft.elementsCount ?? (draft.products.isNotEmpty ? draft.products.length : 1);
    setState(() {});
  }

  void _applyQuoteFallback(_QuoteItem item) {
    // Reconstitute fields from the minimal data we have for older quotes without draft.
    final clientParts = item.client.trim().split(RegExp(r'\\s+'));
    if (clientParts.length > 1) {
      clientNameController.text = clientParts.first;
      clientFirstNameController.text = clientParts.sublist(1).join(' ');
    } else {
      clientNameController.text = item.client;
    }

    final segments = item.address.split(',');
    if (segments.isNotEmpty) {
      clientStreetController.text = segments.first.trim();
    }
    if (segments.length > 1) {
      final tail = segments.sublist(1).join(',').trim();
      final postalMatch = RegExp(r'(\\d{5})').firstMatch(tail);
      if (postalMatch != null) {
        clientPostalController.text = postalMatch.group(1) ?? '';
        final city = tail.replaceFirst(postalMatch.group(0) ?? '', '').trim();
        if (city.isNotEmpty) clientCityController.text = city;
      } else {
        clientCityController.text = tail;
      }
    }

    chantierNotesController.clear();
    commentaireController.clear();
    phoneController.clear();
    emailController.clear();
    _selectedMetreurId = item.assignedMetreurId;
    _selectedMetreurName = item.assignedMetreurName;
    products = const [];
    _elementsCount = 1;
  }

  void _capitalizeFirstLetter(TextEditingController controller) {
    final text = controller.text;
    if (text.isEmpty) return;
    final capitalized = text[0].toUpperCase() + text.substring(1);
    if (capitalized == text) return;
    final selectionIndex = controller.selection.baseOffset;
    controller.value = controller.value.copyWith(
      text: capitalized,
      selection: TextSelection.collapsed(
        offset: selectionIndex.clamp(0, capitalized.length),
      ),
    );
  }

  /// Génère les éléments à métrer pour un nouveau devis (pas d'édition en
  /// cours) : un placeholder par élément compté par le commercial, ou un par
  /// ligne détectée par l'IA si une analyse a abouti (voir _aiElements) —
  /// dans les deux cas, seul `metierKey` est connu à ce stade, le reste
  /// (catégorie, type, dimensions) est rempli par le métreur sur place.
  List<_ProductFormData> _buildPlaceholderProducts() {
    if (_aiElements != null && _aiElements!.isNotEmpty) {
      return _aiElements!
          .map((e) => _ProductFormData(
                metierKey: tradeKey,
                quantite: e.quantite,
                aiHint: e.description,
              ))
          .toList();
    }
    final count = _elementsCount < 1 ? 1 : _elementsCount;
    return List.generate(count, (_) => _ProductFormData(metierKey: tradeKey, quantite: 1));
  }

  _QuoteDraft _buildDraft() {
    return _QuoteDraft(
      clientName: clientNameController.text,
      clientFirstName: clientFirstNameController.text,
      street: clientStreetController.text,
      postal: clientPostalController.text,
      city: clientCityController.text,
      phone: phoneController.text,
      email: emailController.text,
      commentaire: commentaireController.text,
      chantierNotes: chantierNotesController.text,
      chantierType: chantierType,
      typeHabitation: typeHabitation,
      accessibilite: accessibilite,
      date: selectedDate,
      products: products.isNotEmpty ? products : _buildPlaceholderProducts(),
      assignedMetreurId: _selectedMetreurId == 'any' ? null : _selectedMetreurId,
      assignedMetreurName: _selectedMetreurName,
      soldEstimatedDurationDays: _soldDurationDays,
      soldPoseurCountRequired: _soldPoseurCountRequired,
      elementsCount: _elementsCount,
      montantHT: double.tryParse(montantHTController.text.replaceAll(',', '.').trim()),
    );
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
    montantHTController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildSummaryFromDraft(_QuoteDraft draft) {
    final entries = <Map<String, dynamic>>[];
    void addEntry(String label, String? value) {
      final clean = value?.trim();
      if (clean != null && clean.isNotEmpty) {
        entries.add({'label': label, 'value': clean});
      }
    }

    addEntry('Type de chantier', draft.chantierType);
    addEntry('Type d’habitation', draft.typeHabitation);
    addEntry('Accessibilité', draft.accessibilite);
    addEntry('Commentaires chantier', draft.chantierNotes);
    addEntry('Éléments à métrer', draft.products.isNotEmpty ? '${draft.products.length}' : null);
    final hints = draft.products.map((p) => p.aiHint).whereType<String>().where((h) => h.isNotEmpty).toList();
    if (hints.isNotEmpty) addEntry('Suggestions IA', hints.join(', '));
    if (draft.montantHT != null) addEntry('Montant HT', '${draft.montantHT!.toStringAsFixed(2)} €');

    if (draft.date != null) {
      final d = draft.date!;
      final formatted = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      addEntry('Chantier prévu', formatted);
    }

    return entries;
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
                          color: AppColors.grey200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sélectionnez la commune',
                        style: TextStyle(
                          color: AppColors.grey900,
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
                            title: Text(city, style: const TextStyle(color: AppColors.grey900)),
                            onTap: () {
                              setState(() => clientCityController.text = city);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                        separatorBuilder: (_, __, ) => const Divider(height: 1, color: AppColors.grey100),
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

  /// Upload un seul fichier vers Storage et retourne son URL de
  /// téléchargement (ou `null` si le bucket refuse d'en émettre une — le
  /// fichier reste stocké, juste sans lien direct).
  Future<String?> _uploadSingleFile(String path) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(path)}';
    final storage = FirebaseStorage.instanceFor(bucket: _storageBucket);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final workspace = prefs.getString(_workspaceIdKey);
    if (uid == null || workspace == null) {
      throw Exception('Utilisateur ou workspace manquant pour sécuriser le fichier.');
    }
    final ref = storage.ref().child('devis_uploads/$workspace/$uid/$fileName');

    // Certaines sélections (bibliothèque photos) nécessitent une lecture en mémoire.
    final file = File(path);
    final bytes = await file.readAsBytes();
    final uploadTask = await ref.putData(bytes);
    if (uploadTask.bytesTransferred <= 0) throw Exception('Téléversement incomplet.');

    try {
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Upload tous les fichiers sélectionnés (pas seulement le premier — un
  /// devis multi-pages doit être lu en entier, notamment par l'analyse IA,
  /// voir _analyzeUpload) puis déclenche cette analyse.
  Future<void> _uploadAllFiles(List<String> paths) async {
    try {
      setState(() => uploadLabel = 'Envoi du devis…');
      final urls = <String>[];
      for (final path in paths) {
        final url = await _uploadSingleFile(path);
        if (url != null) urls.add(url);
      }
      setState(() {
        uploadedFileUrls = urls;
        uploadedFileUrl = urls.isNotEmpty ? urls.first : null;
        uploadLabel = 'Devis stocké pour le reste de l’équipe.';
      });
      if (urls.isNotEmpty) unawaited(_analyzeUpload(urls));
    } catch (e) {
      _showPickerError(context, 'Envoi impossible : $e');
      setState(() => uploadLabel = null);
    }
  }

  /// Fait lire le devis uploadé par l'IA (Cloud Function `analyzeDevis`) pour
  /// en extraire les éléments — jamais bloquant : en cas d'échec/quota
  /// dépassé, le commercial garde simplement la saisie manuelle du nombre
  /// d'éléments (voir _ElementCountField dans _chantierForm).
  Future<void> _analyzeUpload(List<String> urls) async {
    setState(() {
      _analyzingWithAi = true;
      _aiError = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('analyzeDevis');
      final result = await callable.call<Map<String, dynamic>>({
        'fileUrls': urls,
        'tradeLabel': tradeLabel,
      });
      final data = result.data;
      final rawElements = data['elements'];
      final elements = rawElements is List
          ? rawElements
              .whereType<Map>()
              .map((e) => _AiExtractedElement(
                    quantite: (e['quantite'] as num?)?.toInt() ?? 1,
                    description: e['description']?.toString() ?? '',
                  ))
              .where((e) => e.description.isNotEmpty)
              .toList()
          : <_AiExtractedElement>[];

      if (!mounted) return;
      setState(() {
        _analyzingWithAi = false;
        if (elements.isEmpty) {
          _aiError = 'Aucun élément détecté automatiquement — indiquez le nombre à la main.';
          return;
        }
        _aiElements = elements;
        _elementsCount = elements.fold(0, (s, e) => s + e.quantite).clamp(1, 999);
        final montantHT = (data['montantHT'] as num?)?.toDouble();
        if (montantHT != null && montantHTController.text.trim().isEmpty) {
          montantHTController.text = montantHT.toStringAsFixed(2);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzingWithAi = false;
        _aiError = 'Analyse IA indisponible — indiquez le nombre d’éléments manuellement.';
      });
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
      final paths = picked.files.map((f) => f.path).whereType<String>().toList();
      if (paths.isEmpty) {
        _showPickerError(context, 'Impossible de lire ce fichier.');
        return;
      }
      setState(() => selectedFiles = picked.files.map((f) => f.name).toList());
      await _uploadAllFiles(paths);
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
      setState(() => selectedFiles = photos.map((f) => f.name).toList());
      await _uploadAllFiles(photos.map((f) => f.path).toList());
    } on PlatformException catch (e) {
      _showPickerError(context, 'Accès appareil photo impossible (${e.code}).');
    } catch (e) {
      _showPickerError(context, 'Accès appareil photo impossible.');
    }
  }

  Widget _stepHeader() {
    const labels = ['Client', 'Chantier', 'Date', 'Commentaires', 'Upload devis'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
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
                      color: done ? _commercialAccent : AppColors.grey200,
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
        const Text('Coordonnées client', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Nom',
          controller: clientNameController,
          keyboardType: TextInputType.name,
          required: true,
          onChanged: (_) => _capitalizeFirstLetter(clientNameController),
        ),
        _LabeledField(
          label: 'Prénom',
          controller: clientFirstNameController,
          keyboardType: TextInputType.name,
          onChanged: (_) => _capitalizeFirstLetter(clientFirstNameController),
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
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
            return isValid ? null : 'Email invalide';
          },
        ),
      ],
    );
  }

  Widget _chantierForm() {
    final fields = dictionary?['workit_commercial']?['part2_infos_generales']?['fields']
        as Map<String, dynamic>? ??
        {};
    String? typeChantier = chantierType;
    String? habitationVal = typeHabitation;
    String? accessVal = accessibilite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text('Infos générales chantier', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
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
          label: "Type d'habitation",
          value: habitationVal,
          choices: fields['type_habitation']?['choices']?.cast<String>() ?? const [],
          onChanged: (v) => setState(() => typeHabitation = v),
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
        const SizedBox(height: 4),
        const Text('Temps & équipe vendus', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Estimation transmise au métreur — il pourra la confirmer ou l\'ajuster après le métré.',
          style: TextStyle(color: AppColors.grey400, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _IntField(
                label: 'Durée estimée (jours)',
                value: _soldDurationDays,
                onChanged: (v) => setState(() => _soldDurationDays = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IntField(
                label: 'Nombre de poseurs',
                value: _soldPoseurCountRequired,
                onChanged: (v) => setState(() => _soldPoseurCountRequired = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Le détail de chaque élément (type, dimensions) sera relevé par le métreur sur place.',
          style: TextStyle(color: AppColors.grey400, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _ElementCountField(
          value: _elementsCount,
          onChanged: (v) => setState(() {
            _elementsCount = v;
            // Une saisie manuelle du nombre invalide une éventuelle
            // détection IA précédente (qui pilotait ce champ jusque-là).
            _aiElements = null;
          }),
        ),
        _LabeledField(
          label: 'Montant HT total du chantier (€)',
          controller: montantHTController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        ),
      ],
    );
  }

  Widget _dateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Planification', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Text(
                  selectedDate != null
                      ? 'Chantier prévu : ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                      : 'Choisir une date estimative',
                  style: const TextStyle(color: AppColors.grey500),
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
                        colorScheme: const ColorScheme.light(
                          primary: _commercialAccent,
                          surface: _commercialCard,
                          onSurface: AppColors.grey900,
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
        const Text('Commentaires', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
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

  Widget _metreurStep() {
    if (loadingMetreurs) {
      return const Center(child: CircularProgressIndicator(color: _commercialAccent));
    }
    if (_metreurs.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _commercialCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Aucun métreur disponible dans l’entreprise.',
          style: TextStyle(color: AppColors.grey500),
        ),
      );
    }

    final options = [
      ..._metreurs,
      const _MetreurOption(id: 'any', name: 'Peu importe', email: null),
    ];
    final groupValue = _selectedMetreurId ?? 'any';

    return Container(
      decoration: BoxDecoration(
        color: _commercialCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attribuer à un métreur',
            style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...options.map((m) {
            final selected = groupValue == m.id;
            return RadioListTile<String>(
              value: m.id,
              groupValue: groupValue,
              onChanged: (value) {
                setState(() {
                  _selectedMetreurId = value;
                  _selectedMetreurName = value == 'any' ? 'Peu importe' : m.name;
                });
              },
              activeColor: _commercialAccent,
              title: Text(
                m.name,
                style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
              ),
              subtitle: m.email != null ? Text(m.email!, style: const TextStyle(color: AppColors.grey500)) : null,
              tileColor: selected ? AppColors.primaryLight : Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _uploadStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uploader le devis', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text(
          'Ajoutez un PDF ou des photos. Le devis sera stocké et accessible aux métreurs/poseurs.',
          style: TextStyle(color: AppColors.grey500),
        ),
        const SizedBox(height: 14),
        if (selectedFiles.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedFiles
                .map(
                  (f) => Chip(
                    label: Text(f, style: const TextStyle(color: AppColors.grey900)),
                    backgroundColor: AppColors.grey100,
                    side: BorderSide(color: AppColors.grey200),
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
          Text(uploadLabel!, style: const TextStyle(color: AppColors.grey500)),
        ],
        if (_analyzingWithAi) ...[
          const SizedBox(height: 14),
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _commercialAccent),
              ),
              SizedBox(width: 10),
              Text('Analyse du devis en cours…', style: TextStyle(color: AppColors.grey500)),
            ],
          ),
        ],
        if (_aiError != null && !_analyzingWithAi) ...[
          const SizedBox(height: 14),
          Text(
            _aiError!,
            style: const TextStyle(color: AppColors.grey400, fontSize: 12),
          ),
        ],
        if (_aiElements != null && _aiElements!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '${_aiElements!.length} élément(s) détecté(s) par l’IA — nombre à métrer mis à jour automatiquement, modifiable à l’étape Chantier.',
            style: const TextStyle(color: AppColors.grey500, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_aiElements!.length, (i) {
              final e = _aiElements![i];
              return Chip(
                label: Text(
                  '${e.quantite}x ${e.description}',
                  style: const TextStyle(color: AppColors.grey900, fontSize: 12),
                ),
                backgroundColor: _commercialAccent.withOpacity(0.12),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() {
                  _aiElements = List.of(_aiElements!)..removeAt(i);
                  _elementsCount = _aiElements!.fold(0, (s, e) => s + e.quantite);
                  if (_elementsCount < 1) _elementsCount = 1;
                }),
              );
            }),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // L'étape de choix du métreur n'a de sens que s'il y a un vrai choix à
    // faire (plusieurs métreurs) — avec 0 ou 1 métreur, l'attribution se
    // fait déjà automatiquement en silence, pas besoin de l'afficher.
    final showMetreurStep = !loadingMetreurs && _metreurs.length > 1;
    final steps = [
      _clientForm(),
      _chantierForm(),
      _dateForm(),
      if (showMetreurStep) _metreurStep(),
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

    final bodyContent = loadingDictionary
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
                                  foregroundColor: AppColors.grey700,
                                  side: const BorderSide(color: AppColors.grey300),
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
                              onPressed: () async {
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
                                await _saveQuoteToCloud();
                                if (!mounted) return;
                                Navigator.of(context).pop();
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
                  );

    // Desktop : rendu en dialog centré (chrome léger, pas de Scaffold plein
    // écran) — la logique des étapes ci-dessus reste strictement identique.
    if (context.isDesktop) {
      return Material(
        color: _commercialBg,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.grey200)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nouveau devis',
                      style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.grey700),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: bodyContent),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _commercialBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.grey700),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Nouveau devis', style: TextStyle(color: AppColors.grey900)),
      ),
      body: SafeArea(child: bodyContent),
    );
  }

  Future<void> _saveQuoteToCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('workit_workspace_id');

    if (uid == null || workspaceId == null) return;

    final draft = _buildDraft();
    final existing = widget.existingItem;
    
    // Construct the quote item
    final newItem = _QuoteItem(
      client: clientNameController.text.isNotEmpty
          ? '${clientNameController.text}${clientFirstNameController.text.isNotEmpty ? ' ${clientFirstNameController.text}' : ''}'
          : 'Nouveau client',
      address: '${clientStreetController.text}, ${clientPostalController.text} ${clientCityController.text}',
      number: existing?.number ?? '#${DateTime.now().millisecondsSinceEpoch % 10000}',
      date: existing?.date ?? 'Ajouté aujourd’hui',
      tag: '',
      assignedMetreurId: _selectedMetreurId == 'any' ? null : _selectedMetreurId,
      assignedMetreurName: _selectedMetreurName,
      draft: draft,
      id: existing?.id,
      createdAt: existing?.createdAt ?? DateTime.now(),
      uploadUrl: uploadedFileUrl ?? existing?.uploadUrl,
    );

    try {
        final col = FirebaseFirestore.instance.collection('workspaces').doc(workspaceId).collection('devis');
        final sanitizedNumber = newItem.number.replaceAll('#', '');
        final docId = (newItem.id?.isNotEmpty == true)
            ? newItem.id!
            : (sanitizedNumber.isNotEmpty
                ? sanitizedNumber
                : 'quote_${DateTime.now().millisecondsSinceEpoch}');
        final ref = col.doc(docId);

        // Catégorie du chantier = métier de l'entreprise connectée, auto —
        // il n'y a plus de saisie manuelle par élément (voir _buildDraft).
        final categoryLabel = tradeLabel;

        final summary = newItem.draft != null ? _buildSummaryFromDraft(newItem.draft!) : <Map<String, dynamic>>[];
        final attachmentUrls = uploadedFileUrls.isNotEmpty
            ? uploadedFileUrls
            : (newItem.uploadUrl != null && newItem.uploadUrl!.isNotEmpty ? [newItem.uploadUrl!] : const <String>[]);
        final attachments = [
          for (var i = 0; i < attachmentUrls.length; i++)
            {
              'label': attachmentUrls.length > 1 ? 'Devis du commercial (page ${i + 1})' : 'Devis du commercial',
              'icon': Icons.picture_as_pdf.codePoint,
              'thumbnailUrl': attachmentUrls[i],
            },
        ];

        final combinedClientName = [
          newItem.draft?.clientFirstName?.trim() ?? '',
          newItem.draft?.clientName?.trim() ?? '',
        ].where((e) => e.isNotEmpty).join(' ').trim();

        await ref.set({
          ...newItem.toMap(),
          'userId': uid,
          'workspaceId': workspaceId,
          'metreurId': newItem.assignedMetreurId,
          // Only set status to 'Nouvelle demande' if it's a new quote or doesn't have a status yet.
          // If editing, we want to preserve the status ideally, but for now we might reset if not careful.
          // However, existing Metreur workflow relies on status. 
          // If existing item has status, keep it. 
          'status': existing?.status ?? 'Nouvelle demande',
          'category': categoryLabel,
          'phone': newItem.draft?.phone,
          'montantHT': newItem.draft?.montantHT,
          'updated': 'À l’instant',
          'note': newItem.draft?.commentaire ?? newItem.draft?.chantierNotes ?? '',
          'summary': summary,
          'attachments': attachments,
          if (attachmentUrls.isNotEmpty) 'attachmentUrls': attachmentUrls,
          if (combinedClientName.isNotEmpty) 'client': combinedClientName,
          'createdAt': newItem.createdAt != null
              ? Timestamp.fromDate(newItem.createdAt!)
              : FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving quote: $e');
      if (mounted) _showPickerError(context, 'Erreur sauvegarde: $e');
    }
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
    final bg = primary ? AppColors.primary : AppColors.grey100;
    final fg = primary ? Colors.white : AppColors.grey700;
    final border = primary ? Colors.transparent : AppColors.grey200;
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
                  color: primary ? Colors.white.withOpacity(0.15) : AppColors.grey200,
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
            ? _commercialAccent
            : AppColors.grey200;
    final Color textColor = done || active ? Colors.white : AppColors.grey500;
    final Color labelColor = done
        ? _commercialAccent
        : active
            ? AppColors.grey900
            : AppColors.grey400;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _commercialAccent.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? _commercialAccent.withOpacity(0.5) : Colors.transparent),
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
    this.validator,
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
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(color: AppColors.grey500),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            style: const TextStyle(color: AppColors.grey900),
            onChanged: onChanged,
            readOnly: readOnly,
            onTap: onTap,
            inputFormatters: inputFormatters,
            validator: validator,
            autovalidateMode: validator != null ? AutovalidateMode.onUserInteraction : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.grey50,
              hintText: hintText,
              hintStyle: const TextStyle(color: AppColors.grey400),
              counterText: maxLength != null ? '' : null,
              errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _commercialAccent, width: 1.3),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ "Combien d'éléments à métrer ?" — un `DropdownMenu` (Material 3)
/// propose 1 à 10 en suggestions rapides, mais le champ texte sous-jacent
/// reste librement modifiable : taper directement "13" fonctionne même si ce
/// n'est pas une des suggestions affichées.
class _ElementCountField extends StatefulWidget {
  const _ElementCountField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_ElementCountField> createState() => _ElementCountFieldState();
}

class _ElementCountFieldState extends State<_ElementCountField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value.toString())..addListener(_handleTextChange);

  void _handleTextChange() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed != null && parsed > 0 && parsed != widget.value) widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Combien d’éléments à métrer ?', style: TextStyle(color: AppColors.grey500)),
          const SizedBox(height: 6),
          DropdownMenu<int>(
            controller: _controller,
            width: double.infinity,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
            ),
            textStyle: const TextStyle(color: AppColors.grey900),
            keyboardType: TextInputType.number,
            dropdownMenuEntries: List.generate(
              10,
              (i) => DropdownMenuEntry(value: i + 1, label: '${i + 1}'),
            ),
            // Le contrôleur accepte aussi une saisie libre (ex. "13") qui ne
            // correspond à aucune entrée listée — `_handleTextChange` capte
            // ce cas en écoutant directement le texte, en plus des choix
            // pris dans le menu (qui écrivent aussi dans ce contrôleur).
            onSelected: (v) {
              if (v != null) widget.onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({required this.label, this.value, this.onChanged});

  final String label;
  final int? value;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value?.toString() ?? '';
    final controller = TextEditingController(text: text)
      ..selection = TextSelection.collapsed(offset: text.length);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey500)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.grey900),
            onChanged: (text) {
              final parsed = int.tryParse(text);
              onChanged?.call(parsed);
            },
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
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
