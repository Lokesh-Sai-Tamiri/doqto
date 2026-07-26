"""Seed a demo directory: real-world health systems staffed with generated doctors.

    python -m scripts.seed_demo                 # 100 orgs, 1000 doctors
    python -m scripts.seed_demo --orgs 20 --doctors 200
    python -m scripts.seed_demo --purge         # remove a previous seed first

Organization names are real US health systems and hospitals (public entities).
Doctor names are GENERATED — attaching invented profiles, phone numbers and NPIs
to real physicians' names would be fabricating records about real people.

Phones use the NANP fictional range NPA-555-0100..0199 under real area codes,
because that is the only block that is both reserved for fiction and *valid* —
libphonenumber (which the app validates with) rejects 555-000-XXXX outright.
That caps each area code at 100 numbers, hence the list of ten.

Seeded rows are tagged by NPIs starting '99' and org invite codes ending
'·9###', so --purge removes exactly the seed and nothing you created by hand.
"""
from __future__ import annotations

import argparse
import asyncio
import random
import string
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import delete, func, select, text  # noqa: E402

from app.core.enums import OrgRole, OrgStatus, UserRole  # noqa: E402
from app.db.postgres import SessionLocal  # noqa: E402
from app.models import Organization, OrgMember, User  # noqa: E402

# Seed marker — every generated row carries it, nothing else does.
SEED_NPI_PREFIX = "99"

# Real area codes × the reserved 555-0100..0199 fictional block = 1000 numbers
# that libphonenumber accepts as valid US numbers.
SEED_AREA_CODES = ["212", "213", "312", "415", "617", "305", "202", "206", "404", "713"]
SEED_NUMBERS_PER_AREA = 100


def _seed_phone(index: int) -> str:
    """index 0..999 → +1{area}555{0100+n}. Raises past the usable range rather
    than silently colliding."""
    area, n = divmod(index, SEED_NUMBERS_PER_AREA)
    if area >= len(SEED_AREA_CODES):
        raise SystemExit(
            f"seed supports at most {len(SEED_AREA_CODES) * SEED_NUMBERS_PER_AREA} "
            "doctors — add more area codes to SEED_AREA_CODES"
        )
    return f"+1{SEED_AREA_CODES[area]}555{100 + n:04d}"

