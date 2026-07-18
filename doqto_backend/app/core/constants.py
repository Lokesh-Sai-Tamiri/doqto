"""TTLs, limits, and other magic numbers — defined ONCE. No inline numbers in services."""

# JWT lifetimes
ACCESS_TOKEN_TTL_SECONDS = 60 * 60  # 1 hour
REFRESH_TOKEN_TTL_SECONDS = 60 * 60 * 24 * 7  # 7 days

# OTP
OTP_TTL_SECONDS = 60 * 10  # 10 minutes
OTP_LENGTH = 6
OTP_MAX_ATTEMPTS = 5

# Dev-only master OTP — works for any phone when ENVIRONMENT=local.
# Never accepted in staging/prod. Safe for simulator + emulator testing.
DEV_MASTER_OTP = "777777"

# Presence
PRESENCE_ONLINE_TTL_SECONDS = 60 * 5  # 5 minutes
PRESENCE_AWAY_TTL_SECONDS = 60 * 30  # 30 minutes
WS_HEARTBEAT_INTERVAL_SECONDS = 60
# Server drops a socket silent for 2 missed heartbeats + grace. Must match
# AppConstants.wsHeartbeatTimeout (130s) on the Flutter side.
WS_HEARTBEAT_TIMEOUT_SECONDS = WS_HEARTBEAT_INTERVAL_SECONDS * 2 + 10

# Presigned URL
PRESIGNED_URL_TTL_SECONDS = 60 * 5  # 5 minutes

# Pagination
MESSAGES_PAGE_SIZE = 50
MEMBERS_PAGE_SIZE = 100

# Voice notes
VOICE_NOTE_MIN_DURATION_SECONDS = 1
VOICE_NOTE_MAX_DURATION_SECONDS = 60 * 5  # 5 minutes
VOICE_NOTE_MAX_FILE_BYTES = 10 * 1024 * 1024  # 10 MB

# Files
FILE_MAX_BYTES = 25 * 1024 * 1024  # 25 MB

# Avatars
AVATAR_MAX_BYTES = 2 * 1024 * 1024  # 2 MB
AVATAR_ALLOWED_MIME = frozenset({"image/jpeg", "image/png", "image/webp"})
AVATAR_ALLOWED_EXT = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}

# Profile validation
BIO_MAX_LEN = 500
SKILLS_MAX_COUNT = 20
SKILL_MAX_LEN = 40
YEARS_OF_EXPERIENCE_MIN = 0
YEARS_OF_EXPERIENCE_MAX = 80

# Invite codes
INVITE_CODE_FORMAT = "XXXX·NNNN"  # 4 letters + middle dot + 4 digits
INVITE_CODE_LETTERS_LEN = 4
INVITE_CODE_DIGITS_LEN = 4

# Rate limiting (requests per minute per user per endpoint)
RATE_LIMIT_DEFAULT_PER_MINUTE = 60
RATE_LIMIT_OTP_PER_HOUR = 5
# Read endpoints (message history, file URLs, member list) — generous.
RATE_LIMIT_READS_PER_MINUTE = 120
# Admin login lockout: attempts per email per window.
ADMIN_LOGIN_MAX_ATTEMPTS = 5
ADMIN_LOGIN_WINDOW_SECONDS = 15 * 60

# OTP request cooldown — mirror of mobile-side Resend button timer. Must match
# AppConstants.otpResendCooldown (30s) on the Flutter side.
OTP_RESEND_COOLDOWN_SECONDS = 30

# Push notifications — PHI-free by policy: these strings are sent verbatim to
# Apple/Google. NEVER interpolate user data (names, message content, phone
# numbers) into push title/body.
PUSH_TITLE = "Doqto"
PUSH_BODY_NEW_MESSAGE = "New message"

# Chat list preview
CHAT_LIST_PREVIEW_MAX_LEN = 140

# Disappearing messages — allowed timer values (seconds → human label).
# Mirror of the option list in the Flutter chat details screen.
DISAPPEAR_OPTIONS_SEC = {
    60 * 60 * 24: "24 hours",
    60 * 60 * 24 * 7: "7 days",
    60 * 60 * 24 * 30: "30 days",
    60 * 60 * 24 * 90: "90 days",
}
DISAPPEAR_PURGE_INTERVAL_SEC = 60
# Hard-delete grace: content of soft-deleted/expired messages is crypto-shredded
# (encrypted blobs nulled, S3 objects deleted) once older than this.
PURGE_CONTENT_GRACE_SEC = 30 * 24 * 3600  # 30 days
