/// ============================================================================
/// ADD MEMBERS SCREEN - Add members to an existing group
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../contacts/data/repositories/contacts_repository.dart';
import '../../../contacts/data/models/connection_model.dart';
import '../../data/models/messaging_models.dart';
import '../providers/messaging_provider.dart';

class AddMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  final List<ParticipantInfo>? existingMembers;

  const AddMembersScreen({
    super.key,
    required this.groupId,
    this.existingMembers,
  });

  @override
  ConsumerState<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends ConsumerState<AddMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<NetworkContactModel> _contacts = [];
  List<NetworkContactModel> _filteredContacts = [];
  bool _isLoadingContacts = true;
  String _searchQuery = '';

  Set<String> get _existingMemberIds =>
      widget.existingMembers?.map((m) => m.userId).toSet() ?? {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final repository = ContactsRepository();
      final contacts = await repository.getNetwork();

      // Filter out existing members
      final availableContacts = contacts
          .where((c) => !_existingMemberIds.contains(c.contactUserId))
          .toList();

      setState(() {
        _contacts = availableContacts;
        _filteredContacts = availableContacts;
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingContacts = false;
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((c) {
          final name = c.fullName.toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _addMembers() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    final success = await ref.read(groupProvider.notifier).addMembers(
          conversationId: widget.groupId,
          userIds: _selectedUserIds.toList(),
        );

    if (success && mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${_selectedUserIds.length} member${_selectedUserIds.length > 1 ? 's' : ''}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add members'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text(
          'Add Members',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: groupState.isLoading || _selectedUserIds.isEmpty
                ? null
                : _addMembers,
            child: groupState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Add (${_selectedUserIds.length})',
                    style: TextStyle(
                      color: _selectedUserIds.isEmpty
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),

          // Selected members chips
          if (_selectedUserIds.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedUserIds.length,
                itemBuilder: (context, index) {
                  final userId = _selectedUserIds.elementAt(index);
                  final contact = _contacts.firstWhere(
                    (c) => c.contactUserId == userId,
                    orElse: () => _contacts.first,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          contact.initials,
                          style: const TextStyle(
                            color: AppColors.textInverse,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      label: Text(
                        contact.firstName ?? contact.displayName ?? 'Unknown',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _toggleSelection(userId),
                      backgroundColor: AppColors.surfaceLight,
                    ),
                  );
                },
              ),
            ),

          const Divider(color: AppColors.divider),

          // Contacts list
          Expanded(
            child: _buildContactsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    if (_isLoadingContacts) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_filteredContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No contacts found'
                  : _contacts.isEmpty
                      ? 'All contacts are already members'
                      : 'No contacts available',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final isSelected = _selectedUserIds.contains(contact.contactUserId);

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceLight,
                backgroundImage:
                    contact.avatarUrl != null ? NetworkImage(contact.avatarUrl!) : null,
                child: contact.avatarUrl == null
                    ? Text(
                        contact.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (isSelected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.textInverse,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            contact.fullName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: contact.specialization != null
              ? Text(
                  contact.specialization!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                )
              : null,
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: AppColors.primary)
              : const Icon(Icons.circle_outlined, color: AppColors.textSecondary),
          onTap: () {
            HapticFeedback.selectionClick();
            _toggleSelection(contact.contactUserId);
          },
        );
      },
    );
  }
}
