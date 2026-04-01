# CLAUDE.md

## 1. Project snapshot
- Name: `birdle` (Flutter frontend for GPS attendance + admin web).
- Stack: Flutter Material 3, `http`, `flutter_map`, `latlong2`, `shared_preferences`, `geolocator`, `intl`, `universal_html`.
- Backend: FastAPI (separate repo at `E:\CongtyGPIT\chamcongapp`), accessed via `API_BASE_URL`.
- Current routing: **Navigator (onGenerateRoute)** in `lib/main.dart` (not go_router).

## 2. Run locally
```bash
flutter pub get
flutter run -d chrome --web-port=62601 --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=GEOAPIFY_API_KEY=YOUR_KEY
```

Optional defines (from `lib/core/config/app_config.dart`):
- `API_BASE_URL` (default `http://127.0.0.1:8000`)
- `RECAPTCHA_SITE_KEY`
- `GEOAPIFY_API_KEY`
- `GEOAPIFY_MAP_STYLE`
- `DEFAULT_MAP_CENTER` (`lat,lng`)

## 3. Core architecture
- Config: `lib/core/config/app_config.dart`
- Theme tokens: `lib/core/theme/app_colors.dart`
- Storage:
  - `lib/core/storage/token_storage.dart`
  - `lib/core/storage/session_storage*.dart`
- Download helpers:
  - `lib/core/download/file_downloader*.dart`

No Riverpod/Bloc/Provider package in `pubspec.yaml`.
State is currently managed via `StatefulWidget` + local state + API classes.

## 4. Routing map (main.dart)
- `/login`
- `/forgot-password`
- `/reset-password`
- `/admin` (dashboard)
- `/admin/attendance`
- `/admin/employees`
- `/admin/groups`
- `/admin/geofences`
- `/admin/reports`
- `/admin/exceptions`
- `/admin/settings`
- `/home` (employee check-in/out)

## 5. Frontend structure
```
lib/
├── main.dart                          # Entry point, Navigator routing
├── core/
│   ├── config/app_config.dart         # API_BASE_URL, API keys
│   ├── theme/app_colors.dart          # Material 3 color tokens
│   ├── storage/token_storage.dart     # JWT token persistence (shared_preferences)
│   └── download/file_downloader.dart  # Excel/file download helper
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_api.dart          # Login, register, refresh
│   │   │   ├── password_reset_api.dart
│   │   │   └── recaptcha_client.dart  # Web/stub conditional import
│   │   └── presentation/
│   │       ├── login_page.dart
│   │       ├── register_page.dart
│   │       ├── forgot_password_page.dart
│   │       └── reset_password_page.dart
│   ├── attendance/
│   │   └── data/attendance_api.dart   # Check-in/out, status, logs
│   ├── home/
│   │   └── presentation/home_page.dart  # Main check-in/out UI with map
│   ├── location/
│   │   └── data/geoapify_client.dart  # Reverse geocoding
│   └── admin/
│       ├── data/admin_api.dart        # ALL admin API calls (~1800 lines)
│       └── presentation/
│           ├── admin_page.dart        # Main admin container (~5000 lines, uses `part`)
│           ├── admin_shell.dart       # Shell layout wrapper
│           ├── dashboard/             # Dashboard screen
│           ├── employees/             # Employee CRUD
│           ├── groups/                # Group/shift management
│           ├── geofences/             # Geofence map editor
│           ├── attendance_logs/       # Attendance log viewer
│           └── reports/               # Charts and reports
├── screens/admin/
│   ├── exceptions/                    # Exception review workflow
│   └── settings/                      # System settings
└── widgets/common/
    ├── admin_sidebar.dart
    ├── admin_topbar.dart
    ├── kpi_card.dart
    └── status_badge.dart
```

## 6. API usage pattern
- HTTP client: `package:http/http.dart`.
- Auth header: `Authorization: Bearer <token>`, `Content-Type: application/json`.
- Token source: `TokenStorage.getToken()`.
- Admin endpoints centralized in `lib/features/admin/data/admin_api.dart`.
- Response parsing: `_extractPayloadMap()` handles `{success, data}` wrapper + flat responses.

## 7. UI/UX conventions
- Prefer `AppColors` tokens; avoid hardcoded colors.
- Vietnamese labels across admin UI.
- Time format: 24h.
- Keep existing route names and navigation flow.
- Extend existing files/components before creating new abstractions.

## 8. Safety rules when editing
- Do not change auth/token persistence behavior unless explicitly requested.
- Do not rewrite route architecture unless explicitly requested.
- Keep API field names compatible with backend response mapping in `admin_api.dart` and `attendance_api.dart`.
- Avoid large refactors in one patch; prefer small, reviewable edits.
- `admin_page.dart` uses `part` directives for sub-widgets; keep this pattern.

## 9. Quick quality checks
```bash
flutter analyze
flutter test
flutter build web
```

---

# BACKEND ARCHITECTURE (FastAPI - E:\CongtyGPIT\chamcongapp)

