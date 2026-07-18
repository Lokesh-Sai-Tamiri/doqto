import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/di/providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/motion.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../data/models/organization.dart';
import '../../../state/org_state.dart';
import '../../widgets/app_pressable.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/fade_slide_in.dart';
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

  bool get _canSubmit => _name.text.trim().isNotEmpty && _selected.length >= 2;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the sticky CTA enabled state as the name is typed.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _loading = true);
    try {
      final conv = await ref.read(chatRepositoryProvider).createConversation(
            type: ConversationType.group,
            name: _name.text.trim(),
            memberIds: _selected.toList(),
          );
      if (!mounted) return;
      context.go(AppRoutes.chat(conv.id));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(orgProvider).current?.id;
    final members = orgId != null
        ? ref.watch(orgMembersProvider(orgId))
        : const AsyncValue<List<OrgMember>>.data([]);
    final memberById = <String, OrgMember>{
      for (final m in members.asData?.value ?? const <OrgMember>[]) m.id: m,
    };
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.groupNewTitle)),
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
                loading: () => const SkeletonList(),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 40, color: AppColors.gray400),
                      const SizedBox(height: AppSpacing.md),
                      Text('Couldn’t load members',
                          style: AppText.body, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Retry',
                        variant: AppButtonVariant.secondary,
                        onPressed: orgId == null
                            ? null
                            : () => ref.invalidate(orgMembersProvider(orgId)),
                      ),
                    ],
                  ),
                ),
                data: (list) => ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final selected = _selected.contains(m.id);
                    return FadeSlideIn.staggered(
                      i,
                      _MemberRow(
                        member: m,
                        colorIndex: i,
                        selected: selected,
                        onTap: () => _toggle(m.id),
                      ),
                      enabled: i <= AppMotion.staggerCap,
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
                              Text(
                                  memberById[id]
                                          ?.fullName
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .first ??
                                      id.substring(0, 6),
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
            ],
          ],
        ),
      ),
      // Sticky CTA in the thumb zone — always visible, enabled once a name
      // and at least two members are chosen.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.md,
          ),
          child: AppButton(
            label: _selected.length < 2
                ? 'Create group'
                : 'Create group (${_selected.length})',
            onPressed: _canSubmit ? _submit : null,
            loading: _loading,
            expand: true,
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final OrgMember member;
  final int colorIndex;
  final bool selected;
  final VoidCallback onTap;

  const _MemberRow({
    required this.member,
    required this.colorIndex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.maybe(context, AppMotion.micro);
    return AppPressable(
      onTap: onTap,
      child: ListTile(
        leading: DoctorAvatar(initials: member.initials, colorIndex: colorIndex),
        title: Text(member.fullName),
        subtitle: Text(member.specialty ?? ''),
        // Selected state animates: outline circle fills brand teal and the
        // checkmark fades in — never snaps.
        trailing: AnimatedContainer(
          duration: duration,
          curve: AppMotion.standard,
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.medBlue : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.medBlue : AppColors.gray400,
              width: 1.5,
            ),
          ),
          child: AnimatedOpacity(
            opacity: selected ? 1.0 : 0.0,
            duration: duration,
            curve: AppMotion.standard,
            child: const Icon(Icons.check, size: 16, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}
