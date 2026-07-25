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

  // Networking (spec §18 copy deck — M0; screens wire these in M1–M5.
  // Legacy inline literals elsewhere are tracked debt, not retrofitted here.)
  // -- Connection buttons / states
  static const String netConnect = 'Connect';
  static const String netPending = 'Pending';
  static const String netConnected = 'Connected';
  static const String netMessage = 'Message';
  static const String netSendMessageRequest = 'Send message request';
  static const String netAccept = 'Accept';
  static const String netDecline = 'Decline';
  static const String netIgnore = 'Ignore';
  static const String netWithdraw = 'Withdraw';
  static const String netRemoveConnection = 'Remove connection';
  static const String netBlock = 'Block';
  static const String netUnblock = 'Unblock';
  static const String netReport = 'Report';
  // -- Labels
  static const String netTabNetwork = 'Network';
  static const String netTabGroups = 'Groups';
  static const String netInvitations = 'Invitations';
  static const String netConnections = 'Connections';
  static const String netMutualConnections = 'Mutual connections';
  static const String netDegreeFirst = '1st';
  static const String netDegreeSecond = '2nd';
  static const String netDegreeGroup = 'Group';
  static const String netFilterFocused = 'Focused';
  static const String netFilterRequests = 'Requests';
  // -- Reason lines (why you can / can't reach someone)
  static const String netReasonSameOrg = 'You work in the same organization';
  static const String netReasonConnected = 'You are connected';
  static const String netReasonSharedGroup = 'You share a group';
  static const String netReasonRequestNeeded =
      'Not connected — your first message is sent as a request';
  static const String netReasonUnavailable = 'This user is unavailable';
  // -- Message requests
  static const String netRequestBannerSender =
      'Request sent. You can send more messages once they accept.';
  static const String netRequestBannerRecipient =
      'This is a message request. They can\'t see your activity until you accept.';
  static const String netRequestAcceptedToast = 'Request accepted';
  static const String netRequestDeclinedToast = 'Request declined';
  static const String netRequestHint =
      'One short text message, no links or attachments, until they accept.';
  // -- Toasts
  static const String netInviteSentToast = 'Invitation sent';
  static const String netInviteWithdrawnToast = 'Invitation withdrawn';
  static const String netNowConnectedToast = 'You are now connected';
  static const String netConnectionRemovedToast = 'Connection removed';
  static const String netBlockedToast = 'Blocked';
  static const String netUnblockedToast = 'Unblocked';
  static const String netReportedToast = 'Report submitted';
  // -- Confirmations
  static const String netRemoveConnectionConfirm =
      'Remove this connection? They will not be notified.';
  static const String netBlockConfirm =
      'Block this person? You will no longer see each other or exchange messages.';
  static const String netWithdrawConfirm =
      'Withdraw this invitation? You can send a new one in a few days.';
  static const String netLeaveGroupConfirm = 'Leave this group?';
  // -- Empty states
  static const String netEmptyInvitations = 'No pending invitations';
  static const String netEmptyConnections =
      'No connections yet. Search for colleagues to get started.';
  static const String netEmptySearch = 'No people found. Try a different name.';
  static const String netEmptyRequests = 'No message requests';
  static const String netEmptyGroups =
      'No groups yet. Create one to collaborate across organizations.';
  // -- Groups
  static const String groupJoin = 'Join';
  static const String groupRequestToJoin = 'Request to join';
  static const String groupRequested = 'Requested';
  static const String groupInvited = 'Invited';
  static const String groupMembersLabel = 'Members';
  static const String groupAboutLabel = 'About';
  static const String groupRequestsLabel = 'Requests';
  static const String groupJoinRequestSentToast = 'Join request sent';
  static const String groupJoinedToast = 'You joined the group';
  static const String groupLeftToast = 'You left the group';
  // -- Inline explanations
  static const String netExplainRequestTier =
      'Messages from people outside your network arrive as requests.';
  static const String netExplainDegree =
      '1st: connected · 2nd: connection of a connection';
  static const String netExplainOrgPolicy =
      'Your organization has turned off external networking.';
  // -- Errors
  static const String netErrorGeneric = 'Something went wrong. Try again.';
  static const String netErrorQuota =
      'You\'ve reached your invitation limit for now. Try again later.';
  static const String netErrorCooldown =
      'You can\'t send another invitation to this person yet.';
  static const String netErrorUserUnavailable = 'This user is unavailable.';
  static const String netErrorRequestClosed =
      'You can\'t reply until your request is accepted.';

  // Profile sections
  static const String profileAbout = 'About';
  static const String profileExperience = 'Experience';
  static const String profileSkills = 'Skills';

  // Common
  static const String copy = 'Copy';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String retry = 'Retry';
  static const String loading = 'Loading...';
}
