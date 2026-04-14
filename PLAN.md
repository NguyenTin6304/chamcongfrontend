# PLAN.md — Exception Deadline Policy Feature
# Cập nhật: 2026-04-14
# Branch: uat

---

## 1. Bối cảnh & Trạng thái hiện tại

### Hiện tại
- `AttendanceException` đã có cột `expires_at` (DATETIME) trong DB
- Expiry được set cứng `timedelta(days=3)` khi tạo exception tại `app/services/attendance_exception_workflow.py`
- Chưa có lazy expiry: status không tự chuyển `EXPIRED` khi hết hạn
- Chưa có cấu hình: admin không thể đổi deadline
- Chưa có extend deadline: không ai có thể gia hạn cá nhân
- Chưa có blocking: employee vẫn có thể submit sau `expires_at`
- Endpoint: `POST /reports/attendance-exceptions/{id}/submit-explanation`

### Mục tiêu
Xây dựng hệ thống deadline chuyên nghiệp cho doanh nghiệp:
- Admin cấu hình deadline mặc định (days + hours, per exception type)
- Lazy expiry: tự động EXPIRED khi đọc quá hạn
- Admin gia hạn cá nhân từng exception
- Employee thấy countdown + bị block khi hết hạn
- Admin thấy badge màu theo mức độ khẩn cấp

---

## 2. Thiết kế Database

### 2a. Bảng `exception_policies` (singleton id=1)

```sql
CREATE TABLE exception_policies (
    id INTEGER PRIMARY KEY DEFAULT 1,
    -- Deadline mặc định (áp dụng cho tất cả exception types)
    default_deadline_hours INTEGER NOT NULL DEFAULT 72,   -- 3 ngày
    -- Override per type (NULL = dùng default)
    auto_closed_deadline_hours INTEGER,
    missed_checkout_deadline_hours INTEGER,
    location_risk_deadline_hours INTEGER,
    large_time_deviation_deadline_hours INTEGER,
    -- Grace period sau deadline (để admin vẫn có thể xem trước khi purge)
    grace_period_days INTEGER NOT NULL DEFAULT 30,
    -- Metadata
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_by_id INTEGER REFERENCES users(id)
);
```

### 2b. Thêm cột vào `attendance_exceptions`
```sql
-- Không cần thêm cột vì expires_at đã có sẵn
-- Chỉ cần thêm: extended_deadline_at (nullable) cho gia hạn cá nhân
ALTER TABLE attendance_exceptions ADD COLUMN extended_deadline_at TIMESTAMP;
```

**Effective deadline** = `extended_deadline_at ?? expires_at`

### 2c. Migration file
`alembic/versions/XXXX_exception_deadline_policy.py`

---

## 3. Backend API

### 3a. Singleton Policy Endpoints
```
GET  /rules/exception-policy          → ExceptionPolicyResponse
PATCH /rules/exception-policy         → ExceptionPolicyResponse (admin only)
```

**ExceptionPolicyResponse**:
```python
class ExceptionPolicyResponse(BaseModel):
    default_deadline_hours: int
    auto_closed_deadline_hours: int | None
    missed_checkout_deadline_hours: int | None
    location_risk_deadline_hours: int | None
    large_time_deviation_deadline_hours: int | None
    grace_period_days: int
    updated_at: datetime | None
    updated_by_name: str | None
```

### 3b. Extend Deadline Endpoint
```
PATCH /reports/attendance-exceptions/{id}/extend-deadline
Body: { "extend_hours": int }        # 1–168 (max 1 tuần mỗi lần gia hạn)
Response: AttendanceExceptionResponse (updated exception)
```
Logic:
- Chỉ ADMIN
- Chỉ khi status là PENDING_EMPLOYEE hoặc đang EXPIRED (để hồi sinh)
- Tính từ **effective_deadline_now + extend_hours** (không phải từ thời điểm gọi API)
- Nếu đang EXPIRED → đổi status về PENDING_EMPLOYEE, clear expired flag

### 3c. Lazy Expiry Helper
```python
def _auto_expire_overdue(db: Session, exceptions: list[AttendanceException]) -> list[AttendanceException]:
    """
    Gọi sau mỗi query trả về exception list.
    Với mỗi exception PENDING_EMPLOYEE có effective_deadline < now():
      → status = EXPIRED, flush DB
    Trả về list sau khi đã update in-place.
    """
```

Áp dụng tại:
- `list_exceptions` (admin)
- `my_exceptions` (employee)
- `get_exception` (single)

### 3d. Block submit sau deadline
Trong `submit_explanation`:
```python
effective = emp_exception.extended_deadline_at or emp_exception.expires_at
if effective and datetime.now(timezone.utc) > effective:
    raise HTTPException(status_code=410, detail="Đã quá hạn giải trình")
```

### 3e. Batch expire endpoint (dùng cho admin trigger thủ công)
```
POST /reports/attendance-exceptions/batch-expire
Response: { "expired_count": int }
```

---

## 4. Tính Effective Deadline

