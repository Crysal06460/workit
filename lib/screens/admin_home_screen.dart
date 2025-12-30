import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_company_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_team_tab.dart';
import 'sign_in_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, this.workspaceId});
  
  final String? workspaceId;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _workspaceId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.workspaceId != null) {
      _workspaceId = widget.workspaceId;
      _loading = false;
    } else {
      _loadWorkspace();
    }
  }

  Future<void> _loadWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workspaceId = prefs.getString('workit_workspace_id');
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF07090D),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_workspaceId == null) {
      return const Scaffold(
         backgroundColor: Color(0xFF07090D),
         body: Center(child: Text('Aucun espace de travail trouvé.', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF00E676)),
              tooltip: 'Se déconnecter',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFF00E676),
          tabs: const [
            Tab(text: 'Tableau de bord', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Équipe', icon: Icon(Icons.group_outlined)),
            Tab(text: 'Entreprise', icon: Icon(Icons.business_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminDashboardTab(workspaceId: _workspaceId!),
          AdminTeamTab(workspaceId: _workspaceId!),
          AdminCompanyTab(workspaceId: _workspaceId!),
        ],
      ),
    );
  }
}
