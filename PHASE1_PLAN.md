# Phase 1 Plan: Chốt nghiệp vụ Exception Workflow

## Mục tiêu

Chốt dứt điểm nghiệp vụ cho exception workflow mới trước khi đụng vào schema, API, notification hay UI.

Phase 1 chỉ nhằm trả lời rõ:
- exception có các trạng thái nào
- ai được thao tác ở mỗi trạng thái
- trạng thái chuyển như thế nào
- exception nào cần nhân viên giải trình
- exception nào có thể vào thẳng admin review
- SLA giải trình là bao lâu
- khi nào exception hết hạn
- có nhắc hạn hay không

Nếu chưa chốt xong các câu trên thì không bắt đầu Phase 2.

---

## Phạm vi

### Trong scope
- Chốt state machine mới cho exception.
- Chốt quyền thao tác của employee/admin/system.
- Chốt rule transition hợp lệ.
- Chốt phân loại exception theo flow xử lý.
- Chốt SLA giải trình và rule expire.
- Chốt yêu cầu notification ở mức nghiệp vụ.
- Chốt các quyết định đủ để backend Phase 2 implement mà không phải đoán.

### Ngoài scope
- Không sửa code frontend/backend ở Phase 1.
- Không đổi schema DB.
- Không tạo API mới.
- Không làm UI mới.
- Không implement notification/job.

---

## State Machine cần chốt

## Status chính thức
- `PENDING_EMPLOYEE`
- `PENDING_ADMIN`
- `APPROVED`
- `REJECTED`
- `EXPIRED`

## Luồng chuẩn cần chốt
- `SYSTEM_DETECTED -> PENDING_EMPLOYEE -> PENDING_ADMIN -> APPROVED`
- `SYSTEM_DETECTED -> PENDING_EMPLOYEE -> PENDING_ADMIN -> REJECTED`
- `SYSTEM_DETECTED -> PENDING_EMPLOYEE -> EXPIRED`

## Luồng rẽ nhánh cần chốt thêm
- loại exception nào đi thẳng:
  - `SYSTEM_DETECTED -> PENDING_ADMIN`
- loại exception nào bắt buộc qua:
  - `SYSTEM_DETECTED -> PENDING_EMPLOYEE`

## Nguyên tắc transition
- Backend là source of truth duy nhất cho transition.
- Frontend chỉ hiển thị action hợp lệ theo status hiện tại.
- Không cho nhảy trạng thái tắt.
- Không cho employee approve/reject.
- Không cho admin nộp explanation thay employee.

---

## Câu hỏi nghiệp vụ bắt buộc phải chốt

### 1. Phân loại exception
Cần lập bảng mapping:
- loại exception
- điều kiện phát hiện
- có cần employee giải trình không
- nếu không cần thì có vào thẳng `PENDING_ADMIN` không
- có cho auto approve trong trường hợp nào không

Ví dụ các nhóm cần chốt:
- fake GPS / location spoof
- check-in ngoài vùng
- checkout bất thường
- thiếu checkout
- lệch giờ lớn

### 2. Quyền thao tác

#### Employee
- Chỉ được:
  - xem exception của chính mình
  - nhập explanation khi status là `PENDING_EMPLOYEE`
- Không được:
  - approve
  - reject
  - sửa explanation sau khi đã submit, trừ khi nghiệp vụ cho phép

#### Admin
- Chỉ được:
  - review exception đang ở `PENDING_ADMIN`
  - approve
  - reject
  - nhập note quyết định
- Không được:
  - submit explanation thay employee
  - đổi trực tiếp `PENDING_EMPLOYEE -> APPROVED/REJECTED`

#### System
- Tạo exception ban đầu
- Tự expire exception quá hạn
- Gửi notification theo workflow

### 3. SLA giải trình
- Thời hạn giải trình là bao nhiêu ngày
- Tính từ:
  - `detected_at`
  - hay đầu ngày làm việc kế tiếp
  - hay cuối ngày làm việc
- Có nhắc hạn không
- Nếu có:
  - nhắc trước bao lâu
  - nhắc một lần hay nhiều lần

### 4. Rule expire
- Khi hết hạn thì chuyển sang `EXPIRED` ngay hay theo batch job định kỳ
- `EXPIRED` có thể reopen hay không
- `EXPIRED` có được admin duyệt tay sau đó hay không

### 5. Rule reject/approve
- Admin reject có bắt buộc note không
- Admin approve có bắt buộc note không
- Sau `APPROVED/REJECTED` có được sửa lại quyết định không

---

## Deliverables bắt buộc của Phase 1

Phase 1 phải tạo ra tài liệu chốt được các mục sau:

1. Bảng state machine
- status hiện tại
- actor được phép thao tác
- action hợp lệ
- status kế tiếp

2. Bảng phân loại exception
- loại exception
- nguồn phát hiện
- có cần explanation không
- SLA bao nhiêu ngày
- có notify ai

3. Danh sách business rules
- rule tạo exception
- rule submit explanation
- rule approve
- rule reject
- rule expire

4. Danh sách câu hỏi mở
- các điểm chưa được business chốt
- các điểm nếu chưa rõ thì Phase 2 chưa được bắt đầu

---

## Tiêu chí hoàn thành Phase 1

Phase 1 chỉ được coi là xong khi:
- tất cả status đã chốt
- tất cả transition hợp lệ đã chốt
- quyền employee/admin/system đã chốt
- SLA expire đã chốt
- loại exception nào cần explanation đã chốt
- không còn chỗ nào Phase 2 phải tự suy đoán nghiệp vụ

---

## Rủi ro nếu bỏ qua

- Backend implement sai transition rồi phải migrate lại.
- Frontend employee/admin làm lệch nhau vì hiểu khác status.
- Notification flow gửi sai actor.
- Reporting sau này không thống nhất vì status không được chốt ngay từ đầu.

---

## Bước thực hiện đề xuất

1. Chốt vocabulary/status chính thức.
2. Chốt transition matrix.
3. Chốt actor permissions.
4. Chốt exception-type classification.
5. Chốt SLA + expire rule.
6. Chốt notification expectation ở mức nghiệp vụ.
7. Viết bảng quyết định cuối cùng làm đầu vào cho Phase 2.

---

## Guardrails

- Không bắt đầu sửa model/API trước khi matrix nghiệp vụ được chốt.
- Không để frontend/backend tự định nghĩa status khác nhau.
- Không dùng tên status tạm thời ngoài 5 status đã chốt.
- Không mở rộng scope sang implementation ở Phase 1.
