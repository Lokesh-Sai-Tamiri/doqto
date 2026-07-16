import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/di/providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../data/models/organization.dart';
import '../../../state/org_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/primary_button.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  bool _loading = false;

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _selected.length < 2) return;
    setState(() => _loading = true);
    try {
      final conv = await ref.read(chatRepositoryProvider).createConversation(
            type: ConversationType.group,
            name: name,
            memberIds: _selected.toList(),
          );
      if (!mounted) return;
      context.go(AppRoutes.chat(conv.id));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(orgProvider).current?.id;
    final members = orgId != null ? ref.watch(orgMembersProvider(orgId)) : const AsyncValue<List<OrgMember>>.data([]);
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.groupNewTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(controller: _name, label: 'Group name', hint: Strings.groupNameHint),
            const SizedBox(height: AppSpacing.lg),
            Text(Strings.groupAddMembers, style: AppText.label),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: members.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e', style: AppText.caption),
                data: (list) => ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final selected = _selected.contains(m.user.id);
                    return ListTile(
                      leading: DoctorAvatar(initials: m.user.initials, colorIndex: i),
                      title: Text(m.user.fullName),
                      subtitle: Text(m.user.specialty ?? ''),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: AppColors.medBlue)
                          : const Icon(Icons.add_circle_outline, color: AppColors.gray400),
                      onTap: () => setState(() {
                        if (selected) {
                          _selected.remove(m.user.id);
                        } else {
                          _selected.add(m.user.id);
                        }
                      }),
                    );
                  },
                ),
              ),
            ),
            if (_selected.isNotEmpty) ...[
              const Divider(),
              Text('${Strings.groupSelected} (${_selected.length})', style: AppText.label),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _selected
                    .map((id) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.medBlueLight,
                            borderRadius: AppRadii.rFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(id.substring(0, 6),
                                  style: AppText.button
                                      .copyWith(color: AppColors.medBlueDark, fontSize: 12)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _selected.remove(id)),
                                child: const Icon(Icons.close, size: 14, color: AppColors.medBlueDark),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Create group', onPressed: _submit, loading: _loading, expand: true),
            ],
          ],
        ),
      ),
    );
  }
}
