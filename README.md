# Birdle - Cham Cong User MVP (Flutter)

## 1) Tong quan
Frontend Flutter cho bai toan cham cong GPS.
Hien tai da hoan thanh User MVP:
- Login/Register
- Lay GPS
- Check-in / Check-out
- Xem lich su cham cong
- Hien thi distance + trong/ngoai vung + message API

Backend tuong ung:
- Duong dan: `E:\CongtyGPIT\chamcongapp`
- Base API mac dinh: `http://127.0.0.1:8000`

## 2) Cac buoc da lam (log)
### Auth
- Tao `AuthApi` goi:
  - `POST /auth/login`
  - `POST /auth/register`
- Them `LoginPage` + `RegisterPage`.
- Luu JWT token bang `TokenStorage` (`shared_preferences`).

### Attendance User MVP
- Tao `AttendanceApi` goi:
  - `GET /attendance/status`
  - `POST /attendance/checkin`
  - `POST /attendance/checkout`
  - `GET /attendance/me`
- Home page da co:
  - Nut lay GPS that
  - Nut check-in/check-out theo state tu `/attendance/status`
  - Card hien ket qua action gan nhat
  - Danh sach lich su cham cong

### UI/UX polish
- Loading states:
  - global top progress
  - loading rieng cho action checkin/checkout
  - loading cho lay GPS
- Badge:
  - Badge trang thai `IN/OUT/UNASSIGNED`
  - Badge range `Trong vung/Ngoai vung`
- Format thoi gian VN:
  - Hien thi theo UTC+7
  - Dinh dang `dd/MM/yyyy HH:mm:ss (VN)`

### Mobile permissions
- Android manifest da them:
  - `android.permission.ACCESS_COARSE_LOCATION`
  - `android.permission.ACCESS_FINE_LOCATION`
- iOS Info.plist da them:
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`

## 3) Dependencies
- `http`
- `shared_preferences`
- `geolocator`
- `intl`

## 4) Cac file chinh
- `lib/main.dart`
- `lib/core/config/app_config.dart`
- `lib/core/storage/token_storage.dart`
- `lib/features/auth/data/auth_api.dart`
- `lib/features/auth/presentation/login_page.dart`
- `lib/features/auth/presentation/register_page.dart`
- `lib/features/attendance/data/attendance_api.dart`
- `lib/features/home/presentation/home_page.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

## 5) Chay local
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android emulator:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Test tren dien thoai that (cung Wi-Fi voi may backend):
```bash
flutter run --dart-define=API_BASE_URL=http://<LAN_IP_BACKEND>:8000
```

## 6) Luu y
- Tai khoan `USER` phai duoc gan `employee` o backend thi moi checkin/checkout duoc.
- Backend phai co `rules/active`.
- Neu Android chan HTTP cleartext, can mo cau hinh cleartext hoac dung HTTPS.