## Tech stack
- **Framework**: FastAPI 0.135.1 + Starlette + Uvicorn
- **ORM**: SQLAlchemy 2.0.48
- **Migrations**: Alembic 1.18.4
- **Auth**: JWT (PyJWT) + bcrypt
- **DB**: PostgreSQL (psycopg2-binary) / SQLite for dev
- **Excel export**: openpyxl
- **Data validation**: Pydantic 2.12.5
- **Timezone**: Vietnam (UTC+7), all timestamps stored in UTC

## Backend structure
```
app/
├── main.py                    # FastAPI app, CORS, routers, error handlers
├── models.py                  # SQLAlchemy models (9 tables)
├── core/
│   ├── config.py              # Settings from .env (pydantic-settings)
│   ├── db.py                  # Engine, SessionLocal, Base
│   ├── deps.py                # get_current_user, require_admin
│   ├── security.py            # JWT create/decode, password hash
│   └── policy.py              # Policy constants
├── api/
│   ├── auth.py                # /auth/* (login, register, refresh, forgot/reset password)
│   ├── attendance.py          # /attendance/* (status, checkin, checkout, logs, exceptions approve/reject)
│   ├── employees.py           # /employees/* (CRUD, assign user/group)
│   ├── groups.py              # /groups/* (CRUD, geofences per group)
│   ├── geofences.py           # /geofence/list (flat geofence list for dashboard)
│   ├── reports.py             # /reports/* (dashboard, attendance-logs, weekly-trends, exceptions, export-excel, attendance.xlsx)
│   ├── rules.py               # /rules/* (checkin rule config)
│   └── users.py               # /users (list users for admin assignment)
├── schemas/
│   ├── attendance.py          # Request/response models
│   ├── auth.py
│   ├── employees.py
│   ├── groups.py
│   └── rules.py
└── services/
    ├── attendance_time.py     # Work date calculation, punctuality classification, overtime
    ├── geo.py                 # Haversine distance
    ├── location_risk.py       # GPS spoof detection (risk score 0-100)
    ├── report_consistency.py  # Distance consistency warnings
    └── auth/
        ├── password_reset_service.py
        └── recaptcha_service.py
```

## Database tables (models.py)

| Table | Key columns | Constraints |
|---|---|---|
| `users` | id, email (UNIQUE), password_hash, role (USER/ADMIN) | |
| `employees` | id, code (UNIQUE), full_name, user_id (FK, UNIQUE nullable), group_id (FK) | 1 user = max 1 employee |
| `groups` | id, code (UNIQUE), name, start_time, grace_minutes, end_time, checkout_grace_minutes, cross_day_cutoff_minutes, active | Optional time rule override |
| `group_geofences` | id, group_id (FK), name, latitude, longitude, radius_m (default 200), active | Multiple per group |
| `checkin_rules` | id, latitude, longitude, radius_m, start_time (08:00), grace_minutes (30), end_time (17:30), checkout_grace_minutes (0), cross_day_cutoff_minutes (240), active | System-wide fallback |
| `attendance_logs` | id, employee_id (FK), type (IN/OUT), time (UTC), work_date, lat, lng, distance_m, is_out_of_range, punctuality_status, checkout_status, matched_geofence_name, geofence_source, risk_score/level/flags, snapshot_* | **UNIQUE(employee_id, work_date, type)** |
| `attendance_exceptions` | id, employee_id (FK), source_checkin_log_id (FK, UNIQUE), exception_type, work_date, status (OPEN/RESOLVED), resolved_by/at/note | One exception per checkin |
| `refresh_tokens` | id, user_id, jti (UNIQUE), token_hash, remember_me, expires_at, revoked_at | Token rotation |
| `password_reset_tokens` | id, user_id, token_hash (UNIQUE), expires_at, used_at | One-time use |

## API endpoints

### Auth `/auth`
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | /auth/register | - | Create account |
| POST | /auth/login | - | Login with reCAPTCHA |
| POST | /auth/refresh | - | Refresh access token |
| POST | /auth/logout | User | Revoke refresh token |
| POST | /auth/logout-all | User | Revoke all refresh tokens |
| GET | /auth/me | User | Current user info |
| POST | /auth/forgot-password | - | Send reset email |
| POST | /auth/reset-password | - | Reset with token |

### Attendance `/attendance`
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | /attendance/status | User | Session state (IN/OUT, can_checkin/can_checkout) |
| POST | /attendance/checkin | User | Check-in with GPS (lat, lng, accuracy_m) |
| POST | /attendance/checkout | User | Check-out with GPS |
| GET | /attendance/me | User | User's own logs |
| GET | /attendance/report/daily | Admin | Daily summary by employee |
| GET | /attendance | Admin | Full attendance logs |
| PATCH | /attendance/exceptions/{id}/approve | Admin | Quick approve from dashboard |
| PATCH | /attendance/exceptions/{id}/reject | Admin | Quick reject/reopen from dashboard |

