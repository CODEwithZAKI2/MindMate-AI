# MindMate AI 🧠💚

> Your compassionate mental wellness companion powered by AI

**MindMate AI** is a Flutter-based mobile application designed to provide accessible, private mental wellness support through empathetic AI conversations, mood tracking, and personalized wellness exercises.

[![Flutter Version](https://img.shields.io/badge/Flutter-3.29.3-02569B?logo=flutter)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.7.2-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Proprietary-red)]()

---

## 🌟 Features

### Core Features (MVP)
- 🔐 **Secure Authentication** - Email, Google, and Apple Sign-In
- 💬 **AI Wellness Chat** - Empathetic conversations with context memory
- 📊 **Mood Tracking** - Daily check-ins with 5-point scale
- 📈 **Mood History** - Visual trends and patterns
- 🚨 **Safety System** - Proactive crisis detection with resource display
- ⚙️ **User Settings** - Profile management and preferences

### Coming Soon
- 🎯 Premium subscription tier
- 📉 Advanced mood analytics
- 🧘 Guided breathing exercises
- ✍️ AI-powered journaling
- 🔔 Smart reminders
- 🌍 Multi-language support

---

## 🏗️ Architecture

MindMate AI follows **Clean Architecture** principles with a clear separation of concerns:

```
lib/
├── core/           # Shared utilities, constants, theme
├── data/           # Data sources, models, repositories
├── domain/         # Business logic, entities, use cases
├── presentation/   # UI, screens, widgets, state management
└── l10n/           # Internationalization
```

### Tech Stack
- **Frontend**: Flutter 3.29+ with Material 3
- **State Management**: Riverpod 2.x
- **Backend**: Firebase (Auth, Firestore, Cloud Functions)
- **AI**: Google Gemini API
- **Navigation**: GoRouter
- **Typography**: Google Fonts (Inter)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.29.3 or higher
- Dart 3.7.2 or higher
- Android Studio / VS Code with Flutter extension
- Firebase project (see setup instructions)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/mindmate_ai.git
   cd mindmate_ai
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase** (Required)
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add Android and iOS apps
   - Download configuration files:
     - `google-services.json` → `android/app/`
     - `GoogleService-Info.plist` → `ios/Runner/`
   - Enable Authentication (Email/Password, Google)
   - Create Firestore database

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run analyzer
flutter analyze
```

---

## 📱 Supported Platforms

- ✅ Android 5.0+ (API 21+)
- ✅ iOS 12.0+
- 🚧 Web (coming soon)
- 🚧 macOS (coming soon)

---

## 🎨 Design System

### Colors
- **Primary**: Calming Purple `#6B4CE6`
- **Secondary**: Welcoming Teal `#4ECDC4`
- **Mood Scale**: 5 colors from red to green

### Typography
- **Font Family**: Inter (Google Fonts)
- **Styles**: Material Design 3 type scale

### Theme
- ✅ Light mode
- ✅ Dark mode
- 🎨 System theme detection

---

## 🔒 Privacy & Security

MindMate AI takes privacy seriously:
- ✅ End-to-end encryption for sensitive data
- ✅ No third-party data sharing for ads
- ✅ GDPR-compliant data deletion
- ✅ Local secure storage for tokens
- ✅ Backend-only AI processing (no direct API calls from app)

### Safety Features
- 🚨 Crisis keyword detection
- 📞 Immediate access to crisis resources
- 🛡️ Content safety filters
- ⚠️ Clear disclaimers about non-medical nature

---

## 📖 Documentation

- [Product Specification](01-product-specification.md)
- [System Architecture](03-system-architecture.md)
- [Development Phases](08-development-phases.md)
- [Implementation Progress](IMPLEMENTATION_PROGRESS.md)
- [Tasks Tracker](tasks.md)

### API Documentation
API documentation will be available once Cloud Functions are deployed.

---

## 🤝 Contributing

This is currently a private project. Contribution guidelines will be added when the project goes public.

---

## 📋 Project Status

**Current Phase**: Phase 1 - Foundation (Week 1-2)  
**Status**: ✅ Foundation Complete - Ready for Firebase Setup

### Progress
- ✅ Project structure and dependencies
- ✅ Core utilities and theme system
- ✅ Navigation setup
- ✅ Error handling
- 🔄 Firebase integration (in progress)
- ⏳ Authentication flows (next)
- ⏳ Chat system (upcoming)
- ⏳ Mood tracking (upcoming)

See [tasks.md](tasks.md) for detailed task tracking.

---

## 📝 License

Proprietary - All rights reserved.  
This project is not open source and may not be used, copied, or distributed without explicit permission.

---

## 🙋 Support

For support, email support@mindmate-ai.com or visit our [Help Center](https://mindmate-ai.com/help).

### Crisis Resources
If you're in crisis, please reach out:
- **988 Suicide & Crisis Lifeline**: Call or text 988
- **Crisis Text Line**: Text HOME to 741741
- **Emergency**: Call 911

---

## 👥 Team

**Project Lead**: [Your Name]  
**Development**: [Team Members]  
**Design**: [Designer Names]

---

## 🏆 Acknowledgments

- Google Gemini API for AI capabilities
- Firebase for backend infrastructure
- Flutter community for amazing packages
- Mental health professionals for guidance

---

**Note**: This app is NOT a replacement for professional mental health care. Always consult qualified healthcare providers for medical advice.

---

*Last Updated: December 17, 2025*