# --------------------------------------------------------------------------- #
# Real US health systems / hospitals (name, city, state)
# --------------------------------------------------------------------------- #
REAL_SYSTEMS: list[tuple[str, str, str]] = [
    ("Mayo Clinic", "Rochester", "MN"),
    ("Cleveland Clinic", "Cleveland", "OH"),
    ("Johns Hopkins Hospital", "Baltimore", "MD"),
    ("Massachusetts General Hospital", "Boston", "MA"),
    ("Brigham and Women's Hospital", "Boston", "MA"),
    ("UCSF Medical Center", "San Francisco", "CA"),
    ("Cedars-Sinai Medical Center", "Los Angeles", "CA"),
    ("NewYork-Presbyterian Hospital", "New York", "NY"),
    ("Mount Sinai Hospital", "New York", "NY"),
    ("NYU Langone Health", "New York", "NY"),
    ("Northwestern Memorial Hospital", "Chicago", "IL"),
    ("Rush University Medical Center", "Chicago", "IL"),
    ("University of Chicago Medical Center", "Chicago", "IL"),
    ("Stanford Health Care", "Palo Alto", "CA"),
    ("UCLA Medical Center", "Los Angeles", "CA"),
    ("Houston Methodist Hospital", "Houston", "TX"),
    ("MD Anderson Cancer Center", "Houston", "TX"),
    ("UT Southwestern Medical Center", "Dallas", "TX"),
    ("Baylor University Medical Center", "Dallas", "TX"),
    ("Emory University Hospital", "Atlanta", "GA"),
    ("Duke University Hospital", "Durham", "NC"),
    ("UNC Medical Center", "Chapel Hill", "NC"),
    ("Vanderbilt University Medical Center", "Nashville", "TN"),
    ("Barnes-Jewish Hospital", "St. Louis", "MO"),
    ("University of Michigan Health", "Ann Arbor", "MI"),
    ("Henry Ford Hospital", "Detroit", "MI"),
    ("Hospital of the University of Pennsylvania", "Philadelphia", "PA"),
    ("Thomas Jefferson University Hospital", "Philadelphia", "PA"),
    ("UPMC Presbyterian", "Pittsburgh", "PA"),
    ("Yale New Haven Hospital", "New Haven", "CT"),
    ("Hartford Hospital", "Hartford", "CT"),
    ("Tufts Medical Center", "Boston", "MA"),
    ("Beth Israel Deaconess Medical Center", "Boston", "MA"),
    ("Rhode Island Hospital", "Providence", "RI"),
    ("Dartmouth Hitchcock Medical Center", "Lebanon", "NH"),
    ("Maine Medical Center", "Portland", "ME"),
    ("University of Vermont Medical Center", "Burlington", "VT"),
    ("Albany Medical Center", "Albany", "NY"),
    ("Strong Memorial Hospital", "Rochester", "NY"),
    ("Roswell Park Comprehensive Cancer Center", "Buffalo", "NY"),
    ("MedStar Washington Hospital Center", "Washington", "DC"),
    ("Inova Fairfax Hospital", "Falls Church", "VA"),
    ("UVA Health University Hospital", "Charlottesville", "VA"),
    ("VCU Medical Center", "Richmond", "VA"),
    ("West Virginia University Hospital", "Morgantown", "WV"),
    ("Ohio State University Wexner Medical Center", "Columbus", "OH"),
    ("Cincinnati Children's Hospital", "Cincinnati", "OH"),
    ("Indiana University Health", "Indianapolis", "IN"),
    ("Froedtert Hospital", "Milwaukee", "WI"),
    ("University of Wisconsin Hospital", "Madison", "WI"),
    ("Mayo Clinic Health System", "Eau Claire", "WI"),
    ("Abbott Northwestern Hospital", "Minneapolis", "MN"),
    ("University of Iowa Hospitals", "Iowa City", "IA"),
    ("Nebraska Medicine", "Omaha", "NE"),
    ("University of Kansas Hospital", "Kansas City", "KS"),
    ("Saint Luke's Hospital", "Kansas City", "MO"),
    ("Oklahoma University Medical Center", "Oklahoma City", "OK"),
    ("Arkansas Children's Hospital", "Little Rock", "AR"),
    ("Ochsner Medical Center", "New Orleans", "LA"),
    ("University of Mississippi Medical Center", "Jackson", "MS"),
    ("UAB Hospital", "Birmingham", "AL"),
    ("Tampa General Hospital", "Tampa", "FL"),
    ("Jackson Memorial Hospital", "Miami", "FL"),
    ("Mayo Clinic Florida", "Jacksonville", "FL"),
    ("AdventHealth Orlando", "Orlando", "FL"),
    ("Medical University of South Carolina", "Charleston", "SC"),
    ("Prisma Health Greenville Memorial", "Greenville", "SC"),
    ("Wake Forest Baptist Medical Center", "Winston-Salem", "NC"),
    ("Atrium Health Carolinas Medical Center", "Charlotte", "NC"),
    ("Denver Health Medical Center", "Denver", "CO"),
    ("UCHealth University of Colorado Hospital", "Aurora", "CO"),
    ("Intermountain Medical Center", "Murray", "UT"),
    ("University of Utah Hospital", "Salt Lake City", "UT"),
    ("St. Luke's Boise Medical Center", "Boise", "ID"),
    ("Providence St. Vincent Medical Center", "Portland", "OR"),
    ("Oregon Health & Science University Hospital", "Portland", "OR"),
    ("UW Medical Center", "Seattle", "WA"),
    ("Swedish Medical Center", "Seattle", "WA"),
    ("Virginia Mason Medical Center", "Seattle", "WA"),
    ("Banner University Medical Center", "Phoenix", "AZ"),
    ("Mayo Clinic Arizona", "Scottsdale", "AZ"),
    ("University of New Mexico Hospital", "Albuquerque", "NM"),
    ("Sunrise Hospital and Medical Center", "Las Vegas", "NV"),
    ("Renown Regional Medical Center", "Reno", "NV"),
    ("Scripps Green Hospital", "La Jolla", "CA"),
    ("UC San Diego Medical Center", "San Diego", "CA"),
    ("Sharp Memorial Hospital", "San Diego", "CA"),
    ("Hoag Memorial Hospital Presbyterian", "Newport Beach", "CA"),
    ("Keck Hospital of USC", "Los Angeles", "CA"),
    ("UC Davis Medical Center", "Sacramento", "CA"),
    ("UC Irvine Medical Center", "Orange", "CA"),
    ("Kaiser Permanente Oakland Medical Center", "Oakland", "CA"),
    ("Queen's Medical Center", "Honolulu", "HI"),
    ("Providence Alaska Medical Center", "Anchorage", "AK"),
    ("Billings Clinic", "Billings", "MT"),
    ("Sanford USD Medical Center", "Sioux Falls", "SD"),
    ("Sanford Medical Center Fargo", "Fargo", "ND"),
    ("Bryan Medical Center", "Lincoln", "NE"),
    ("Christiana Hospital", "Newark", "DE"),
    ("Hackensack University Medical Center", "Hackensack", "NJ"),
    ("Robert Wood Johnson University Hospital", "New Brunswick", "NJ"),
    ("Lehigh Valley Hospital", "Allentown", "PA"),
    ("Geisinger Medical Center", "Danville", "PA"),
    ("University of Kentucky Albert B. Chandler Hospital", "Lexington", "KY"),
    ("Norton Hospital", "Louisville", "KY"),
]