### Employees `/employees`
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | /employees | Admin | Create employee |
| GET | /employees | Admin | List with search, unassigned_only filter |
| GET | /employees/me | User | Own employee profile |
| GET | /employees/{id} | Admin | Employee detail |
| PUT | /employees/{id}/assign-user | Admin | Link employee to user account |
| PUT | /employees/{id}/assign-group | Admin | Assign to shift group |
| DELETE | /employees/{id} | Admin | Delete employee |

### Groups `/groups`
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | /groups | Admin | Create group |
| GET | /groups | Admin | List all groups |
| PUT | /groups/{id} | Admin | Update group |
| DELETE | /groups/{id} | Admin | Delete group |
| POST | /groups/{id}/geofences | Admin | Add geofence to group |
| GET | /groups/{id}/geofences | Admin | List group geofences |
| PUT | /groups/{id}/geofences/{gid} | Admin | Update geofence |
| DELETE | /groups/{id}/geofences/{gid} | Admin | Delete geofence |

### Geofence `/geofence`
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | /geofence/list | Admin | Flat list of all geofences across groups |

### Reports `/reports`
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | /reports/dashboard?date= | Admin | KPI summary (total, checked_in, late, out_of_range, geofences) |
| GET | /reports/attendance-logs?date= | Admin | Table data for dashboard |
| GET | /reports/weekly-trends?date= | Admin | 7-day trend chart (on_time, late, out_of_range) |
| GET | /reports/exceptions?status= | Admin | Dashboard exception sidebar |
| GET | /reports/attendance.xlsx | Admin | Excel export (GET with query params) |
| POST | /reports/export-excel | Admin | Excel export (POST with JSON body, used by Flutter) |
| GET | /reports/attendance-exceptions | Admin | Full exception list with details |
| PATCH | /reports/attendance-exceptions/{id}/resolve | Admin | Resolve exception |
| PATCH | /reports/attendance-exceptions/{id}/reopen | Admin | Reopen exception |

### Rules `/rules`
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | /rules/active | Public | Current active checkin rule |
| PUT | /rules/active | Admin | Update active rule |

## Key business logic

### Work date calculation
- Vietnam timezone (UTC+7)
- `cross_day_cutoff_minutes` (default 240 = 04:00 VN): night shifts span calendar days
- Check-in at 22:00 = work_date today; check-in at 02:00 = work_date yesterday

### Punctuality classification
- **Check-in**: EARLY (before start_time), ON_TIME (within grace), LATE (after grace)
- **Check-out**: EARLY (before end_time), ON_TIME (within grace), LATE (after grace), SYSTEM_AUTO (auto-closed)

### Geofence matching hierarchy
1. Employee group active + has geofences -> GROUP
2. Group inactive or no geofences -> SYSTEM_FALLBACK
3. No group assigned -> SYSTEM_FALLBACK

### Location risk assessment (anti-GPS-spoof)
- Exact coordinate reuse detection
- Impossible travel speed check
- Accuracy anomaly detection
- Risk score 0-100, levels: LOW/MEDIUM/HIGH/CRITICAL
- Decisions: ALLOW, ALLOW_WITH_EXCEPTION, BLOCK

### Auto-close & missed checkout
- **Auto-close**: open session past work_date cutoff -> system OUT log + AUTO_CLOSED exception
- **Missed checkout**: past (end_time + checkout_grace) with no OUT -> MISSED_CHECKOUT exception
- **Exception precedence**: AUTO_CLOSED > MISSED_CHECKOUT > SUSPECTED_LOCATION_SPOOF

### Rule snapshot
- Current time rule frozen at check-in time (snapshot_start_time, snapshot_end_time, etc.)
- Payroll calculations use snapshot, not current rule

## Running backend
```bash
cd E:\CongtyGPIT\chamcongapp
pip install -r requirements.txt
alembic upgrade head
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## API response format
```json
// Success (some endpoints wrap in {success, data}, others return flat)
{"success": true, "data": {...}}
// or flat:
[{...}, {...}]

// Error
{"success": false, "error": {"code": "ERROR_CODE", "message": "..."}}
```

---

# IMPORTANT PATTERNS & CONSTRAINTS

## Database constraints
1. **UNIQUE(employee_id, work_date, type)** in attendance_logs - one IN + one OUT per day
2. **UNIQUE(source_checkin_log_id)** in attendance_exceptions - one exception per checkin
3. **employee.user_id** is UNIQUE nullable - one user = max one employee

## Business rules
1. Cannot check-in if: no employee, open session exists, already checked in for work_date, risk BLOCK
2. Cannot check-out if: no open session, session auto-closed
3. Exception types: AUTO_CLOSED, MISSED_CHECKOUT, SUSPECTED_LOCATION_SPOOF

## Frontend-backend field mapping (admin_api.dart)
- Dashboard summary: wraps in `{success, data}`, extracted by `_extractPayloadMap()`
- Attendance logs: returns flat array, parsed by `_parseJsonListAny()`
- location_status: `"inside"` / `"outside"` (lowercase)
- attendance_status / status: `"on_time"`, `"late"`, `"early"`, `"complete"`, `"absent"`, `"missed_checkout"`, `"pending_timesheet"` (lowercase)
