/// UI strings. No inline copy in widgets — every user-facing string lives here.
/// When i18n is on the roadmap, this migrates to ARB + intl without touching widgets.
class Strings {
  Strings._();

  // Brand
  static const String appName = 'Doqto';
  static const String tagline = 'Secure doctor-to-doctor communication';

  // Auth
  static const String authPhoneTitle = 'Enter your phone';
  static const String authPhoneHint = '+1 555 555 0100';
  static const String authSendOtp = 'Send code';
  static const String authOtpTitle = 'Enter verification code';
  static const String authOtpHint = '000000';
  static const String authVerify = 'Verify';
  static const String authResend = 'Resend code';

  // Registration
  static const String regFullName = 'Full name';
  static const String regSpecialty = 'Specialty';
  static const String regNpi = 'NPI number';
  static const String regNpiHelper = 'Find your NPI at nppes.cms.hhs.gov';
  static const String regContinue = 'Continue';

  // Org
  static const String orgSelectTitle = 'Get started';
  static const String orgCreateTitle = 'Create Organization';
  static const String orgCreateSub = 'Set up your hospital or practice';
  static const String orgJoinTitle = 'Join with Invite Code';
  static const String orgJoinSub = 'Your org admin shared a code with you';
  static const String orgInviteCodeLabel = 'Your org invite code';
  static const String orgPendingTitle = 'Verification in Progress';
  static const String orgPendingBody =
      'We are verifying your organization. You will be notified once approved.';

  // Tabs
  static const String tabChats = 'Chats';
  static const String tabDoctors = 'Doctors';
  static const String tabMyOrg = 'My Org';

  // Chat
  static const String chatMessageHint = 'Message...';
  static const String chatRecording = 'Recording...';
  static const String chatRecordingInstruction = 'Release to send · Slide left to cancel';

  // Group
  static const String groupNewTitle = 'New Group';
  static const String groupNameHint = 'e.g. ICU Consult Team';
  static const String groupAddMembers = 'ADD MEMBERS';
  static const String groupSelected = 'SELECTED';
  static const String groupInfoTitle = 'Group Info';
  static const String groupLeave = 'Leave Group';
  static const String groupAddMembersBtn = '+ Add Members';

  // Common
  static const String copy = 'Copy';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String retry = 'Retry';
  static const String loading = 'Loading...';
}
