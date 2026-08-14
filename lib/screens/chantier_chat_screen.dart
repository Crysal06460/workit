import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';

const String _chatStorageBucket = 'gs://workit-1daa1.firebasestorage.app';

String _chatLastReadKey(String devisId) => 'workit_chat_lastread_$devisId';

Color _roleColor(String? role) {
  switch (role) {
    case 'commercial':
      return AppColors.roleCommercial;
    case 'metreur':
      return AppColors.roleMetteur;
    case 'poseur':
      return AppColors.rolePoseur;
    case 'admin':
      return AppColors.roleAdmin;
    default:
      return AppColors.grey500;
  }
}

/// Bouton d'entrée vers la messagerie d'un chantier, avec un badge "non lu"
/// simple (comparaison locale entre le dernier message et la dernière
/// ouverture de ce fil, stockée en SharedPreferences).
///
/// Résout lui-même le `workspaceId` courant depuis SharedPreferences (comme
/// le fait déjà chaque écran de ce projet) pour rester trivial à intégrer
/// depuis n'importe quelle fiche détail (commercial/métreur/poseur/admin).
class ChatEntryButton extends StatelessWidget {
  const ChatEntryButton({
    super.key,
    required this.devisId,
    required this.clientLabel,
    this.color,
  });

  final String devisId;
  final String clientLabel;
  final Color? color;

