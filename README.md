# Chikitsya — Quick Start

**Prerequisites**
- Git, Flutter SDK, Android SDK (or Xcode for iOS)
- Python 3.8+ and pip
- (Optional) Docker & Docker Desktop for running Presidio services locally
- Firebase project configured (see `chikitsya/android/app/google-services.json`)

**Repository layout (important files)**
- Server: [server/app.py](server/app.py) — Flask API entry
- Server processing: [server/process.py](server/process.py) — PDF extraction + Presidio calls
- Flutter app: [chikitsya/](chikitsya/) — Flutter project
- Firebase config (Android): [chikitsya/android/app/google-services.json](chikitsya/android/app/google-services.json)

**1) Start the backend server (local, without Docker)**
- Create and activate a Python virtual environment, install deps:
```powershell
python -m venv server/env
server\env\Scripts\Activate.ps1  # PowerShell
pip install -r server/requirements.txt
```
- Confirm or update Presidio service URLs in `server/process.py` (ANALYZER_URL, ANONYMIZER_URL). If you are running Presidio locally set them to `http://127.0.0.1:5002` and `http://127.0.0.1:5001` respectively.
- Run the Flask server:
```powershell
python server/app.py
# or
python3 server/app.py
```
- Server listens on `0.0.0.0:5000` by default (see `server/app.py`).

**2) (Optional) Run Presidio Analyzer & Anonymizer with Docker**
- Pull images and run containers (example images; if pull fails, see Presidio docs at https://microsoft.github.io/presidio/):
```powershell
docker pull mcr.microsoft.com/presidio/analyzer:latest
docker pull mcr.microsoft.com/presidio/anonymizer:latest

docker run -d --name presidio-analyzer -p 5002:5002 mcr.microsoft.com/presidio/analyzer:latest
docker run -d --name presidio-anonymizer -p 5001:5001 mcr.microsoft.com/presidio/anonymizer:latest
```
- If your environment uses a different image path, consult the official Presidio repo/docs for exact image names and recommended docker-compose.
- After containers are running, ensure `server/process.py` points to the analyzer/anonymizer host:port (e.g., `http://127.0.0.1:5002` / `http://127.0.0.1:5001`).

**3) Start the Flutter application (mobile)**
- Open terminal at `chikitsya/` and fetch packages:
```bash
cd chikitsya
flutter pub get
```
- Confirm Firebase config:
  - Android: `chikitsya/android/app/google-services.json` should be present (you provided one).
  - iOS: add the GoogleService-Info.plist in the iOS runner if testing on iOS.
  - For Phone Auth, add your app SHA-1/SHA-256 to Firebase project settings (Android) and enable Phone sign-in in Firebase Console.
- Run the app:
```bash
flutter run
```
- For phone authentication, use a physical device or an emulator with Google Play services. If you do not receive SMS, add a test phone number in Firebase Authentication (Console → Authentication → Sign-in method → Phone → Add test phone number) to avoid SMS quota and reCAPTCHA issues.

**4) Firebase Phone Auth notes (common gotchas)**
- Make sure Phone sign-in is enabled in Firebase Console.
- Add debug/release SHA fingerprints to Firebase for Android (required for Play Integrity / SafetyNet flow).
- Use Firebase test phone numbers to avoid sending real SMS while developing.
- If Play Integrity isn't available, Firebase may fall back to reCAPTCHA Enterprise — configure a site key in Google Cloud & Firebase if needed.

**5) Troubleshooting quick tips**
- `docker pull` error on Windows: ensure Docker Desktop is installed and running (Docker daemon). Start Docker Desktop before running `docker` commands.
- If OTP `verificationFailed` callbacks show reCAPTCHA or Play Integrity errors: verify SHA fingerprints and Firebase Phone sign-in settings.
- If server cannot reach Presidio: ensure containers are running and `ANALYZER_URL` / `ANONYMIZER_URL` point to the correct host/port.

**6) Useful commands**
- Python environment and server:
```powershell
python -m venv server/env
server\env\Scripts\Activate.ps1
pip install -r server/requirements.txt
python server/app.py
```
- Docker (Presidio):
```powershell
docker pull mcr.microsoft.com/presidio/analyzer:latest
docker pull mcr.microsoft.com/presidio/anonymizer:latest
docker run -d --name presidio-analyzer -p 5002:5002 mcr.microsoft.com/presidio/analyzer:latest
docker run -d --name presidio-anonymizer -p 5001:5001 mcr.microsoft.com/presidio/anonymizer:latest
```
- Flutter:
```bash
cd chikitsya
flutter pub get
flutter run
```

**7) Features (one-line implementation pointer)**
- Phone authentication: Firebase Phone Auth (`chikitsya/lib/services/auth_service.dart`) — client-side service handling OTP send/verify.
- PDF extraction: `server/process.py` — uses `pdfplumber` to extract text from PDFs.
- De-identification (PII removal): `server/process.py` → Presidio analyzer/anonymizer (server service calling Presidio APIs).
- Care-plan generation: `server/gemini_service.py` — sends de-identified text to Gemini API to generate care plans and chat responses (service/API wrapper).
- Voice interaction: `chikitsya/lib/services/voice_interaction_service.dart` — microphone permission checks and voice-to-text flow (service).
- Notifications & scheduling: `chikitsya/lib/services/notification_service.dart` — local notifications and scheduling (service).
- Profile & persistence: `chikitsya/lib/providers/profile_provider.dart` and `chikitsya/lib/services/database_service.dart` — local profile storage (model + service).
- UI components & screens: `chikitsya/lib/screens/*` and `chikitsya/lib/widgets/*` — presentation layer (widgets/screens).

---
If you want, I can next:
- Add a docker-compose.yml for Presidio and the Flask server, or
- Add a small script to set ANALYZER_URL/ANONYMIZER_URL from environment variables in `server/process.py`.

README created at repository root: [README.md](README.md)
