# Birdle - Ứng dụng chấm công (Flutter)

## 1) Tổng quan
Đây là frontend Flutter cho hệ thống chấm công theo GPS/geofence.

Ứng dụng hiện có 2 luồng chính:
- `USER`: đăng nhập, lấy GPS, check-in/check-out, xem lịch sử chấm công.
- `ADMIN`: quản trị rule, nhân viên, group/geofence, xử lý exception, xuất báo cáo Excel.

Backend API đang tích hợp theo chuẩn FastAPI (project backend tách riêng).

## 2) Tính năng hiện tại
### 2.1) Xác thực & phiên đăng nhập
- Đăng nhập, đăng ký, lấy hồ sơ (`/auth/login`, `/auth/register`, `/auth/me`).
- Refresh token & logout (`/auth/refresh`, `/auth/logout`).
- Tự khôi phục phiên đăng nhập khi mở lại app.
- Có tùy chọn `Ghi nhớ đăng nhập`.

### 2.2) Quên mật khẩu
- Gửi yêu cầu quên mật khẩu (`/auth/forgot-password`).
- Đặt lại mật khẩu bằng token (`/auth/reset-password`).
- Trang reset tự đọc token từ URL (query hoặc fragment).
- Có cảnh báo rõ khi link thiếu token.

### 2.3) reCAPTCHA
- Đăng nhập có hỗ trợ reCAPTCHA v2 checkbox trên Flutter Web (nếu có `RECAPTCHA_SITE_KEY`).
- Nếu không cấu hình site key thì bỏ qua bước captcha.
- Có sẵn helper v3 trong `lib/features/auth/data/recaptcha/*` nhưng UI login hiện dùng v2 checkbox.

### 2.4) Chấm công (USER)
- Lấy trạng thái hiện tại (`/attendance/status`).
- Check-in/check-out có gửi tọa độ GPS (`/attendance/checkin`, `/attendance/checkout`).
- Xem lịch sử cá nhân (`/attendance/me`).
- Hiển thị trạng thái trong/ngoài vùng, matched geofence, cảnh báo exception, trạng thái giờ vào/ra.

### 2.5) Quản trị (ADMIN)
- Quản lý rule active (tọa độ, bán kính, giờ vào/ra, grace, cutoff).
- Quản lý nhân viên, gán user cho nhân viên.
- Quản lý group, gán nhân viên vào group.
- Quản lý geofence theo group.
- Xuất báo cáo chấm công (`/reports/attendance.xlsx`).
- Quản lý attendance exception:
  - Lọc danh sách exception.
  - Resolve/Reopen exception (`/reports/attendance-exceptions/...`).

## 3) Công nghệ & package
- Flutter (Material 3)
- `http`
- `flutter_map`
- `latlong2`
- `shared_preferences`
- `geolocator`
- `intl`
- `universal_html`

## 4) Cấu hình runtime
Ứng dụng dùng `--dart-define` để cấu hình:

- `API_BASE_URL`
  - Mặc định: `http://127.0.0.1:8000`
- `RECAPTCHA_SITE_KEY`
  - Mặc định: rỗng (không bật captcha)
- `GEOAPIFY_API_KEY`
  - Mặc định: rỗng (phải truyền qua `--dart-define`)
- `GEOAPIFY_MAP_STYLE`
  - Mặc định: `osm-carto`
- `DEFAULT_MAP_CENTER`
  - Mặc định: `10.776889,106.700806` (format `lat,lng`)

Ví dụ:
```bash
flutter run -d chrome \
  --web-port=62601 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=RECAPTCHA_SITE_KEY=your_site_key \
  --dart-define=GEOAPIFY_API_KEY=your_geoapify_key \
  --dart-define=GEOAPIFY_MAP_STYLE=osm-carto \
  --dart-define=DEFAULT_MAP_CENTER=10.776889,106.700806
```

## 5) Chạy local
### 5.1) Cài dependency
```bash
flutter pub get
```

### 5.2) Chạy web
```bash
flutter run -d chrome --web-port=62601 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=GEOAPIFY_API_KEY=your_geoapify_key
```

### 5.3) Chạy Android emulator
```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### 5.4) Chạy trên máy thật cùng Wi-Fi backend
```bash
flutter run \
  --dart-define=API_BASE_URL=http://<LAN_IP_BACKEND>:8000
```

## 6) Cấu trúc thư mục chính
```text
lib/
  core/
    config/
    download/
    storage/
  features/
    auth/
      data/
      presentation/
    attendance/
      data/
    home/
      presentation/
    admin/
      data/
      presentation/
```

## 7) Quyền truy cập vị trí
Đã khai báo quyền vị trí cho mobile:
- Android:
  - `android.permission.ACCESS_COARSE_LOCATION`
  - `android.permission.ACCESS_FINE_LOCATION`
- iOS:
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`

## 8) Lưu ý tích hợp backend
- User phải được gán employee ở backend thì mới chấm công được.
- Backend phải có rule active/geofence phù hợp để đánh giá trong vùng/ngoài vùng.
- Nếu dùng reset password qua email cho Flutter Web hash-route, link nên theo dạng:
  - `http://<host>/#/reset-password?token=<token>`
- Cần bật CORS phù hợp cho domain frontend (localhost, Vercel, Cloudflare...).

## 9) Lưu ý deploy
- Không commit secret key reCAPTCHA vào repo.
- Chỉ để `RECAPTCHA_SITE_KEY` ở frontend; secret key phải verify ở backend.
- Không hardcode `GEOAPIFY_API_KEY` trong source code; chỉ truyền qua môi trường build/runtime.
- Nếu deploy frontend tĩnh (Vercel/Cloudflare Pages), toàn bộ logic xác minh captcha vẫn phải chạy ở backend API.
