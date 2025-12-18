AdChat Agora Edition - automated fixes applied

What I changed:
- Updated pubspec.yaml dependencies to include Agora, Firebase, FCM, Cloud Functions
- Ensured AndroidManifest includes required permissions and FCM service
- Added functions/ with 2nd Gen index.js and package.json (Node 20)
- Removed deprecated 'crypto' npm dependency in functions

Next steps for you:
1. Replace Agora App ID & Certificate in functions/index.js and lib/services/agora_service.dart
2. Add google-services.json to android/app/
3. In functions/: run `npm install` locally, then deploy using Blaze project
4. Run `flutter clean` and `flutter pub get`, then build & test on device

