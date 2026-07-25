import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/di/providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/network_profile.dart';
import '../../../state/groups_state.dart';
import '../../../state/network_state.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/member_row.dart';
import '../../widgets/step_flow.dart';

/// 3-step group creation: Identity → Access → Invite. Chrome is the shared
/// [StepFlow]. Creates a real Group entity (POST /groups), then optionally
/// sends invites, then opens the group detail.
class CreateGroupFlowScreen extends ConsumerStatefulWidget {
  const CreateGroupFlowScreen({super.key});

  @override
  ConsumerState<CreateGroupFlowScreen> createState() =>
      _CreateGroupFlowScreenState();
}

class _CreateGroupFlowScreenState extends ConsumerState<CreateGroupFlowScreen> {
  int _step = 0;

  final _name = TextEditingController();
  final _description = TextEditingController();

  GroupVisibility _visibility = GroupVisibility.private;
  GroupJoinPolicy _joinPolicy = GroupJoinPolicy.request;
  final Set<String> _invitees = {};

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _identityValid => _name.text.trim().isNotEmpty;

  bool get _isLastStep => _step == 2;

  String get _nextLabel => _isLastStep ? Strings.groupsCreateCta : Strings.groupsNext;

  VoidCallback? get _onNext {
    if (_submitting) return null;
    if (_step == 0 && !_identityValid) return null;
    return _advance;
  }

  void _advance() {
    if (_isLastStep) {
      _submit();
    } else {
      setState(() => _step++);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(groupsRepositoryProvider);
      final group = await repo.createGroup(
        name: _name.text.trim(),
        description: _description.text.trim(),
        visibility: _visibility,
        joinPolicy: _joinPolicy,
      );
      // Send invites (best-effort — a failed invite doesn't undo the group).
      for (final id in _invitees) {
        try {
          await repo.inviteUser(group.id, id);
        } catch (_) {}
      }
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      // Replace the flow with the new group's detail.
      context.pushReplacement(AppRoutes.group(group.id));
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ErrorMessages.forApi(e)),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(title: const Text(Strings.groupsCreate)),
      body: StepFlow(
        currentStep: _step,
        stepTitles: const [
          Strings.groupsStepIdentity,
          Strings.groupsStepAccess,
          Strings.groupsStepInvite,
        ],
        onBack: _step == 0 ? null : () => setState(() => _step--),
        onNext: _onNext,
        nextLabel: _nextLabel,
        loading: _submitting,
        child: _stepBody(),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _identityStep();
      case 1:
        return _accessStep();
      default:
        return _inviteStep();
    }
  }

  // ---- Step 1: Identity --------------------------------------------------
  Widget _identityStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      children: [
        Center(
          child: DoctorAvatar(
            initials: _name.text.trim().isEmpty
                ? '?'
                : initialsOf(_name.text.trim()),
            colorIndex: _name.text.hashCode.abs(),
            size: AvatarSize.xxl,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _name,
          label: Strings.groupsNameLabel,
          hint: Strings.groupNameHint,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _description,
          label: Strings.groupsDescriptionLabel,
          hint: Strings.groupsDescriptionHint,
        ),
      ],
    );
  }

  // ---- Step 2: Access ----------------------------------------------------
  Widget _accessStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      children: [
        Text(Strings.groupsVisibilityLabel, style: AppText.label),
        const SizedBox(height: AppSpacing.sm),
        SelectableRow(
          title: 'Public',
          subtitle: Strings.groupsVisPublic,
          icon: Icons.public,
          selected: _visibility == GroupVisibility.public,
          onTap: () => setState(() => _visibility = GroupVisibility.public),
        ),
        SelectableRow(
          title: 'Private',
          subtitle: Strings.groupsVisPrivate,
          icon: Icons.lock_outline,
          selected: _visibility == GroupVisibility.private,
          onTap: () => setState(() => _visibility = GroupVisibility.private),
        ),
        SelectableRow(
          title: 'Secret',
          subtitle: Strings.groupsVisSecret,
          icon: Icons.visibility_off_outlined,
          selected: _visibility == GroupVisibility.secret,
          onTap: () => setState(() => _visibility = GroupVisibility.secret),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(Strings.groupsJoinPolicyLabel, style: AppText.label),
        const SizedBox(height: AppSpacing.sm),
        SelectableRow(
          title: Strings.groupJoin,
          subtitle: Strings.groupsPolicyOpen,
          icon: Icons.group_add_outlined,
          selected: _joinPolicy == GroupJoinPolicy.open,
          onTap: () => setState(() => _joinPolicy = GroupJoinPolicy.open),
        ),
        SelectableRow(
          title: Strings.groupRequestToJoin,
          subtitle: Strings.groupsPolicyRequest,
          icon: Icons.how_to_reg_outlined,
          selected: _joinPolicy == GroupJoinPolicy.request,
          onTap: () => setState(() => _joinPolicy = GroupJoinPolicy.request),
        ),
        SelectableRow(
          title: 'Invite only',
          subtitle: Strings.groupsPolicyInviteOnly,
          icon: Icons.mail_outline,
          selected: _joinPolicy == GroupJoinPolicy.inviteOnly,
          onTap: () => setState(() => _joinPolicy = GroupJoinPolicy.inviteOnly),
        ),
      ],
    );
  }

  // ---- Step 3: Invite ----------------------------------------------------
  Widget _inviteStep() {
    final async = ref.watch(connectionsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            0,
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Strings.groupsInviteStepTitle, style: AppText.subheading),
              const SizedBox(height: AppSpacing.xs),
              Text(Strings.groupsInviteStepBody, style: AppText.caption),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const SkeletonList(),
            error: (e, _) => Center(
              child: Text(ErrorMessages.forApi(e), style: AppText.caption),
            ),
            data: (connections) {
              if (connections.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      Strings.netEmptyConnections,
                      style: AppText.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: connections.length,
                itemBuilder: (context, i) {
                  final c = connections[i];
                  final selected = _invitees.contains(c.id);
                  return _InviteRow(
                    person: c,
                    selected: selected,
                    onTap: () => setState(() {
                      if (selected) {
                        _invitees.remove(c.id);
                      } else {
                        _invitees.add(c.id);
                      }
                    }),
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

class _InviteRow extends StatelessWidget {
  final PersonCard person;
  final bool selected;
  final VoidCallback onTap;
  const _InviteRow({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MemberRow(
      selected: selected,
      avatar: DoctorAvatar(
        initials: person.initials,
        colorIndex: person.avatarIndex,
        imageUrl: person.avatarPresignedUrl,
        isSelected: selected,
      ),
      title: person.fullName,
      subtitle: person.specialty ?? person.headline,
      trailing: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected ? AppColors.medBlue : AppColors.gray400,
      ),
      onTap: onTap,
    );
  }
}
