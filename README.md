# ESS Mobile App - Employee Self Service

Mobile app for ERPNext attendance, leave requests, and payroll.

## Quick Start

### Build APK (Local)
```bash
flutter pub get
flutter build apk --debug
# APK at: build/app/outputs/flutter-apk/app-debug.apk
```

### Or Use GitHub Actions
1. Generate a new token with `repo` AND `workflow` scopes
2. Push to trigger auto-build
3. Download APK from Actions tab

## Features

- ✅ Login with ERPNext credentials
- ✅ View employee profile
- ✅ Clock In with GPS
- ✅ Leave request management
- ✅ Payroll view
- ✅ Attendance history

## Configuration

Edit `lib/main.dart` → `AppConfig`:
- `baseUrl` - Your ERPNext URL
- `apiKey` - Your API Key
- `apiSecret` - Your API Secret

## API Endpoints

```
POST /api/method/login
GET  /api/resource/Employee
POST /api/resource/Attendance
GET  /api/resource/Attendance
GET  /api/resource/Leave Type
POST /api/resource/Leave Application
GET  /api/resource/Salary Slip
```
