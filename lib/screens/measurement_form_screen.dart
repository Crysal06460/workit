import 'package:flutter/material.dart';

const Color _bg = Color(0xFF07090D);
const Color _accent = Color(0xFF00E676); // Metreur Green
const Color _cardBg = Color(0xFF13161C);

class MeasurementFormScreen extends StatefulWidget {
  const MeasurementFormScreen({super.key, required this.draftData});

  final Map<String, dynamic> draftData;

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  PageController? _pageControllerCached;
  PageController get _pageController => _pageControllerCached ??= PageController(initialPage: _currentIndex);

  List<Map<String, dynamic>>? _productsCached;
  List<Map<String, dynamic>> get _products => _productsCached ??=
      (widget.draftData['products'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

  int _currentIndex = 0;

  // Temporary local state for measurements
  final Map<int, Map<String, String>> _measurements = {};

  @override
  void initState() {
    super.initState();
    // Initialize measurements from existing product data
    final products = (widget.draftData['products'] as List<dynamic>? ?? []);
    for (int i = 0; i < products.length; i++) {
        final p = products[i] as Map<String, dynamic>;
        if (p['largeurReelle'] != null || p['hauteurReelle'] != null || p['cjHaut'] != null) {
             _measurements[i] = {
                'width': p['largeurReelle']?.toString() ?? '',
                'height': p['hauteurReelle']?.toString() ?? '',
                 'cjHaut': p['cjHaut']?.toString() ?? '',
                 'cjBas': p['cjBas']?.toString() ?? '',
                 'cjGauche': p['cjGauche']?.toString() ?? '',
                 'cjDroite': p['cjDroite']?.toString() ?? '',
                 'note': p['note']?.toString() ?? '',
                 'ref': p['ref']?.toString() ?? '',
                 'color': p['couleur']?.toString() ?? '', // Pre-fill with existing color if not modified? 
                 // Actually color might be different from planned. Be simpler:
                 // if new color is set, use it. if not, allow user to input.
                 // let's check if 'couleur' was modified? No, separate field if we want distinct 'couleurReelle' but user asked for just color.
                 // Let's assume the input fields in schematic override or refine.
             };
              // Special case: if these fields are set, use them.
             if (p['couleur'] != null) _measurements[i]!['color'] = p['couleur']; 
             if (p['quantite'] != null) _measurements[i]!['qty'] = p['quantite'].toString();
        } else {
             // Pre-populate with planned values for convenience?
              _measurements[i] = {
                 'color': p['couleur']?.toString() ?? '',
                 'qty': p['quantite']?.toString() ?? '1',
              };
        }
    }
  }

  @override
  void dispose() {
    _pageControllerCached?.dispose();
    super.dispose();
  }

  void _updateMeasurement(int index, String key, String value) {
    setState(() {
      if (!_measurements.containsKey(index)) {
        _measurements[index] = {};
      }
      _measurements[index]![key] = value;
    });
  }

  String _getMeasurement(int index, String key) {
    return _measurements[index]?[key] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Prise de mesure (${_currentIndex + 1}/${_products.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white70),
            onPressed: () {
              // TODO: Print/PDF feature
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _products.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, index) {
                  return _SchematicEditor(
                    product: _products[index],
                    index: index,
                    measurements: _measurements[index] ?? {},
                    onUpdate: (key, val) => _updateMeasurement(index, key, val),
                  );
                },
              ),
            ),
            _BottomNav(
              total: _products.length,
              current: _currentIndex,
              onNext: () {
                if (_currentIndex < _products.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  // Merge measurements back into products
                  final updatedProducts = List<Map<String, dynamic>>.from(_products);
                  _measurements.forEach((index, data) {
                    if (index < updatedProducts.length) {
                       final existing = updatedProducts[index];
                       updatedProducts[index] = {
                         ...existing,
                         'largeurReelle': data['width'],
                         'hauteurReelle': data['height'],
                         'cjHaut': data['cjHaut'],
                         'cjBas': data['cjBas'],
                         'cjGauche': data['cjGauche'],
                         'cjDroite': data['cjDroite'],
                         'note': data['note'],
                         'ref': data['ref'],
                         // Allow updating color/qty if changed
                         if (data['color']?.isNotEmpty == true) 'couleur': data['color'],
                         if (data['qty']?.isNotEmpty == true) 'quantite': int.tryParse(data['qty']!) ?? existing['quantite'],
                       };
                    }
                  });

                  // Return updated data
                  Navigator.of(context).pop(updatedProducts);
                }
              },
              onPrev: () {
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SchematicEditor extends StatelessWidget {
  const _SchematicEditor({
    required this.product,
    required this.index,
    required this.measurements,
    required this.onUpdate,
  });

  final Map<String, dynamic> product;
  final int index;
  final Map<String, String> measurements;
  final Function(String, String) onUpdate;

  @override
  Widget build(BuildContext context) {
    final title = product['typeProduit']?.toString() ?? 'Produit ${index + 1}';
    final wPrev = product['largeur']?.toString() ?? '-';
    final hPrev = product['hauteur']?.toString() ?? '-';

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available space
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        
        // Dynamic sizing based on screen size
        final double frameSize = w < 400 ? 180 : 240;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.window, color: _accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prévu: $wPrev x $hPrev mm',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Schematic View Container (Frame + CJs)
                SizedBox(
                  height: 360, 
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Central Frame Visual with Note
                      Container(
                        width: frameSize,
                        height: frameSize,
                        decoration: BoxDecoration(
                          color: _cardBg,
                          border: Border.all(color: Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('NOTE',
                                  style: TextStyle(
                                      color: Colors.white30,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: TextField(
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    hintText: 'Ajouter une note...',
                                    hintStyle: TextStyle(color: Colors.white12),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onChanged: (v) => onUpdate('note', v),
                                  controller: TextEditingController(text: measurements['note'])
                                    ..selection = TextSelection.collapsed(
                                        offset: measurements['note']?.length ?? 0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // CJ Haut (Top Center)
                      Positioned(
                        top: 0,
                        child: _SchematicInput(
                          label: 'CJ Haut', 
                          value: measurements['cjHaut'],
                          onChanged: (v) => onUpdate('cjHaut', v),
                        ),
                      ),

                      // CJ Bas (Bottom Center)
                      Positioned(
                        bottom: 0, 
                        child: _SchematicInput(
                          label: 'CJ Bas', 
                          value: measurements['cjBas'],
                          onChanged: (v) => onUpdate('cjBas', v),
                        ),
                      ),

                      // CJ Gauche (Left Center)
                      Positioned(
                        left: 0,
                        child: _SchematicInput(
                          label: 'CJ Gauche', 
                          value: measurements['cjGauche'],
                           onChanged: (v) => onUpdate('cjGauche', v),
                        ),
                      ),

                      // CJ Droite (Right Center)
                      Positioned(
                        right: 0,
                        child: _SchematicInput(
                          label: 'CJ Droite', 
                          value: measurements['cjDroite'],
                           onChanged: (v) => onUpdate('cjDroite', v),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),

                // Main Dimensions Row (Width & Height below the frame)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Expanded(
                       child: _MainDimensionInput(
                        label: 'Largeur',
                        value: measurements['width'], 
                         onChanged: (v) => onUpdate('width', v),
                      ),
                     ),
                     const SizedBox(width: 16),
                     Expanded(
                       child: _MainDimensionInput(
                        label: 'Hauteur',
                        value: measurements['height'], 
                         onChanged: (v) => onUpdate('height', v),
                      ),
                     ),
                  ],
                ),
                
                const SizedBox(height: 20),
                // Footer Inputs
                Row(
                  children: [
                    Expanded(child: _FooterInput(label: 'Couleur', hint: 'Ex: RAL 9010', value: measurements['color'], onChanged: (v) => onUpdate('color', v))),
                    const SizedBox(width: 12),
                    Expanded(child: _FooterInput(label: 'Quantité', hint: 'Ex: 1', value: measurements['qty'], onChanged: (v) => onUpdate('qty', v))),
                  ],
                ),
                 const SizedBox(height: 12),
                _FooterInput(label: 'Référence / Emplacement', hint: 'Ex: Salon fenêtre gauche', value: measurements['ref'], onChanged: (v) => onUpdate('ref', v)),

              ],
            ),
          ),
        );
      },
    );
  }
}

class _SchematicInput extends StatelessWidget {
  const _SchematicInput({required this.label, required this.onChanged, this.value});
  final String label;
  final ValueChanged<String> onChanged;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value?.length ?? 0);
      
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Container(
          width: 60,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
             onChanged: onChanged,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(bottom: 14), // Center vertically roughly
            ),
          ),
        ),
      ],
    );
  }
}

class _MainDimensionInput extends StatelessWidget {
   const _MainDimensionInput({required this.label, required this.onChanged, this.value});
  final String label;
  final ValueChanged<String> onChanged;
  final String? value;

  @override
  Widget build(BuildContext context) {
     final controller = TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value?.length ?? 0);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2)),
        ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
           const SizedBox(height: 4),
           SizedBox(
             width: 80,
             height: 24,
             child: TextField(
                controller: controller,
                onChanged: onChanged,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 18,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white12),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
             ),
           ),
        ],
      ),
    );
  }
}

class _FooterInput extends StatelessWidget {
  const _FooterInput({required this.label, required this.hint, required this.onChanged, this.value});
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final String? value;

  @override
  Widget build(BuildContext context) {
       final controller = TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value?.length ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
             border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.total,
    required this.current,
    required this.onNext,
    required this.onPrev,
  });

  final int total;
  final int current;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  @override
  Widget build(BuildContext context) {
    final isLast = current == total - 1;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bg,
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          if (current > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? _accent : Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: onNext,
              child: Text(
                isLast ? 'Terminer et Valider' : 'Suivant',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
