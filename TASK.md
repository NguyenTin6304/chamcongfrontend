# TASK.md — Exception Deadline Policy
# Cập nhật: 2026-04-14
# Xem PLAN.md để biết chi tiết thiết kế

---

## Tiến độ tổng quan

| Phase | Mô tả | Trạng thái |
|-------|-------|-----------|
| P1 | Core Backend | ✅ Hoàn thành (trừ P1.7 test thủ công) |
| P2 | Admin UI | ✅ Hoàn thành |
| P3 | Employee UI | ✅ Hoàn thành |
| P4 | Polish | ✅ Hoàn thành |

---

## Phase P1 — Core Backend

### P1.1 — Database Migration ✅
- [x] Tạo file migration `alembic/versions/a3b5c7d9e1f2_exception_deadline_policy.py`
  - Tạo bảng `exception_policies` (singleton id=1)
  - Insert row mặc định: `default_deadline_hours=72`, `grace_period_days=30`
  - Thêm cột `extended_deadline_at TIMESTAMP NULL` vào `attendance_exceptions`
- [x] Chạy `python -m alembic upgrade head` và xác nhận không lỗi

### P1.2 — ORM Model ✅
- [x] `app/models.py`: thêm class `ExceptionPolicy`
- [x] `app/models.py`: thêm `extended_deadline_at` vào `AttendanceException`

### P1.3 — Schemas ✅
- [x] `app/schemas/exception_policy.py` (file mới): `ExceptionPolicyResponse`, `ExceptionPolicyPatch`
- [x] Export từ `app/schemas/__init__.py` nếu cần (không có __init__.py, import trực tiếp)

### P1.4 — Rules API ✅
- [x] `app/api/rules.py`: GET /rules/exception-policy (tất cả user đã đăng nhập)
- [x] `app/api/rules.py`: PATCH /rules/exception-policy (chỉ ADMIN, dùng require_admin)

### P1.5 — Workflow Service ✅
- [x] `get_deadline_hours(policy, exception_type) -> int`
- [x] `get_effective_deadline(exception) -> datetime | None`
- [x] `auto_expire_overdue(db, exceptions) -> list` — lazy expiry
- [x] Sửa `_default_expires_at` trong reports.py: dùng policy thay vì hardcode 3 ngày

### P1.6 — Reports API ✅
- [x] `submit_explanation`: check deadline → HTTP 410 nếu quá hạn, flip status EXPIRED
- [x] `list_exceptions` (admin): gọi `_expire_overdue_now(db)` trước query
- [x] `my_exceptions` (employee): gọi `_expire_overdue_now(db)` trước query
- [x] `get_exception` + `get_my_exception` (single): gọi `auto_expire_overdue(db, [exception])`
- [x] `extended_deadline_at` thêm vào list query + `_build_exception_response`
- [x] `AttendanceExceptionReportResponse` thêm field `extended_deadline_at`
- [x] PATCH `/reports/attendance-exceptions/{id}/extend-deadline` (admin only)
- [x] POST `/reports/attendance-exceptions/batch-expire` (admin only)

### P1.7 — Kiểm tra thủ công
- [ ] Test GET/PATCH `/rules/exception-policy` với Swagger
- [ ] Test `submit-explanation` sau khi expires_at đã qua → expect 410
- [ ] Test extend-deadline với exception EXPIRED → expect status về PENDING_EMPLOYEE
- [ ] Test batch-expire

---

## Phase P2 — Admin UI

### P2.1 — admin_api.dart
- [x] Thêm model `ExceptionPolicy`:
  ```dart
  class ExceptionPolicy {
    final int defaultDeadlineHours;
    final int? autoClosedDeadlineHours;
    final int? missedCheckoutDeadlineHours;
    final int? locationRiskDeadlineHours;
    final int? largeTimeDeviationDeadlineHours;
    final int gracePeriodDays;
    final DateTime? updatedAt;
    final String? updatedByName;
  }
  ```
- [x] Thêm `expiresAt`, `extendedDeadlineAt` vào `AttendanceExceptionItem`
- [x] Thêm method `getExceptionPolicy(token)` → `ExceptionPolicy`
- [x] Thêm method `patchExceptionPolicy(token, {...})` → `ExceptionPolicy`
- [x] Thêm method `extendExceptionDeadline(token, id, extendHours)` → `AttendanceExceptionItem`

### P2.2 — Settings Screen: Tab Chính sách giải trình
- [x] `lib/features/admin/presentation/settings/settings_screen.dart`:
  - Thêm tab item "Chính sách giải trình"
  - Sidebar item: "Chính sách giải trình" với icon `Icons.timer_outlined`
