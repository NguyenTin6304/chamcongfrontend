# TASKS PHASE 1 - Chot nghiep vu Exception Workflow

## Task 1: Chot vocabulary va status chinh thuc
- [ ] Xac nhan bo status chinh thuc:
  - [ ] `PENDING_EMPLOYEE`
  - [ ] `PENDING_ADMIN`
  - [ ] `APPROVED`
  - [ ] `REJECTED`
  - [ ] `EXPIRED`
- [ ] Xac nhan khong dung them status tam thoi ngoai bo tren
- [ ] Xac nhan backend/frontend/reporting/notification se dung cung mot vocabulary

## Task 2: Chot state machine va transition matrix
- [ ] Chot luong chuan:
  - [ ] `SYSTEM_DETECTED -> PENDING_EMPLOYEE -> PENDING_ADMIN -> APPROVED`
  - [ ] `SYSTEM_DETECTED -> PENDING_EMPLOYEE -> PENDING_ADMIN -> REJECTED`
  - [ ] `SYSTEM_DETECTED -> PENDING_EMPLOYEE -> EXPIRED`
- [ ] Chot co hay khong luong `SYSTEM_DETECTED -> PENDING_ADMIN`
- [ ] Chot ro transition nao bi cam
- [ ] Chot backend la source of truth duy nhat cho transition

## Task 3: Chot phan quyen actor
- [ ] Xac nhan employee chi duoc:
  - [ ] xem exception cua minh
  - [ ] submit explanation khi status la `PENDING_EMPLOYEE`
- [ ] Xac nhan employee khong duoc:
  - [ ] approve
  - [ ] reject
  - [ ] doi transition ngoai explanation
- [ ] Xac nhan admin chi duoc:
  - [ ] review `PENDING_ADMIN`
  - [ ] approve
  - [ ] reject
  - [ ] nhap note quyet dinh
- [ ] Xac nhan system duoc:
  - [ ] create exception
  - [ ] expire exception
  - [ ] trigger notification/job lien quan

## Task 4: Chot phan loai exception theo flow xu ly
- [ ] Liet ke danh sach loai exception can xu ly
- [ ] Voi moi loai, chot:
  - [ ] nguon phat hien
  - [ ] co can employee explanation khong
  - [ ] neu khong can thi co vao thang `PENDING_ADMIN` khong
  - [ ] co truong hop nao auto approve khong
- [ ] Chot ro cac nhom can xem xet:
  - [ ] fake GPS / location spoof
  - [ ] check-in ngoai vung
  - [ ] checkout bat thuong
  - [ ] thieu checkout
  - [ ] lech gio lon

## Task 5: Chot SLA giai trinh va rule expire
- [ ] Chot SLA giai trinh la bao nhieu ngay
- [ ] Chot moc tinh han:
  - [ ] tu `detected_at`
  - [ ] hay dau ngay lam viec ke tiep
  - [ ] hay cuoi ngay lam viec
- [ ] Chot khi nao exception thanh `EXPIRED`
- [ ] Chot `EXPIRED` co duoc reopen khong
- [ ] Chot `EXPIRED` co duoc admin xu ly tay sau do khong

## Task 6: Chot notification expectation o muc nghiep vu
- [ ] Chot system phat hien exception thi notify employee
- [ ] Chot employee submit explanation thi notify admin
- [ ] Chot admin approve/reject thi notify employee
- [ ] Chot co hay khong reminder truoc khi het han
- [ ] Neu co reminder, chot:
  - [ ] remind truoc bao lau
  - [ ] mot lan hay nhieu lan

## Task 7: Chot rule approve/reject cu the
- [ ] Chot admin reject co bat buoc note khong
- [ ] Chot admin approve co bat buoc note khong
- [ ] Chot sau `APPROVED/REJECTED` co duoc thay doi quyet dinh khong
- [ ] Chot admin co duoc bo qua buoc employee explanation hay khong

## Task 8: Tao bang quyet dinh nghiep vu dau vao cho Phase 2
- [ ] Tao bang state machine:
  - [ ] current status
  - [ ] actor
  - [ ] allowed action
  - [ ] next status
- [ ] Tao bang phan loai exception:
  - [ ] exception type
  - [ ] source
  - [ ] explanation required
  - [ ] SLA
  - [ ] notify target
- [ ] Tao danh sach business rules:
  - [ ] create
  - [ ] submit explanation
  - [ ] approve
  - [ ] reject
  - [ ] expire

## Task 9: Ghi lai open questions va blocker
- [ ] Liet ke cac diem business chua chot
- [ ] Danh dau ro muc nao la blocker cua Phase 2
- [ ] Khong cho bat dau Phase 2 neu con question lam backend phai tu suy doan

## Task 10: Verify tai lieu Phase 1
- [ ] Dam bao khong co noi dung implementation code trong Phase 1
- [ ] Dam bao tat ca quyet dinh deu la nghiep vu/contract-level
- [ ] Dam bao backend/frontend/notification/reporting co the doc cung mot bo rule
- [ ] Dam bao `PHASE1_PLAN.md` va `TASKS_PHASE1.md` dong bo voi roadmap moi trong `CLAUDE.md`
