# NPI lookup & prefill

Registration asks a physician for their name and NPI. The public CMS NPI
Registry already knows both, plus their practice address and taxonomy. This
spec makes registration fill itself in from that registry.

**Status:** implemented. **Scope:** `RegistrationScreen` only; profile editing
is unaffected.

**Non-goal:** verification. A prefill is a convenience, not a trust boundary —
the user can overwrite anything we fill. Authoritative NPI verification stays
a backend concern (see [Open decisions](#open-decisions)).

---

## 1. The data source

Public, free, no API key, no auth, no registration:

```
GET https://npiregistry.cms.hhs.gov/api/?version=2.1&<criteria>
```

`version=2.1` is mandatory. Two queries are used:

| Path | Query |
|---|---|
| By name | `first_name=<first>&last_name=<last>&enumeration_type=NPI-1&limit=2` |
| By NPI | `number=<10 digits>` |

`enumeration_type=NPI-1` restricts to individual providers (NPI-2 is
organizations — irrelevant here, and they have no first/last name).

### `limit=2` is load-bearing

`result_count` is **capped by `limit`** — the API returns no true total. So:

- `result_count == 0` → nobody by that name
- `result_count == 1` → exactly one match, safe to prefill
- `result_count == 2` → **two or more**, ambiguous

That is the entire unique-vs-ambiguous test, and it costs one small request.
Never raise `limit` to "count" matches; we don't need the count, only the
distinction, and a bigger limit means a bigger payload for nothing.

### Response shape

Verified live against `VIMAL NANAVATI` (NPI `1851408082`), trimmed:

```json
{"result_count":1,"results":[{
  "number":"1851408082",
  "enumeration_type":"NPI-1",
  "basic":{"first_name":"VIMAL","last_name":"NANAVATI","middle_name":"I",
           "credential":"M.D.","name_prefix":"Dr.","status":"A"},
  "addresses":[
    {"address_purpose":"MAILING","address_1":"PO BOX 1734","city":"POWAY",
     "state":"CA","postal_code":"920741734","telephone_number":"619-585-0476"},
    {"address_purpose":"LOCATION","address_1":"180 OTAY LAKES RD STE 110",
     "city":"BONITA","state":"CA","postal_code":"919022444",
     "telephone_number":"619-585-0476"}],
  "practiceLocations":[{"address_purpose":"LOCATION","address_1":"2510 AIRPARK DR STE 205",
                        "city":"REDDING","state":"CA","postal_code":"960012461"}],
  "taxonomies":[{"code":"207RI0011X","primary":true,"state":"CA",
                 "desc":"Internal Medicine, Interventional Cardiology"}]
}]}
```

Errors come back **HTTP 200** with an `Errors` array instead of `results`:

```json
{"Errors":[{"description":"NPI must be 10 digits","field":"number","number":"06"}]}
```

Treat any response without a `results` key as "no match". Do not surface CMS
error text to the user — it is written for a web form, not our UI.

### Field extraction

| Registry | Rule | Doqto field |
|---|---|---|
| `number` | as-is | NPI |
| `basic.first_name` / `last_name` | title-case | match-card display only |
| `basic.credential` | as-is, may be absent | match-card display only |
| Primary practice address | first `addresses[]` with `address_purpose == "LOCATION"`, else first `MAILING`, else none | match-card display; `city` + `state` persisted |
| Primary taxonomy | first `taxonomies[]` with `primary == true`, else `taxonomies[0]` | `specialty` |

Ignore `practiceLocations[]` — those are *secondary* locations. The registry's
own "Primary Practice Address" column is the `LOCATION` entry in `addresses[]`.

**Address formatting.** `address_1` + optional `address_2`, then
`CITY, ST ZIP`. `postal_code` arrives as 9 unpunctuated digits — render
`919022444` as `91902-2444`; 5-digit codes pass through unchanged.

**Taxonomy caveat.** The registry *website* shows a rolled-up grouping
("Internal Medicine") while the API's `desc` is the full specialization
("Internal Medicine, Interventional Cardiology"). Use `desc` verbatim. Mapping
NUCC codes back to their grouping means shipping the whole NUCC taxonomy table
to get a shorter string — not worth it. If it reads too long in the specialty
field, truncate at the first comma at *display* time and keep the full string
in state.

---

## 2. Behaviour

### Screen changes

`Full name` (one field) splits into **First name** and **Last name**. The
lookup needs them separately, and `User.fullName` stays `"$first $last"` so
nothing downstream changes.

Field order: First name · Last name · [match card] · Specialty · NPI number.

Both new fields use `AppTextField` (already keyboard-rule compliant per
`CLAUDE.md`) with `Validators.personName('first name' | 'last name')` —
non-empty, ≥ 2 characters. `Validators.fullName()` stays for any other caller.

### State machine

```
idle ──both names ≥2 chars & focus leaves────► querying
querying ──result_count == 1──► matched      (prefill + card)
querying ──result_count >= 2──► ambiguous    (hint, no prefill)
querying ──result_count == 0──► none         (silent, name re-armed)
querying ──timeout/network/error────────────► none (silent, name re-armed)

NPI field reaches 10 digits ──────────────► querying (by number)
   ──1 result──► matched   ──0 results──► none (silent)
```

"None" and "CMS was unreachable" are indistinguishable from the screen, so a
`none` clears the dedupe key and the same name may be asked again. Genuine
misses are cached inside the service, so the retry costs no network.

Held in the screen's `State`. No Riverpod provider — nothing outside this
screen reads it.

### Trigger rules

- **Name path.** Fire when *both* name fields are non-empty and ≥ 2 chars,
  and focus leaves either one. Not on every keystroke — no debounce timer to
  write, no request per character.
- **NPI path.** Fire the moment the NPI field holds 10 digits. `AppTextField`
  already unfocuses on valid fixed-length entry (`dismissOnValid`), so this
  rides the existing callback.
- **Dedupe.** Keep the last query string. Identical query → no second call.
  The service memoises results for the session; no disk cache.
- **Never re-fire** the name path after a successful NPI-path match. The user
  has told us exactly who they are.

### Prefill rules

On `matched`:

1. Show the **match card** (below).
2. Fill NPI (name path only — on the NPI path the user typed it).
3. Fill Specialty **only if empty or previously auto-filled**.
4. Store `city`/`state` from the primary practice address in screen state.
5. **Never touch the name fields.** The user typed them; overwriting their own
   name with a shouty registry variant ("VIMAL" → "Vimal") is a worse
   experience than leaving it alone. The card shows the registry name so they
   can see whether we found the right person.

Every prefilled field stays editable. Once the user edits an auto-filled
field, mark it dirty and never overwrite it again.

On `ambiguous`, clear nothing and prefill nothing. Show the hint under the NPI
field:

> Several clinicians share that name. Enter your NPI and we'll fill in the rest.

On `none`, show nothing at all. Silence is the correct UI for "we couldn't
help" — an error for a feature the user never asked for is noise.

### The match card

Read-only, appears under the name fields, dismissible via a small ✕ (which
returns to `idle` and clears auto-filled values):

```
┌─────────────────────────────────────────────┐
│ Found on the NPI registry                 ✕ │
│ Vimal Nanavati, M.D.        NPI 1851408082  │
│ 180 Otay Lakes Rd Ste 110                   │
│ Bonita, CA 91902-2444                       │
│ Internal Medicine, Interventional Cardiology│
└─────────────────────────────────────────────┘
```

Animated in with the existing `FadeSlideIn`. No new widget vocabulary.

### Failure handling

The lookup is best-effort and **never blocks**:

- `Continue` is enabled and submits regardless of lookup state.
- If a lookup is in flight when the user hits `Continue`, submit immediately;
  drop the in-flight result.
- 5-second timeout, one attempt, no retry. CMS is either up or it isn't.
- Any exception → `none`, caught twice: `NpiLookup` swallows transport errors,
  and the screen wraps every call again so a swapped-in provider that throws
  can never reach the user.
- No in-flight spinner. The card appearing is the feedback, and an
  indeterminate spinner is an animation that never lets a widget test settle.

### Privacy

We send the user's own first and last name to a public federal registry that
already lists them. No PHI, no phone, no identifiers.

There used to be an on-screen line saying so ("We look this up on the public
CMS NPI registry."). It went with the other helper texts; if the lookup ever
needs disclosing, the privacy policy is the place for it.

---

## 3. Implementation

### Files

| File | Change |
|---|---|
| `lib/data/services/npi_lookup.dart` | **new** — `NpiMatch` model + `NpiLookup` service (~90 lines) |
| `lib/ui/screens/auth/registration_screen.dart` | split name fields, lookup wiring, match card |
| `lib/core/utils/validators.dart` | add `personName(String field)`, drop the now-unused `fullName()` |
| `lib/core/constants/strings.dart` | new labels, hint, revised NPI helper |
| `lib/state/auth_state.dart` | `completeRegistration()` saves city/state via `PATCH /users/me` |
| `lib/state/auth_state.dart` | `completeRegistration()` signature follows |
| `test/npi_lookup_test.dart` | **new** — 23 parsing/request tests |
| `test/widgets/npi_prefill_test.dart` | **new** — 16 screen tests |

Seven files, one of them new production code. No new dependency — `dio` is
already in the tree and `ApiClient` already wraps it.

### The service

```dart
// lib/data/services/npi_lookup.dart
class NpiMatch {
  final String npi, displayName, taxonomy;
  final String? credential, addressLine, city, state;
  ...
  factory NpiMatch.fromResult(Map<String, dynamic> r);
}

enum NpiLookupOutcome { matched, ambiguous, none }

class NpiLookupResult {
  final NpiLookupOutcome outcome;
  final NpiMatch? match;   // non-null iff matched
}

class NpiLookup {
  final Dio _dio;                                    // bare Dio, not ApiClient
  final _cache = <String, NpiLookupResult>{};        // ponytail: session-only

  Future<NpiLookupResult> byName(String first, String last);
  Future<NpiLookupResult> byNumber(String npi);
}
```

A **bare `Dio`**, not `ApiClient` — `ApiClient` carries our base URL, our bearer
token and our 401-refresh interceptor, none of which belong on a request to a
third party. Do not attach a Doqto access token to `npiregistry.cms.hhs.gov`.

Provided via a plain Riverpod `Provider` in `core/di`, so the test can override
it with a fake.

### Backend

No change needed. `POST /auth/register` accepts only `full_name`,
`specialty` and `npi_number` and silently ignores extra fields, so the practice
city/state are saved with `PATCH /users/me` straight after registering
(best-effort — see `docs/phone-verification.md`).

### Test

`test/npi_lookup_test.dart` (23) drives the service against the captured
`VIMAL NANAVATI` payload and a fake `HttpClientAdapter`: LOCATION-over-MAILING,
`practiceLocations` ignored, primary-taxonomy fallbacks, missing credential /
taxonomy / address, ZIP+4 and title-case edge cases, the `Errors` payload, a
maintenance-page body, the exact query parameters, memoisation, and the two
failure modes.

`test/widgets/npi_prefill_test.dart` (16) drives the screen with a fake
`NpiLookup`: unique → prefill + card, ambiguous → hint and nothing filled,
ambiguous-then-NPI → prefill, partial NPI ignored, throwing lookup silent and
non-blocking, city/state saved through the profile endpoint, user-typed specialty and NPI
survive, "Not me" clears everything, dedupe vs. deliberate retry, no query
while moving between name fields, one-letter names rejected before any query,
and both `CLAUDE.md` keyboard rules on the new fields.

Verified green: `flutter analyze lib test` clean, `flutter test` 143 passed,
and a real iPhone simulator run against the live CMS registry.

---

## Open decisions

**1. Direct-from-app vs. backend proxy.** This spec calls CMS directly from
Flutter: zero backend work, zero terraform, zero deploy coupling, and each
device uses its own IP so there is no shared rate-limit to exhaust. The cost is
no server-side caching and no analytics on lookup hit rate.

Move it behind `GET /api/v1/npi/lookup` when — and only when — one of these is
actually true: we want to *verify* NPI at registration (a trust boundary, which
must be server-side), CMS starts rate-limiting us, or we want to cache
registry data across users. Until then the proxy is a hop that buys nothing.

**2. Should a confirmed match lock the NPI field?** Currently no — everything
stays editable. Locking is one line if product wants it, but it makes a
correct-looking screen unfixable when the registry is wrong or stale.
