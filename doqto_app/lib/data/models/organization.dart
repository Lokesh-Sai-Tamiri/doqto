import '../../core/enums/app_enums.dart';
import 'user.dart';

class Organization {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? practiceType;
  final String inviteCode;
  final OrgStatus status;
  final String? reviewNotes;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final int memberCount;

  const Organization({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.practiceType,
    required this.inviteCode,
    required this.status,
    required this.reviewNotes,
    required this.verifiedAt,
    required this.createdAt,
    required this.memberCount,
  });

  factory Organization.fromJson(Map<String, dynamic> j) => Organization(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String?,
        city: j['city'] as String?,
        state: j['state'] as String?,
        practiceType: j['practice_type'] as String?,
        inviteCode: j['invite_code'] as String,
        status: OrgStatus.fromWire(j['status'] as String),
        reviewNotes: j['review_notes'] as String?,
        verifiedAt: j['verified_at'] != null ? DateTime.parse(j['verified_at'] as String) : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        memberCount: (j['member_count'] ?? 0) as int,
      );
}

class OrgMember {
  final User user;
  final OrgRole orgRole;
  final DateTime joinedAt;
  final PresenceStatus presence;

  const OrgMember({
    required this.user,
    required this.orgRole,
    required this.joinedAt,
    required this.presence,
  });

  factory OrgMember.fromJson(Map<String, dynamic> j) => OrgMember(
        user: User.fromJson(j['user'] as Map<String, dynamic>),
        orgRole: OrgRole.fromWire(j['org_role'] as String),
        joinedAt: DateTime.parse(j['joined_at'] as String),
        presence: PresenceStatus.fromWire(j['presence'] as String?),
      );
}
