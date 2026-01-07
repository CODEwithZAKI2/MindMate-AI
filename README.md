# MindMate AI 🧠💚

> Your compassionate mental wellness companion powered by AI

**MindMate AI** is a cross-platform Flutter mobile application providing accessible, private mental wellness support through empathetic AI conversations, real-time voice calls, mood tracking, AI-powered journaling, and personalized wellness tools.

[![Flutter Version](https://img.shields.io/badge/Flutter-3.29.3-02569B?logo=flutter)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.7.2-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Functions-FFCA28?logo=firebase)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/AI-Gemini%202.0%20Flash-4285F4?logo=google)](https://ai.google.dev)
[![License](https://img.shields.io/badge/License-Proprietary-red)]()

---

## 🌟 Features

### 🎤 AI Voice Call System ✨ NEW
- **Real-time Voice Conversations** - Talk naturally with your AI wellness companion
- **Google Cloud TTS Integration** - Neural2 voices for natural-sounding responses
- **Animated Wave Visualizer** - Beautiful visual feedback during calls
- **Performance Optimized** - Sentence-based parallel streaming (latency: 30s → 3s)
- **Transcript Saving** - Full conversation saved to chat history after call ends
- **Session Continuity** - Continue any chat conversation in voice mode seamlessly
- **Context-Aware Greetings** - AI greets you based on your recent conversations

### 💬 AI Wellness Chat
- **Empathetic Conversations** - Powered by Gemini 2.0 Flash with therapy-style prompting
- **Auto-Generated Titles** - AI automatically names conversations for easy reference
- **Context Memory** - Last 10 messages + session summaries for continuity
- **User Profile Awareness** - AI uses your name and preferences
- **Mood Context Integration** - AI knows your recent mood patterns (last 7 days)
- **Journal Awareness** - AI references your journal entries for deeper personalization
- **Message Management** - Copy, timestamps, scroll-to-bottom, typing indicators
- **WhatsApp-Style Offline Queue** - Messages queue offline with pending icons, auto-resend on reconnect

### 📝 AI-Powered Journaling
- **Guided Prompts** - AI-generated writing prompts based on your mood
- **Free Writing Mode** - Open-ended journaling space
- **Entry Analysis** - AI-powered insights on journal entries
- **Journal Context for AI** - AI references your journal entries in conversations
- **Date-Based Organization** - Easy navigation through past entries
- **Full-Text Search** - Find entries by content (coming soon)

### 📊 Mood Tracking & Analytics
- **Daily Check-ins** - 5-point scale with emotion tags and notes
- **7-Day History View** - Visual mood trends
- **Monthly Calendar View** - Color-coded mood patterns
- **Streak Tracking** - Gamified consistency encouragement
- **Mood Analytics** - Charts showing mood distribution over time
- **AI Integration** - Mood data automatically shared with AI for context

### 🚨 Crisis Detection & Safety System
- **Real-time Keyword Detection** - Backend-powered crisis recognition
- **Immediate Resources** - Crisis hotlines displayed when needed
- **Regional Localization** - 8 countries with localized resources (US, CA, GB, AU, NZ, IE, IN, ZA)
- **Timezone Detection** - Automatic localization based on user timezone
- **Safety Banners** - "Help is Available" banner on crisis responses
- **Event Logging** - Crisis events logged for safety review
- **AI Blocking** - AI blocked during active crisis, resources shown instead

### 🔐 Secure Authentication
- **Email/Password** - Traditional sign-up/login
- **Google Sign-In** - One-tap authentication
- **Apple Sign-In** - iOS native authentication (coming soon)
- **Onboarding Flow** - 4-page guided introduction
- **Age Verification** - 18+ age gate with disclaimer
- **Session Management** - Secure token handling with flutter_secure_storage

### ⚙️ User Settings & Preferences
- **Profile Management** - Name, avatar, preferences
- **Notification Settings** - Customizable reminders
- **Data Export** - Download your data
- **Account Deletion** - GDPR-compliant data removal

---

## 🏗️ Architecture

MindMate AI follows **Clean Architecture** principles with a clear separation of concerns:

```
lib/
├── core/           # Shared utilities, constants, theme, error handling
├── data/           # Data sources, models, repositories (Firestore)
├── domain/         # Business logic, entities, use cases
├── presentation/   # UI, screens, widgets, Riverpod providers
└── l10n/           # Internationalization
```

### State Management
- **Riverpod 2.x** - Compile-safe dependency injection and state management
- **Provider Pattern** - Repository providers, state notifiers, async providers
- **Reactive UI** - Automatic rebuilds on state changes

### Backend Architecture
- **Firebase Cloud Functions** (Node.js 20, TypeScript)
  - `generateAIResponse()` - Main AI chat endpoint
  - `generateSessionTitle()` - Auto-generates conversation titles
  - `fetchJournalContext()` - Retrieves journal entries for AI context
  - `generateJournalPrompt()` - Creates personalized journal prompts
  - `analyzeJournalEntry()` - AI-powered journal insights
  
### Tech Stack
| Category | Technology |
|----------|------------|
| **Frontend** | Flutter 3.29.3 + Dart 3.7.2 |
| **UI Framework** | Material Design 3 |
| **State Management** | Riverpod 2.x |
| **Backend** | Firebase (Auth, Firestore, Functions, Storage) |
| **AI Model** | Google Gemini 2.0 Flash API |
| **Voice Synthesis** | Google Cloud Text-to-Speech (Neural2) |
| **Navigation** | GoRouter with auth guards |
| **Typography** | Google Fonts (Inter) |
| **Security** | flutter_secure_storage, Firebase Security Rules |

---

## ⚡ Performance Optimizations

### Voice Call Latency Optimization
```
Before: User speaks → Full response generated → Full audio synthesized → Playback
Result: ~30 second delay

After: User speaks → Stream sentences → Parallel TTS synthesis → Immediate playback
Result: ~3 second delay (10x improvement)
```

### Chat System Optimizations
- **Efficient Pagination** - Load messages on demand
- **Offline-First** - Messages queued locally, synced when online
- **Optimistic Updates** - Instant UI feedback before server confirmation
- **Message Deduplication** - Prevent duplicate sends on retry

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.29.3 or higher
- Dart 3.7.2 or higher
- Android Studio / VS Code with Flutter extension
- Firebase project (see setup instructions)
- Google Cloud project with TTS API enabled (for voice calls)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/CODEwithZAKI2/MindMate-AI.git
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
   - Deploy Cloud Functions: `cd functions && npm run deploy`

4. **Set up Gemini API** (Required)
   - Get API key from [Google AI Studio](https://aistudio.google.com)
   - Add to Firebase Functions config

5. **Set up Google Cloud TTS** (For Voice Calls)
   - Enable Text-to-Speech API in Google Cloud Console
   - Download service account JSON
   - See `docs/GOOGLE_CLOUD_TTS_SETUP.md` for details

6. **Run the app**
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

**Current Phase**: Phase 3 - Advanced Features  
**Status**: ✅ Core Features Complete - Voice Calls, Journaling, Analytics

### Development Progress
| Feature | Status |
|---------|--------|
| Authentication System | ✅ Complete |
| AI Chat with Memory | ✅ Complete |
| Voice Call System | ✅ Complete |
| Mood Tracking & Analytics | ✅ Complete |
| AI Journaling | ✅ Complete |
| Crisis Detection & Safety | ✅ Complete |
| Auto-Generated Titles | ✅ Complete |
| Session Continuity | ✅ Complete |
| Offline Message Queue | ✅ Complete |
| Premium Features | 🔄 In Progress |

### Coming Soon
- 🎯 Premium subscription tier
- 🧘 Guided breathing exercises
- 🔔 Smart wellness reminders
- 🌍 Multi-language support

See [tasks.md](docs/planning/tasks.md) for detailed task tracking.

---

## 📝 License

Proprietary - All rights reserved.  
This project is not open source and may not be used, copied, or distributed without explicit permission.

---

## 🙋 Support

For support, email engomar@163.com.



## 👥 Team

**Project Lead**: Omar 马文彬  
**Development**: Omar 马文彬  
**Design**: Omar 马文彬

---

## 🏆 Acknowledgments

- Google Gemini API for AI capabilities
- Google Cloud Text-to-Speech for voice synthesis
- Firebase for backend infrastructure
- Flutter community for amazing packages
- Mental health professionals for guidance

---

**Note**: This app is NOT a replacement for professional mental health care. Always consult qualified healthcare providers for medical advice.

---

*Last Updated: January 7, 2026*