SPECIALTIES = [
    "Cardiology", "Internal Medicine", "Family Medicine", "Pediatrics",
    "Emergency Medicine", "Anesthesiology", "Radiology", "General Surgery",
    "Orthopedic Surgery", "Neurology", "Neurosurgery", "Oncology",
    "Dermatology", "Psychiatry", "Obstetrics & Gynecology", "Urology",
    "Gastroenterology", "Pulmonology", "Nephrology", "Endocrinology",
    "Rheumatology", "Infectious Disease", "Ophthalmology", "Otolaryngology",
    "Pathology", "Critical Care", "Geriatrics", "Hematology",
    "Plastic Surgery", "Vascular Surgery", "Sports Medicine", "Palliative Care",
]

FIRST_NAMES = [
    "Aaron", "Adam", "Adriana", "Aisha", "Alan", "Alejandro", "Alice", "Amara",
    "Amelia", "Amir", "Ana", "Andrew", "Angela", "Anita", "Anthony", "Arjun",
    "Ashley", "Aubrey", "Ava", "Benjamin", "Beatriz", "Bianca", "Blake",
    "Brandon", "Brianna", "Bruce", "Caleb", "Camila", "Carlos", "Caroline",
    "Catherine", "Cecilia", "Charles", "Chloe", "Christopher", "Claire",
    "Daniel", "Danielle", "David", "Deepak", "Diana", "Diego", "Dmitri",
    "Dominic", "Elena", "Eli", "Elizabeth", "Emily", "Emma", "Eric", "Esther",
    "Ethan", "Eva", "Fatima", "Felix", "Fiona", "Gabriel", "Grace", "Gregory",
    "Hannah", "Harold", "Hassan", "Heather", "Helen", "Henry", "Hugo", "Ian",
    "Imani", "Irene", "Isaac", "Isabella", "Jacob", "James", "Jasmine",
    "Jason", "Javier", "Jennifer", "Jessica", "Joel", "John", "Jonathan",
    "Jordan", "Joseph", "Joshua", "Julia", "Julian", "Karen", "Katherine",
    "Kevin", "Kiran", "Laura", "Leah", "Leo", "Liam", "Linda", "Lucas",
    "Lucia", "Maria", "Marcus", "Margaret", "Mark", "Martin", "Mateo",
    "Matthew", "Maya", "Megan", "Mei", "Michael", "Miguel", "Mohammed",
    "Monica", "Nadia", "Natalie", "Nathan", "Nicholas", "Nicole", "Noah",
    "Olivia", "Omar", "Oscar", "Patricia", "Patrick", "Paul", "Priya",
    "Rachel", "Rafael", "Rahul", "Rebecca", "Richard", "Robert", "Rosa",
    "Ruth", "Ryan", "Samuel", "Sandra", "Sarah", "Sebastian", "Simon",
    "Sofia", "Stephanie", "Steven", "Susan", "Tanya", "Theodore", "Thomas",
    "Tobias", "Tyler", "Valeria", "Vanessa", "Victor", "Victoria", "Vikram",
    "Vincent", "William", "Xavier", "Yasmin", "Yuki", "Zachary", "Zoe",
]

