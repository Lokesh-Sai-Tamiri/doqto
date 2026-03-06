/// ============================================================================
/// MENTION PICKER - Widget for selecting group members to mention
/// ============================================================================
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../data/models/messaging_models.dart';

class MentionPicker extends StatefulWidget {
  final List<ParticipantInfo> members;
  final String? currentUserId;
  final void Function(ParticipantInfo member) onMemberSelected;
  final VoidCallback onClose;

  const MentionPicker({
    super.key,
    required this.members,
    this.currentUserId,
    required this.onMemberSelected,
    required this.onClose,
  });

  @override
  State<MentionPicker> createState() => _MentionPickerState();
}

class _MentionPickerState extends State<MentionPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<ParticipantInfo> _filteredMembers = [];

  @override
  void initState() {
    super.initState();
    // Filter out current user from mention options
    _filteredMembers = widget.members
        .where((m) => m.userId != widget.currentUserId)
        .toList();
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = widget.members
            .where((m) => m.userId != widget.currentUserId)
            .toList();
      } else {
        _filteredMembers = widget.members
            .where((m) =>
                m.userId != widget.currentUserId &&
                m.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Mention someone',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
            ),
          ),

          // Members list
          Expanded(
            child: _filteredMembers.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isNotEmpty
                          ? 'No members found'
                          : 'No members to mention',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceLight,
                          backgroundImage: member.avatarUrl != null
                              ? NetworkImage(member.avatarUrl!)
                              : null,
                          radius: 18,
                          child: member.avatarUrl == null
                              ? Text(
                                  member.initials,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          member.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        dense: true,
                        onTap: () => widget.onMemberSelected(member),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display a mention inline in text
class MentionText extends StatelessWidget {
  final String text;
  final List<String>? mentions;
  final Map<String, ParticipantInfo>? memberMap;
  final String? currentUserId;
  final TextStyle? style;

  const MentionText({
    super.key,
    required this.text,
    this.mentions,
    this.memberMap,
    this.currentUserId,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (mentions == null || mentions!.isEmpty || memberMap == null) {
      return Text(text, style: style);
    }

    // Parse the text to find @mentions and highlight them
    final spans = <InlineSpan>[];
    String remaining = text;

    // Pattern to match @userId format
    final mentionPattern = RegExp(r'@([a-f0-9-]{36})');

    while (remaining.isNotEmpty) {
      final match = mentionPattern.firstMatch(remaining);
      if (match == null) {
        spans.add(TextSpan(text: remaining, style: style));
        break;
      }

      // Add text before the mention
      if (match.start > 0) {
        spans.add(TextSpan(
          text: remaining.substring(0, match.start),
          style: style,
        ));
      }

      // Add the mention with highlight
      final userId = match.group(1)!;
      final member = memberMap![userId];
      final isCurrentUser = userId == currentUserId;

      spans.add(TextSpan(
        text: '@${member?.name ?? 'Unknown'}',
        style: (style ?? const TextStyle()).copyWith(
          color: isCurrentUser ? AppColors.warning : AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ));

      remaining = remaining.substring(match.end);
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
