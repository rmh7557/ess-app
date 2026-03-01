# ESS Mobile App - Employee Self Service

Mobile app for ERPNext attendance, leave requests, and payroll.

## Setup

### Prerequisites
- Flutter 3.x installed
- Android SDK / Xcode (for iOS)

### Installation

```bash
cd ess_app
flutter pub get
flutter run
```

## Features

### MVP (Phase 1)
- ✅ Login with ERPNext credentials
- ✅ View employee profile
- ✅ Clock In with GPS location
- ✅ Today's attendance status
- ✅ Leave request management
- ✅ Payroll view
- ✅ Attendance history

### Future Features
- Clock Out
- Leave balance
- Notifications
- Offline mode

## Configuration

Edit `lib/main.dart` → `AppConfig` class:
- `baseUrl` - Your ERPNext URL
- `apiKey` - Your API Key
- `apiSecret` - Your API Secret

## API Endpoints Used

```
POST /api/method/login
GET  /api/resource/Employee
POST /api/resource/Attendance
GET  /api/resource/Attendance
GET  /api/resource/Leave Type
POST /api/resource/Leave Application
GET  /api/resource/Salary Slip
```

## Screens

1. **Login** - Email/password authentication
2. **Home** - Dashboard with employee info, clock-in, quick actions
3. **Leave** - Submit and view leave requests
4. **Payroll** - View salary slips
5. **Attendance History** - View past attendance

## Project Structure

```
lib/
  main.dart          # All screens in one file
```