LAST_NAMES = [
    "Abbott", "Acosta", "Adams", "Aguilar", "Ahmed", "Alexander", "Ali",
    "Allen", "Alvarez", "Andersen", "Anderson", "Bailey", "Baker", "Banks",
    "Barnes", "Bell", "Bennett", "Bishop", "Black", "Blake", "Bowman",
    "Boyd", "Bradley", "Brooks", "Brown", "Bryant", "Burke", "Burns",
    "Butler", "Byrne", "Caldwell", "Campbell", "Cardenas", "Carlson",
    "Carpenter", "Carter", "Castillo", "Chan", "Chandra", "Chang", "Chavez",
    "Chen", "Cho", "Clark", "Cohen", "Coleman", "Collins", "Cooper", "Cortez",
    "Cox", "Cruz", "Cunningham", "Curtis", "Dalton", "Daniels", "Davidson",
    "Davis", "Delgado", "Diaz", "Dixon", "Donnelly", "Douglas", "Doyle",
    "Duarte", "Dunn", "Edwards", "Ellis", "Erickson", "Espinoza", "Evans",
    "Farrell", "Fernandez", "Ferguson", "Fields", "Fischer", "Fisher",
    "Fitzgerald", "Fleming", "Flores", "Ford", "Foster", "Fox", "Franklin",
    "Freeman", "Fuentes", "Gallagher", "Garcia", "Gardner", "Garrett",
    "George", "Gibson", "Gill", "Gomez", "Gonzalez", "Goodwin", "Gordon",
    "Graham", "Grant", "Graves", "Gray", "Green", "Griffin", "Gupta",
    "Gutierrez", "Hall", "Hamilton", "Hansen", "Harper", "Harrington",
    "Harris", "Hart", "Hayes", "Henderson", "Hernandez", "Herrera", "Hicks",
    "Hill", "Ho", "Hoffman", "Holland", "Holmes", "Hopkins", "Howard",
    "Hughes", "Hunt", "Hussain", "Ibrahim", "Ingram", "Iyer", "Jackson",
    "Jacobs", "Jain", "James", "Jenkins", "Jensen", "Jimenez", "Johnson",
    "Jones", "Jordan", "Joseph", "Kaplan", "Karim", "Kaur", "Keller", "Kelly",
    "Kennedy", "Khan", "Kim", "King", "Klein", "Knight", "Kumar", "Lam",
    "Lambert", "Lane", "Larson", "Lawrence", "Le", "Lee", "Leon", "Levine",
    "Lewis", "Li", "Lin", "Lindqvist", "Little", "Liu", "Lopez", "Lowe",
    "Lucas", "Lynch", "Mack", "Maddox", "Mahmoud", "Malik", "Mann", "Marsh",
    "Marshall", "Martin", "Martinez", "Mason", "Mathews", "Matsuda",
    "Maxwell", "McCarthy", "McDonald", "McGrath", "McKinney", "Medina",
    "Mehta", "Mendez", "Mercado", "Meyer", "Miller", "Mills", "Mitchell",
    "Molina", "Montgomery", "Moore", "Morales", "Moreno", "Morgan", "Morris",
    "Morrison", "Moss", "Murphy", "Murray", "Myers", "Nakamura", "Nash",
    "Navarro", "Neal", "Nelson", "Newman", "Nguyen", "Nichols", "Nielsen",
    "Norris", "Novak", "O'Brien", "O'Connor", "Ochoa", "Oliver", "Olsen",
    "Ortega", "Ortiz", "Osborne", "Owens", "Padilla", "Page", "Palmer",
    "Park", "Parker", "Patel", "Patterson", "Paulson", "Payne", "Pearson",
    "Pena", "Perez", "Perry", "Peters", "Petersen", "Phillips", "Pierce",
    "Ponce", "Porter", "Powell", "Powers", "Preston", "Price", "Quinn",
    "Ramirez", "Ramos", "Rao", "Ray", "Reed", "Reese", "Reeves", "Reid",
    "Reyes", "Reynolds", "Rhodes", "Rice", "Richards", "Richardson", "Riley",
    "Rivera", "Roberts", "Robinson", "Rodriguez", "Rogers", "Rojas", "Roman",
    "Romero", "Rose", "Ross", "Rossi", "Roy", "Ruiz", "Russell", "Ryan",
    "Salazar", "Sanchez", "Sanders", "Santiago", "Santos", "Sato", "Saunders",
    "Schmidt", "Schneider", "Schultz", "Schwartz", "Scott", "Sharma", "Shaw",
    "Shea", "Shepherd", "Sheridan", "Sherman", "Silva", "Simmons", "Simon",
    "Singh", "Sinclair", "Sloan", "Smith", "Snyder", "Solis", "Soto",
    "Sparks", "Spencer", "Stanley", "Stein", "Stephens", "Stevens", "Stewart",
    "Stokes", "Stone", "Strickland", "Suarez", "Sullivan", "Sutton", "Suzuki",
    "Swanson", "Sweeney", "Tanaka", "Tate", "Taylor", "Terry", "Thomas",
    "Thompson", "Thornton", "Todd", "Torres", "Tran", "Travis", "Tucker",
    "Turner", "Underwood", "Valdez", "Valencia", "Vance", "Vargas", "Vasquez",
    "Vaughn", "Vega", "Velazquez", "Vernon", "Villanueva", "Wade", "Wagner",
    "Walker", "Wallace", "Walsh", "Walter", "Wang", "Ward", "Warner",
    "Warren", "Washington", "Watkins", "Watson", "Watts", "Weaver", "Webb",
    "Weber", "Webster", "Weiss", "Welch", "Wells", "West", "Whalen",
    "Wheeler", "White", "Whitfield", "Wilkins", "Williams", "Willis",
    "Wilson", "Winters", "Wolfe", "Wong", "Wood", "Woods", "Wright", "Wu",
    "Yamamoto", "Yang", "Yates", "Yoon", "Young", "Yousef", "Zhang", "Zhao",
    "Zimmerman", "Zuniga",
]

