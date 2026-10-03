# Voice Message Reader (iOS)

SwiftUI app that turns voice messages (WhatsApp, Telegram, Signal…), audio and video into text.

- App, Share Extension, Widget (XcodeGen: `project.yml`)
- iOS 17+; uses SpeechAnalyzer on iOS 26, SFSpeechRecognizer otherwise
- Builds on GitHub Actions and uploads to TestFlight (`.github/workflows/build.yml`)

Secrets needed: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (App Store Connect API key, Admin role).