```
Nếu policy có override cho type → dùng override_hours
Còn lại → dùng default_deadline_hours

created_at + policy_hours = expires_at (set lúc tạo)
extended_deadline_at = NULL (mặc định)

effective_deadline = extended_deadline_at ?? expires_at

Trạng thái hạn:
  effective_deadline - now > 48h  → GREEN  (còn nhiều thời gian)
  24h < remaining ≤ 48h           → YELLOW (sắp hết hạn)
  0 < remaining ≤ 24h             → RED    (khẩn cấp)
  remaining ≤ 0                   → GREY   (đã hết hạn / EXPIRED)
```

---

## 5. Flutter Frontend

### 5a. Settings Screen — Tab "Chính sách giải trình"

Vị trí: `lib/features/admin/presentation/settings/settings_screen.dart`
Hiện có các tab (xem file). Thêm tab mới: `_TabIndex.explanationPolicy`.

UI Layout:
```
┌─────────────────────────────────────────────────────┐
│  Chính sách giải trình                              │
│                                                     │
│  Deadline mặc định                                  │
│  [  72  ] giờ  (≈ 3 ngày)                          │
│                                                     │
│  Override theo loại ngoại lệ                        │
│  ┌─────────────────────────────────────────────┐   │
│  │ Đóng ngoài giờ          [____] giờ (trống = dùng mặc định) │
│  │ Quên checkout           [____] giờ                │
│  │ Rủi ro vị trí           [____] giờ                │
│  │ Lệch giờ lớn            [____] giờ                │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  Grace period (giữ hồ sơ sau khi EXPIRED)          │
│  [  30  ] ngày                                     │
│                                                     │
│  Cập nhật lần cuối: 14/04/2026 10:30 bởi Admin     │
│                                                     │
│  [      Lưu cài đặt      ]                         │
└─────────────────────────────────────────────────────┘
```

### 5b. Admin Exceptions Tab — Thêm cột Deadline

Trong `exceptions_screen.dart` + widgets:
- Thêm cột "Hạn giải trình" (chỉ hiện với PENDING_EMPLOYEE)
- Badge màu: GREEN / YELLOW / RED / GREY theo thang trên
- Menu row: thêm "Gia hạn" → dialog nhập số giờ

### 5c. Extend Deadline Dialog
```
┌──────────────────────────────────────┐
│  Gia hạn giải trình                  │
│                                      │
│  Hạn hiện tại: 15/04/2026 23:59     │
│                                      │
│  Gia hạn thêm:  [  24  ] giờ        │
│  Hạn mới:       16/04/2026 23:59    │
│                                      │
│  [Huỷ]           [Xác nhận gia hạn] │
└──────────────────────────────────────┘
```

### 5d. Employee Exception Card — Countdown

Trong `employee_exceptions_screen.dart`:
- Thêm `DeadlineChip` widget:
  - GREEN: "Còn 2 ngày 4 giờ"
  - YELLOW: "Còn 18 giờ"
  - RED: "Còn 2 giờ 30 phút !"
  - GREY: "Đã hết hạn"
- Disabled submit button khi `currentState == EXPIRED`

---

## 6. Phân chia Phase

### Phase P1 — Core Backend (ưu tiên cao nhất)
1. Migration: `exception_policies` table + `extended_deadline_at` column
2. `app/models.py`: `ExceptionPolicy` model
3. `app/schemas/`: `ExceptionPolicyResponse`, `ExceptionPolicyPatch`
4. `app/api/rules.py`: GET/PATCH `/rules/exception-policy`
5. `app/services/attendance_exception_workflow.py`:
   - `_auto_expire_overdue(db, exceptions)`
   - `_get_effective_deadline(exception)` helper
   - Block submit khi expired
6. `app/api/reports.py`:
   - Áp dụng lazy expiry tại list/get/my endpoints
   - `extend-deadline` endpoint
   - `batch-expire` endpoint
7. Test thủ công với curl/Swagger

### Phase P2 — Admin UI
1. `admin_api.dart`: thêm `ExceptionPolicy` model, API methods
2. Settings Screen: thêm tab "Chính sách giải trình"
3. Exceptions tab: thêm cột deadline + màu badge
4. Extend deadline dialog

### Phase P3 — Employee UI
1. `attendance_api.dart`: thêm `expiresAt`, `extendedDeadlineAt` vào `AttendanceExceptionItem`
2. `employee_exceptions_screen.dart`: `DeadlineChip` widget + countdown
3. Block submit khi EXPIRED

### Phase P4 — Polish (optional)
1. Purge records sau grace_period_days
2. Admin trigger xoá hồ sơ hết hạn trong Settings
3. Hiển thị grace_period countdown trong Admin exceptions tab

---

## 7. Quy ước quan trọng

- `expires_at` = set lúc tạo exception, không đổi
- `extended_deadline_at` = set khi admin gia hạn, override `expires_at`
- **Effective deadline** luôn = `extended_deadline_at ?? expires_at`
- Status `EXPIRED` chỉ set bởi lazy expiry — không set thủ công
- Gia hạn exception đang EXPIRED → status trở về `PENDING_EMPLOYEE`
- Admin không cần confirmation khi gia hạn (low-risk action)
- Deadline UI chỉ hiện với PENDING_EMPLOYEE exceptions
