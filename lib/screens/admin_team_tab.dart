import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/onboarding_models.dart';

class AdminTeamTab extends StatefulWidget {
  const AdminTeamTab({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  State<AdminTeamTab> createState() => _AdminTeamTabState();
}

class _AdminTeamTabState extends State<AdminTeamTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _addMember() async {
     // Show dialog to add member
     if (!mounted) return;
     showDialog(
       context: context, 
       builder: (_) => _AddMemberDialog(workspaceId: widget.workspaceId)
     );
  }

  Future<void> _removeUser(String uid, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1422),
        title: const Text('Supprimer cet utilisateur ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Voulez-vous vraiment supprimer l\'accès de $email ?\nCette action est irréversible (pour l\'instant).',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // In a real app we might call a Cloud Function to disable auth.
        // For now, we just mark status as inactive or delete the doc in 'users'/'provisioned_accounts'
        // Let's delete from 'provisioned_accounts' if it's there
        final provQuery = await _firestore.collection('provisioned_accounts').where('uid', isEqualTo: uid).get();
        for(final doc in provQuery.docs) {
           await doc.reference.delete();
        }
        
        // And update 'users' doc
        await _firestore.collection('users').doc(uid).update({'status': 'disabled', 'companyId': FieldValue.delete()});

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur retiré.')),
          );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Membres de l\'équipe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _addMember,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('companyId', isEqualTo: widget.workspaceId)
                 // We might want to filter out 'disabled' status if we don't want to show them
                 // .where('status', isNotEqualTo: 'disabled') // Requires composite index usually
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Aucun membre trouvé.', style: TextStyle(color: Colors.white70)));
              }
              
              final docs = snapshot.data!.docs.where((d) => d['status'] != 'disabled').toList();

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final role = data['role'] ?? 'Inconnu';
                  final email = data['email'] ?? '';
                  final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                  final uid = docs[index].id;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1422),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          child: Text(
                             (name.isNotEmpty ? name[0] : (email.isNotEmpty ? email[0] : '?')).toUpperCase(),
                             style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isNotEmpty ? name : email,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                roleDisplayName(role),
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                         IconButton(
                           icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                           onPressed: () => _removeUser(uid, email),
                         ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({required this.workspaceId});
  final String workspaceId;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _emailController = TextEditingController();
  String _selectedRole = 'commercial';
  bool _isLoading = false;

  Future<void> _provision() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('provisionAccounts');
      
      final payload = [{
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'companyId': widget.workspaceId,
      }];
      
      final res = await callable.call({'accounts': payload});
      final data = res.data as Map;
      final accounts = (data['accounts'] as List<dynamic>? ?? []);
      
      if (!mounted) return;
      
      if (accounts.isNotEmpty) {
          final acc = accounts.first;
          final pass = acc['tempPassword'];
          Navigator.pop(context);
           showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF0F1422),
              title: const Text('Compte créé', style: TextStyle(color: Colors.white)),
              content: SelectableText(
                'Compte créé pour ${_emailController.text}.\nMot de passe temporaire : $pass\n\nCopiez-le, il ne sera plus affiché.',
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF00E676))),
                ),
              ],
            ),
          );
      } else {
        Navigator.pop(context);
      }
      
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1422),
      title: const Text('Ajouter un membre', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedRole,
             dropdownColor: const Color(0xFF0F1422),
             style: const TextStyle(color: Colors.white),
            items: onboardingRoles.map((role) => DropdownMenuItem(
              value: role,
              child: Text(roleDisplayName(role)),
            )).toList(),
            onChanged: (val) => setState(() => _selectedRole = val!),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          TextButton(
            onPressed: _provision,
            child: const Text('Créer', style: TextStyle(color: Color(0xFF00E676))),
          ),
      ],
    );
  }
}