SKILL_POOL = [
    "Echocardiography", "Point-of-care Ultrasound", "Endoscopy", "Colonoscopy",
    "Robotic Surgery", "Laparoscopy", "Interventional Radiology", "MRI",
    "CT Interpretation", "Airway Management", "Regional Anesthesia",
    "Wound Care", "Telemedicine", "Clinical Research", "Medical Education",
    "Quality Improvement", "Infection Control", "Transplant Medicine",
    "Neonatal Resuscitation", "Trauma Resuscitation", "Pain Management",
    "Genetic Counseling", "Health Informatics", "Antimicrobial Stewardship",
]

CLINIC_PATTERNS = [
    "{city} {specialty} Associates",
    "{city} {specialty} Group",
    "{city} Regional Medical Center",
    "{city} Community Hospital",
    "{city} Family Health Center",
]


def _invite_code(rng: random.Random) -> str:
    """Same shape as OrgService's codes, but the digits always start with 9 so
    a seeded org is identifiable (and can be purged) later."""
    letters = "".join(rng.choice(string.ascii_uppercase) for _ in range(4))
    digits = "9" + "".join(rng.choice(string.digits) for _ in range(3))
    return f"{letters}·{digits}"


def _org_specs(count: int, rng: random.Random) -> list[tuple[str, str, str]]:
    """Real systems first; top up with plausible clinics if more are asked for."""
    specs = list(REAL_SYSTEMS[:count])
    while len(specs) < count:
        city, state = rng.choice(REAL_SYSTEMS)[1:]
        name = rng.choice(CLINIC_PATTERNS).format(
            city=city, specialty=rng.choice(SPECIALTIES)
        )
        specs.append((name, city, state))
    return specs