- [x] Tạo widget `_ExplanationPolicyTab` (trong settings hoặc file riêng):
  - Load policy khi init
  - TextField: deadline mặc định (hours)
  - 4 TextFields override per type (nullable)
  - TextField: grace period (days)
  - Text: "Cập nhật lần cuối: ..."
  - Button: "Lưu cài đặt"
  - Validation: hours phải > 0, grace_period > 0

### P2.3 — Exceptions Tab: Cột Deadline
- [x] `lib/features/admin/presentation/exceptions/` (xem file hiện có):
  - Thêm cột "Hạn giải trình" vào bảng/list
  - Chỉ hiện với PENDING_EMPLOYEE tab
- [x] Tạo `DeadlineBadge` widget:
  - Input: `DateTime? effectiveDeadline`
  - Tính `remaining = effectiveDeadline - now`
  - GREEN  (> 48h): chip xanh lá, text "Còn X ngày"
  - YELLOW (24–48h): chip vàng, text "Còn X giờ"
  - RED    (0–24h): chip đỏ, text "Còn X giờ !"
  - GREY   (quá hạn): chip xám, text "Đã hết hạn"
- [ ] Row action menu: thêm "Gia hạn" option (chỉ PENDING_EMPLOYEE)

### P2.4 — Extend Deadline Dialog
- [x] Tạo `_showExtendDeadlineDialog(exception)`:
  - Hiện effective deadline hiện tại
  - TextField: số giờ gia hạn (default 24, max 168)
  - Preview: "Hạn mới: ..."  (cập nhật realtime khi nhập)
  - Nút Xác nhận → gọi `extendExceptionDeadline`

---

## Phase P3 — Employee UI

### P3.1 — attendance_api.dart
- [x] Thêm `expiresAt`, `extendedDeadlineAt` vào `AttendanceExceptionItem`
- [x] Parse từ JSON: `expires_at`, `extended_deadline_at`
- [x] Thêm computed getter:
  ```dart
  DateTime? get effectiveDeadline => extendedDeadlineAt ?? expiresAt;
  ```

### P3.2 — DeadlineChip widget
- [x] Tạo `lib/widgets/common/deadline_chip.dart`
- [x] Input: `DateTime? deadline`, `bool compact = false`
- [x] Logic countdown: hiện "Còn X ngày Y giờ" / "Còn X giờ Y phút" / "Đã hết hạn"
- [x] Auto-refresh mỗi 60 giây (dùng Timer)

### P3.3 — Employee Exceptions Screen
- [x] `lib/features/attendance/presentation/employee_exceptions_screen.dart`:
  - Hiện `DeadlineChip` trên mỗi exception card (chỉ PENDING_EMPLOYEE)
  - Disabled submit button khi status == EXPIRED hoặc deadline đã qua
  - Text hint: "Đã hết hạn giải trình" khi disabled

---

## Phase P4 — Polish ✅

- [x] Purge records: `DELETE` exceptions đã EXPIRED > grace_period_days ngày
- [x] Admin trigger: "Xoá hồ sơ hết hạn" button trong Settings
- [x] Hiển thị grace_period countdown trong Admin exceptions tab

---

## Log tiến độ

| Ngày | Phase | Nội dung | Người làm |
|------|-------|----------|-----------|
| 2026-04-14 | — | Tạo PLAN.md + TASK.md | Claude |
| 2026-04-14 | P1.1 | Migration: exception_policies table + extended_deadline_at | Claude |
| 2026-04-14 | P1.2 | ORM: ExceptionPolicy model + extended_deadline_at column | Claude |
| 2026-04-14 | P1.3 | Schemas: ExceptionPolicyResponse, ExceptionPolicyPatch | Claude |
| 2026-04-14 | P1.4 | Rules API: GET/PATCH /rules/exception-policy | Claude |
| 2026-04-14 | P1.5 | Workflow service: lazy expiry helpers + deadline utils | Claude |
| 2026-04-14 | P1.6 | Reports API: lazy expiry, block submit, extend-deadline, batch-expire | Claude |
| 2026-04-14 | P2 | Admin UI: policy settings tab, deadline badge, extend dialog | Codex |
| 2026-04-14 | P3 | Employee UI: deadline fields, countdown chip, submit blocking | Codex |
| 2026-04-14 | P4 | Polish: purge expired records, admin trigger, grace countdown | Codex |
