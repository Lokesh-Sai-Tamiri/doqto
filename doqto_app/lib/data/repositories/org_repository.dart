import '../../core/constants/api_routes.dart';
import '../../core/enums/app_enums.dart';
import '../api/api_client.dart';
import '../models/organization.dart';

class OrgRepository {
  final ApiClient _api;
  OrgRepository(this._api);

  Future<Organization> create({
    required String name,
    String? address,
    String? city,
    String? state,
    PracticeType? practiceType,
  }) async {
    final j = await _api.post(ApiRoutes.orgs, body: {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'practice_type': practiceType?.wire,
    });
    return Organization.fromJson(j);
  }

  Future<List<Organization>> listMine() async {
    final list = await _api.getList(ApiRoutes.orgsMine);
    return list.map((e) => Organization.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Organization> join(String inviteCode) async {
    final j = await _api.post(ApiRoutes.orgsJoin, body: {'invite_code': inviteCode});
    return Organization.fromJson(j);
  }

  Future<Organization> get(String orgId) async {
    final j = await _api.get(ApiRoutes.orgDetail(orgId));
    return Organization.fromJson(j);
  }

  Future<List<OrgMember>> members(String orgId) async {
    final list = await _api.getList(ApiRoutes.orgMembers(orgId));
    return list.map((e) => OrgMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> inviteCode(String orgId) async {
    final j = await _api.get(ApiRoutes.orgInviteCode(orgId));
    return j['invite_code'] as String;
  }
}
