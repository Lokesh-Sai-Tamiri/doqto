/// ============================================================================
/// CREATE GROUP SCREEN - Create a new group conversation
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../contacts/data/repositories/contacts_repository.dart';
import '../../../contacts/data/models/connection_model.dart';
import '../providers/messaging_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<NetworkContactModel> _contacts = [];
  List<NetworkContactModel> _filteredContacts = [];
  bool _isLoadingContacts = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final repository = ContactsRepository();
      final contacts = await repository.getNetwork();

      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
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

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 members')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    final group = await ref.read(groupProvider.notifier).createGroup(
          name: name,
          participantIds: _selectedUserIds.toList(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        );

    if (group != null && mounted) {
      context.pop();
      // Navigate to the new group chat
      context.push(
        '/chat/${group.conversationId}',
        extra: {
          'userName': group.conversationDisplayName,
          'isGroup': true,
        },
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create group'),
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
          'New Group',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: groupState.isLoading ? null : _createGroup,
            child: groupState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Create',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Group info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group name field
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Group name',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.group, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),

                // Description field
                TextField(
                  controller: _descriptionController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon:
                        const Icon(Icons.description, color: AppColors.textSecondary),
                  ),
                ),
              ],
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

          // Divider
          const Divider(color: AppColors.divider),

          // Member selection header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Add Members',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedUserIds.length} selected',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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

          const SizedBox(height: 8),

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
              _searchQuery.isNotEmpty ? 'No contacts found' : 'No contacts yet',
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
