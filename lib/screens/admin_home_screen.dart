import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import 'admin_company_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_kpis_tab.dart';
import 'admin_team_tab.dart';
import 'planner_screen.dart';
import 'sign_in_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, this.workspaceId});
  
  final String? workspaceId;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

const String _userFirstNameKey = 'workit_user_first_name';
const String _userLastNameKey = 'workit_user_last_name';

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _workspaceId;
  String? _userFirstName;
  String? _userLastName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    if (widget.workspaceId != null) {
      _workspaceId = widget.workspaceId;
      _loading = false;
      _loadUser();
    } else {
      _loadWorkspace();
    }
  }

  Future<void> _loadWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workspaceId = prefs.getString('workit_workspace_id');
      _userFirstName = prefs.getString(_userFirstNameKey);
      _userLastName = prefs.getString(_userLastNameKey);
      _loading = false;
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userFirstName = prefs.getString(_userFirstNameKey);
      _userLastName = prefs.getString(_userLastNameKey);
    });
  }

  String _greetingName() {
    if (_userFirstName?.trim().isNotEmpty == true) return _userFirstName!.trim();
    if (_userLastName?.trim().isNotEmpty == true) return _userLastName!.trim();
    return '';
  }

  String _initials() {
    final f = _userFirstName?.trim() ?? '';
    final l = _userLastName?.trim() ?? '';
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    if (f.isNotEmpty) return f[0].toUpperCase();
    if (l.isNotEmpty) return l[0].toUpperCase();
    return 'A';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_workspaceId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Aucun espace de travail trouvé.', style: TextStyle(color: AppColors.grey500))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greetingName().isNotEmpty ? 'Bonjour ${_greetingName()} 👋' : 'Bonjour 👋',
              style: const TextStyle(
                color: AppColors.grey900,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const Text(
              'Administrateur',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.grey600),
        actions: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppColors.grey500),
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
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.grey500,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Tableau de bord', icon: Icon(Icons.dashboard_outlined, size: 20)),
                Tab(text: 'KPIs', icon: Icon(Icons.insights_outlined, size: 20)),
                Tab(text: 'Planning', icon: Icon(Icons.view_column_outlined, size: 20)),
                Tab(text: 'Équipe', icon: Icon(Icons.group_outlined, size: 20)),
                Tab(text: 'Entreprise', icon: Icon(Icons.business_outlined, size: 20)),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminDashboardTab(workspaceId: _workspaceId!),
          AdminKpisTab(workspaceId: _workspaceId!),
          PlannerScreen(workspaceId: _workspaceId!, accentColor: AppColors.roleAdmin),
          AdminTeamTab(workspaceId: _workspaceId!),
          AdminCompanyTab(workspaceId: _workspaceId!),
        ],
      ),
    );
  }
}