# Most references to `users` are ON DELETE NO ACTION on purpose — an audit
# trail, a message and a conversation all outlive the account. Removing demo
# accounts therefore means clearing their dependents by hand, in order.
_SEEDED = "SELECT id FROM users WHERE npi_number LIKE '99%'"
_PURGE_SQL = [
    # Anything owned by a demo doctor goes with them.
    f"DELETE FROM message_receipts WHERE user_id IN ({_SEEDED})",
    f"DELETE FROM messages WHERE sender_id IN ({_SEEDED})",
    f"DELETE FROM conversation_members WHERE user_id IN ({_SEEDED})",
    f"DELETE FROM conversations WHERE created_by IN ({_SEEDED})",
    f"DELETE FROM groups WHERE owner_id IN ({_SEEDED})",
    f"DELETE FROM group_invites WHERE inviter_id IN ({_SEEDED}) "
    f"OR invitee_id IN ({_SEEDED})",
    f"DELETE FROM connection_invitations WHERE sender_id IN ({_SEEDED}) "
    f"OR recipient_id IN ({_SEEDED})",
    f"DELETE FROM connection_removals WHERE removed_by IN ({_SEEDED})",
    f"DELETE FROM blocks WHERE blocker_id IN ({_SEEDED}) OR blocked_id IN ({_SEEDED})",
    f"DELETE FROM mutes WHERE user_id IN ({_SEEDED}) OR muted_user_id IN ({_SEEDED})",
    f"DELETE FROM reports WHERE reporter_id IN ({_SEEDED})",
    f"DELETE FROM audit_logs WHERE user_id IN ({_SEEDED})",
    # Nullable back-references: keep the row, forget the demo actor.
    f"UPDATE conversations SET initiator_id = NULL WHERE initiator_id IN ({_SEEDED})",
    f"UPDATE group_members SET invited_by = NULL WHERE invited_by IN ({_SEEDED})",
    f"UPDATE notifications SET actor_id = NULL WHERE actor_id IN ({_SEEDED})",
    f"UPDATE organizations SET verified_by = NULL WHERE verified_by IN ({_SEEDED})",
]


async def purge(db) -> tuple[int, int]:
    """Delete only seeded rows, dependents first."""
    users = await db.scalar(
        select(func.count()).select_from(User).where(User.npi_number.like(f"{SEED_NPI_PREFIX}%"))
    )
    orgs = await db.scalar(
        select(func.count())
        .select_from(Organization)
        .where(Organization.invite_code.like("____·9%"))
    )
    for statement in _PURGE_SQL:
        await db.execute(text(statement))
    await db.execute(delete(User).where(User.npi_number.like(f"{SEED_NPI_PREFIX}%")))
    await db.execute(delete(Organization).where(Organization.invite_code.like("____·9%")))
    await db.commit()
    return orgs or 0, users or 0


