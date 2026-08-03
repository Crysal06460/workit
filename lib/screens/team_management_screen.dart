import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'admin_team_tab.dart';

/// Écran "Équipe" accessible à un membre délégué (canManageTeam=true, rôle
/// non-admin) — même UI que côté admin mais restreinte à ses manageableRoles.
class TeamManagementScreen extends StatelessWidget {
  const TeamManagementScreen({
    super.key,
    required this.workspaceId,
    required this.manageableRoles,
  });

  final String workspaceId;
  final List<String> manageableRoles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.grey900),
        title: const Text(
          'Équipe',
          style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: AdminTeamTab(
          workspaceId: workspaceId,
          restrictToRoles: manageableRoles,
        ),
      ),
    );
  }
}
