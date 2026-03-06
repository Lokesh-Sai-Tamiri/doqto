/// ============================================================================
/// GROUP INFO SCREEN - View and manage group details
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/models/messaging_models.dart';
import '../providers/messaging_provider.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? groupName;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  final String? _currentUserId = SupabaseService.client.auth.currentUser?.id;
  bool _isEditingName = false;
  bool _isEditingDescription = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  ConversationModel? _getConversation() {
    final state = ref.watch(conversationsProvider);
    try {
      return state.conversations.firstWhere(
        (c) => c.conversationId == widget.groupId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateGroupName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(groupProvider.notifier).updateGroup(
          conversationId: widget.groupId,
          name: name,
        );

    setState(() => _isEditingName = false);
  }

  Future<void> _updateGroupDescription() async {
    final description = _descriptionController.text.trim();

    await ref.read(groupProvider.notifier).updateGroup(
          conversationId: widget.groupId,
          description: description.isNotEmpty ? description : null,
        );

    setState(() => _isEditingDescription = false);
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Leave Group?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to leave this group? You will need to be added back by an admin to rejoin.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(groupProvider.notifier).leaveGroup(widget.groupId);

      if (success && mounted) {
        context.go('/home');
      }
    }
  }

  Future<void> _removeMember(ParticipantInfo member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Member?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove ${member.name} from this group?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(groupProvider.notifier).removeMember(
            conversationId: widget.groupId,
            userId: member.userId,
          );
    }
  }

  Future<void> _toggleAdmin(ParticipantInfo member) async {
    if (member.isAdmin) {
      await ref.read(groupProvider.notifier).removeAdmin(
            conversationId: widget.groupId,
            userId: member.userId,
          );
    } else {
      await ref.read(groupProvider.notifier).addAdmin(
            conversationId: widget.groupId,
            userId: member.userId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _getConversation();
    final groupInfo = conversation?.groupInfo;
    final isAdmin = conversation?.isUserAdmin(_currentUserId ?? '') ?? false;
    final canEditInfo = isAdmin || !(groupInfo?.settings.onlyAdminsCanEditInfo ?? true);

    if (conversation == null || groupInfo == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: const BackButton(color: AppColors.textPrimary),
          title: Text(
            widget.groupName ?? 'Group Info',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text(
          'Group Info',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add, color: AppColors.primary),
              onPressed: () {
                context.push(
                  '/add-members/${widget.groupId}',
                  extra: {'existingMembers': conversation.memberProfiles},
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Group avatar and name
          Center(
            child: Column(
              children: [
                // Group avatar
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: groupInfo.iconUrl != null
                      ? ClipOval(
                          child: Image.network(
                            groupInfo.iconUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.group,
                              color: AppColors.primary,
                              size: 50,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.group,
                          color: AppColors.primary,
                          size: 50,
                        ),
                ),
                const SizedBox(height: 16),

                // Group name
                if (_isEditingName)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          textAlign: TextAlign.center,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Group name',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: AppColors.primary),
                        onPressed: _updateGroupName,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => setState(() => _isEditingName = false),
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: canEditInfo
                        ? () {
                            _nameController.text = groupInfo.name;
                            setState(() => _isEditingName = true);
                          }
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          groupInfo.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (canEditInfo)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 4),
                Text(
                  '${conversation.memberCount} members',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Description section
          _buildSectionHeader('Description'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isEditingDescription
                ? Column(
                    children: [
                      TextField(
                        controller: _descriptionController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Add a group description',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          border: InputBorder.none,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isEditingDescription = false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: _updateGroupDescription,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: canEditInfo
                        ? () {
                            _descriptionController.text = groupInfo.description ?? '';
                            setState(() => _isEditingDescription = true);
                          }
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            groupInfo.description ?? 'No description',
                            style: TextStyle(
                              color: groupInfo.description != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (canEditInfo)
                          const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // Members section
          _buildSectionHeader('Members'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: conversation.memberProfiles.map((member) {
                final isCurrentUser = member.userId == _currentUserId;
                final isCreator = member.userId == groupInfo.createdBy;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceLight,
                    backgroundImage:
                        member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                    child: member.avatarUrl == null
                        ? Text(
                            member.initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isCurrentUser ? 'You' : member.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (member.isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCreator ? 'Creator' : 'Admin',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: isAdmin && !isCurrentUser && !isCreator
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                          color: AppColors.surface,
                          onSelected: (value) {
                            if (value == 'toggle_admin') {
                              _toggleAdmin(member);
                            } else if (value == 'remove') {
                              _removeMember(member);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'toggle_admin',
                              child: Row(
                                children: [
                                  Icon(
                                    member.isAdmin ? Icons.person_remove : Icons.admin_panel_settings,
                                    color: AppColors.textPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    member.isAdmin ? 'Remove as admin' : 'Make admin',
                                    style: const TextStyle(color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                  SizedBox(width: 8),
                                  Text('Remove', style: TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : null,
                  onTap: !isCurrentUser
                      ? () {
                          // Navigate to member's profile
                          context.push('/contact/${member.userId}');
                        }
                      : null,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 32),

          // Leave group button
          ElevatedButton.icon(
            onPressed: _leaveGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.1),
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Leave Group'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