async def seed(org_count: int, doctor_count: int, rng: random.Random) -> None:
    now = datetime.now(timezone.utc)
    async with SessionLocal() as db:
        # Keep phone/NPI unique against anything already in the table.
        taken_phones = set((await db.scalars(select(User.phone))).all())
        taken_npis = set((await db.scalars(select(User.npi_number))).all())
        taken_codes = set((await db.scalars(select(Organization.invite_code))).all())

        orgs: list[Organization] = []
        for name, city, state in _org_specs(org_count, rng):
            code = _invite_code(rng)
            while code in taken_codes:
                code = _invite_code(rng)
            taken_codes.add(code)
            orgs.append(
                Organization(
                    name=name,
                    city=city,
                    state=state,
                    invite_code=code,
                    # Verified so the directory is usable straight away.
                    status=OrgStatus.ACTIVE,
                    verified_at=now,
                )
            )
        db.add_all(orgs)
        await db.flush()

        # Every org gets at least one doctor; the rest land at random.
        assignments = list(range(org_count)) + [
            rng.randrange(org_count) for _ in range(max(0, doctor_count - org_count))
        ]
        rng.shuffle(assignments)

        seq = 0
        users: list[User] = []
        members: list[OrgMember] = []
        seen_admin: set[int] = set()
        for org_index in assignments[:doctor_count]:
            org = orgs[org_index]
            specialty = rng.choice(SPECIALTIES)
            name = f"Dr. {rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}"

            while True:
                phone = _seed_phone(seq)
                npi = f"{SEED_NPI_PREFIX}{seq:08d}"
                seq += 1
                if phone not in taken_phones and npi not in taken_npis:
                    break
            taken_phones.add(phone)
            taken_npis.add(npi)

            years = rng.randint(1, 35)
            user = User(
                phone=phone,
                full_name=name,
                npi_number=npi,
                specialty=specialty,
                city=org.city,
                state=org.state,
                headline=f"{specialty} at {org.name}",
                bio=(
                    f"{specialty} physician at {org.name} with {years} years of "
                    "clinical practice."
                ),
                years_of_experience=years,
                skills=rng.sample(SKILL_POOL, k=rng.randint(2, 5)),
                role=UserRole.DOCTOR,
            )
            users.append(user)
            # First doctor placed in an org runs it.
            is_admin = org_index not in seen_admin
            seen_admin.add(org_index)
            members.append((user, org, OrgRole.ADMIN if is_admin else OrgRole.DOCTOR))

        db.add_all(users)
        await db.flush()
        db.add_all(
            [
                OrgMember(org_id=org.id, user_id=user.id, org_role=role)
                for user, org, role in members
            ]
        )
        await db.commit()

        print(f"seeded {len(orgs)} organizations, {len(users)} doctors")
        print(f"  login: any seeded phone ({users[0].phone} …) + dev OTP 777777")
        print(f"  sample org: {orgs[0].name} — invite code {orgs[0].invite_code}")


async def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--orgs", type=int, default=100)
    ap.add_argument("--doctors", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=7, help="RNG seed (reproducible runs)")
    ap.add_argument("--purge", action="store_true", help="remove a previous seed, then exit")
    args = ap.parse_args()

    if args.purge:
        async with SessionLocal() as db:
            orgs, users = await purge(db)
        print(f"purged {orgs} seeded organizations, {users} seeded doctors")
        return

    if args.doctors < args.orgs:
        raise SystemExit("--doctors must be >= --orgs so every organization has a member")

    await seed(args.orgs, args.doctors, random.Random(args.seed))


if __name__ == "__main__":
    asyncio.run(main())
