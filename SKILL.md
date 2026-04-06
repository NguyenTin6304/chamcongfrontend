---
name: exception-workflow-roadmap
description: Lam viec theo roadmap moi cho Exception workflow trong du an Birdle. Dung khi Codex can lap plan, chot nghiep vu, refactor backend/API, them notification, employee UI, admin UI, reporting va test cho workflow ngoai le moi. Uu tien di dung phase, khong nhay phase, khong sua UI/API khi nghiep vu transition chua chot.
---

# Exception Workflow Roadmap

## Muc tieu

- Xay dung exception workflow moi theo roadmap 7 phase da chot trong `CLAUDE.md`.
- Giu dung kien truc admin sau refactor:
  - shell mong
  - tab tu lap
  - `AdminDataCache` cho shared data can thiet
- Khong de frontend/backend notification/reporting hieu khac nhau ve status exception.

## Thu tu phase bat buoc

1. Phase 1: chot nghiep vu exception workflow
2. Phase 2: refactor backend model va API
3. Phase 3: notification flow
4. Phase 4: employee UI
5. Phase 5: admin UI
6. Phase 6: reporting va lich su
7. Phase 7: test va acceptance

Khong nhay sang phase sau neu output cua phase truoc chua du ro.

## Phase hien tai uu tien

Neu user chua noi ro phase nao, mac dinh uu tien:
- doc `CLAUDE.md`
- xem roadmap Exception workflow
- bat dau tu `PHASE1_PLAN.md`

## Pham vi doc toi thieu theo phase

### Khi lam Phase 1
- `CLAUDE.md`
- `PHASE1_PLAN.md` neu da ton tai
- chi doc them file exception hien tai neu can doi chieu thuc te

### Khi lam Phase 2-3
- backend model/API files lien quan
- `lib/features/admin/data/admin_api.dart` neu can doi chieu frontend contract
- chi doc UI neu can xem field dang duoc dung

### Khi lam Phase 4
- employee-side screens/features lien quan
- model/API exception
- file route neu can them man hinh moi

### Khi lam Phase 5
- `lib/features/admin/presentation/exceptions/exceptions_screen.dart`
- `lib/features/admin/presentation/dashboard/dashboard_tab.dart`
- `lib/features/admin/data/admin_api.dart`
- file widget exceptions lien quan

### Khi lam Phase 6
- reporting tab/screens
- export/report API
- models/DTO exception moi

### Khi lam Phase 7
- test hien co lien quan exception/admin/attendance
- file implementation vua sua

## Rule bat buoc cua roadmap moi

- Backend la source of truth duy nhat cho transition status.
- Frontend khong tu y suy dien transition.
- Khong implement UI moi neu state machine chua chot.
- Khong implement notification/job neu event source va transition chua ro.
- Khong invent endpoint moi neu chua co plan/backend contract ro rang.

## State machine muc tieu can nho

Status can dung:
- `PENDING_EMPLOYEE`
- `PENDING_ADMIN`
- `APPROVED`
- `REJECTED`
- `EXPIRED`

Luong tong quan:
- `SYSTEM_DETECTED -> PENDING_EMPLOYEE -> PENDING_ADMIN -> APPROVED/REJECTED`
- `PENDING_EMPLOYEE -> EXPIRED`

Can chot them:
- loai exception nao vao thang `PENDING_ADMIN`
- SLA expire
- rule remind truoc expire

## Rule theo khu vuc

### 1. Admin shell

- `AdminShellPage` chi giu shell orchestration.
- Khong nhet exception business logic chi tiet vao shell.
- Exception badge o shell chi duoc giu o muc nhe neu thuc su can.

### 2. Admin Exceptions UI

- `ExceptionsScreen` la noi xu ly chinh cua admin exception UI.
- Dashboard chi nen giu summary/recent items/CTA, khong duyet truc tiep tren dashboard neu roadmap moi yeu cau bo hanh vi nay.

### 3. Employee exception UI

- Uu tien dat o feature phu hop cua employee/attendance.
- Khong dua employee exception flow vao admin module neu khong can.

### 4. Backend/API

- Moi action can co transition validation ro:
  - system create
  - employee submit explanation
  - admin approve
  - admin reject
  - system expire
- Audit trail phai di cung workflow, khong de them sau neu no la requirement cot loi.

## Cach lam viec theo phase

1. Chot input cua phase.
2. Viet plan/checklist neu phase chua co plan file.
3. Chi sua dung pham vi phase do.
4. Verify xong moi mo sang phase tiep theo.

## Khong duoc lam

- Khong tai tao `admin_page.dart`.
- Khong pha vo kien truc shell + tabs da tach.
- Khong refactor rong ngoai scope phase dang lam.
- Khong sua employee/admin UI theo status moi khi backend contract chua chot.
- Khong dung ten status tam thoi khac voi roadmap da chot.

## Verify

Sau moi phase co code:
1. chay `flutter analyze`
2. chay test lien quan neu da co
3. neu patch dong cham contract, doi chieu frontend/backend field va enum

Sau moi phase nghiep vu/tai lieu:
1. dam bao quyet dinh da du de phase sau khong phai doan
2. liet ke ro open questions con lai