  Future<String?> _workspaceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('workit_workspace_id');
  }

  Future<bool> _hasUnread(Timestamp? latest, String? latestSenderId) async {
    if (latest == null) return false;
    // Son propre dernier message n'est jamais "non lu" pour soi-même —
    // sinon le point rouge s'allume dès qu'on vient d'écrire.
    if (latestSenderId != null && latestSenderId == FirebaseAuth.instance.currentUser?.uid) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final lastReadIso = prefs.getString(_chatLastReadKey(devisId));
    if (lastReadIso == null) return true;
    final lastRead = DateTime.tryParse(lastReadIso);
    if (lastRead == null) return true;
    return latest.toDate().isAfter(lastRead);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _workspaceId(),
      builder: (context, wsSnap) {
        final workspaceId = wsSnap.data;
        if (workspaceId == null || workspaceId.isEmpty) {
          return IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: color ?? AppColors.grey500),
            onPressed: null,
          );
        }

        final messagesRef = FirebaseFirestore.instance
            .collection('workspaces')
            .doc(workspaceId)
            .collection('devis')
            .doc(devisId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(1);

        return StreamBuilder<QuerySnapshot>(
          stream: messagesRef.snapshots(),
          builder: (context, snap) {
            Timestamp? latest;
            String? latestSenderId;
            if (snap.hasData && snap.data!.docs.isNotEmpty) {
              final data = snap.data!.docs.first.data() as Map<String, dynamic>;
              latest = data['createdAt'] as Timestamp?;
              latestSenderId = data['senderId']?.toString();
            }
            return FutureBuilder<bool>(
              future: _hasUnread(latest, latestSenderId),
              builder: (context, unreadSnap) {
                final unread = unreadSnap.data ?? false;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline, color: color ?? AppColors.grey500),
                      tooltip: 'Messagerie du chantier',
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          _chatLastReadKey(devisId),
                          DateTime.now().toIso8601String(),
                        );
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChantierChatScreen(
                                workspaceId: workspaceId,
                                devisId: devisId,
                                clientLabel: clientLabel,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    if (unread)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Pastille "N messages non lus" à poser directement sur une vignette de la
/// liste d'accueil — même mécanique de lecture locale (SharedPreferences)
/// que [ChatEntryButton], mais avec un vrai compte au lieu d'un simple point,
/// pour rester visible sans avoir à ouvrir la vignette puis l'icône message.
class WiUnreadMessageBadge extends StatelessWidget {
  const WiUnreadMessageBadge({super.key, required this.devisId, this.workspaceId});

  final String devisId;
  final String? workspaceId;

  Future<String?> _resolveWorkspaceId() async {
    if (workspaceId != null && workspaceId!.isNotEmpty) return workspaceId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('workit_workspace_id');
  }

  Future<DateTime?> _lastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_chatLastReadKey(devisId));
    return iso == null ? null : DateTime.tryParse(iso);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveWorkspaceId(),
      builder: (context, wsSnap) {
        final ws = wsSnap.data;
        if (ws == null || ws.isEmpty) return const SizedBox.shrink();
        return FutureBuilder<DateTime?>(
          future: _lastRead(),
          builder: (context, lastReadSnap) {
            if (!lastReadSnap.hasData && lastReadSnap.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            final lastRead = lastReadSnap.data;
            final messagesRef = FirebaseFirestore.instance
                .collection('workspaces')
                .doc(ws)
                .collection('devis')
                .doc(devisId)
                .collection('messages');
            final query = lastRead == null
                ? messagesRef
                : messagesRef.where('createdAt', isGreaterThan: Timestamp.fromDate(lastRead));
            final myUid = FirebaseAuth.instance.currentUser?.uid;
            return StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snap) {
                // Ne jamais compter ses propres messages comme "non lus" —
                // sinon le badge grimpe même quand c'est l'utilisateur lui-même
                // qui vient d'écrire (constaté en test réel : le compteur
                // montait pendant les allers-retours de test).
                final count = snap.data?.docs
                        .where((d) => (d.data() as Map<String, dynamic>)['senderId'] != myUid)
                        .length ??
                    0;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Fil de discussion dédié à un chantier, partagé entre commercial, métreur,
/// poseurs et admin — accessible depuis la fiche détail de chacun de ces
/// rôles via [ChatEntryButton].
class ChantierChatScreen extends StatefulWidget {
  const ChantierChatScreen({
    super.key,
    required this.workspaceId,
    required this.devisId,
    required this.clientLabel,
  });

  final String workspaceId;
  final String devisId;
  final String clientLabel;

  @override
  State<ChantierChatScreen> createState() => _ChantierChatScreenState();
}

class _ChantierChatScreenState extends State<ChantierChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  String? _senderName;
  String? _senderRole;
  bool _sending = false;

  CollectionReference<Map<String, dynamic>> get _messagesRef => _firestore
      .collection('workspaces')
      .doc(widget.workspaceId)
      .collection('devis')
      .doc(widget.devisId)
      .collection('messages');

  @override
  void initState() {
    super.initState();
    _loadSenderContext();
    _markAsRead();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatLastReadKey(widget.devisId), DateTime.now().toIso8601String());
  }

  Future<void> _loadSenderContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return;
      final first = data['firstName']?.toString().trim() ?? '';
      final last = data['lastName']?.toString().trim() ?? '';
      final name = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
      if (!mounted) return;
      setState(() {
        _senderName = name.isNotEmpty ? name : (data['email']?.toString() ?? 'Utilisateur');
        _senderRole = data['role']?.toString();
      });
    } catch (_) {
      // ignore, fallback aux valeurs par défaut au moment de l'envoi
    }
  }

  Future<void> _sendMessage({String text = '', List<Map<String, String>> attachments = const []}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _messagesRef.add({
      'senderId': uid,
      'senderName': _senderName ?? 'Utilisateur',
      'senderRole': _senderRole ?? '',
      'text': text,
      'attachments': attachments,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _sendMessage(text: text);
  }

  Future<void> _pickAndSendPhoto() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    await _uploadAndSend(await xfile.readAsBytes(), xfile.name, 'image');
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final file = result?.files.isNotEmpty == true ? result!.files.first : null;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await _uploadAndSend(bytes, file.name, 'file');
  }

  Future<void> _uploadAndSend(Uint8List bytes, String fileName, String type) async {
    setState(() => _sending = true);
    try {
      final storedName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = FirebaseStorage.instanceFor(bucket: _chatStorageBucket)
          .ref()
          .child('chantier_messages/${widget.workspaceId}/${widget.devisId}/$storedName');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      await _sendMessage(attachments: [
        {'url': url, 'name': fileName, 'type': type},
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Envoi impossible : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined, color: AppColors.primary),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: AppColors.primary),
              title: const Text('Fichier (PDF, image)'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.clientLabel,
          style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Aucun message pour ce chantier.', style: TextStyle(color: AppColors.grey400)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMine = data['senderId'] == currentUid;
                    final attachments = (data['attachments'] as List?)
                            ?.whereType<Map>()
                            .map((m) => Map<String, dynamic>.from(m))
                            .toList() ??
                        const <Map<String, dynamic>>[];
                    return _MessageBubble(
                      isMine: isMine,
                      senderName: data['senderName']?.toString() ?? '',
                      roleColor: _roleColor(data['senderRole']?.toString()),
                      text: data['text']?.toString() ?? '',
                      attachments: attachments,
                      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
                    );
                  },
                );
              },
            ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.grey500),
                    onPressed: _sending ? null : _showAttachmentSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: AppColors.grey900),
                      decoration: InputDecoration(
                        hintText: 'Écrire un message…',
                        hintStyle: const TextStyle(color: AppColors.grey400),
                        filled: true,
                        fillColor: AppColors.grey50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _sendText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.isMine,
    required this.senderName,
    required this.roleColor,
    required this.text,
    required this.attachments,
    required this.createdAt,
  });

  final bool isMine;
  final String senderName;
  final Color roleColor;
  final String text;
  final List<Map<String, dynamic>> attachments;
  final DateTime? createdAt;

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? AppColors.primary : roleColor.withOpacity(0.12);
    final fg = isMine ? Colors.white : AppColors.grey900;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            for (final att in attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () async {
                    final url = att['url']?.toString();
                    if (url != null) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                  child: att['type'] == 'image'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            att['url']?.toString() ?? '',
                            width: 180,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file, color: fg, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                att['name']?.toString() ?? 'Fichier',
                                style: TextStyle(color: fg, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            if (text.isNotEmpty) Text(text, style: TextStyle(color: fg, fontSize: 14)),
            const SizedBox(height: 2),
            Text(_fmtTime(createdAt), style: TextStyle(color: fg.withOpacity(0.6), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
