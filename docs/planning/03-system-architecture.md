# MindMate AI – System Architecture

## High-Level Architecture Diagram
```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER MOBILE APP                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐│
│  │   Auth   │  │   Chat   │  │   Mood   │  │      Settings        ││
│  │  Screen  │  │  Screen  │  │  Screen  │  │       Screen         ││
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────────┬───────────┘│
│       │             │             │                    │            │
│       └─────────────┴──────┬──────┴────────────────────┘            │
│                            │                                        │
│                   ┌────────▼────────┐                               │
│                   │  State Manager  │  (Riverpod)                   │
│                   │   + Services    │                               │
│                   └────────┬────────┘                               │
└────────────────────────────┼────────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GOOGLE CLOUD PLATFORM                            │
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────────────────────────┐  │
│  │     Firebase     │    │          Cloud Functions             │  │
│  │  Authentication  │    │  ┌────────────────────────────────┐  │  │
│  └────────┬─────────┘    │  │     /api/chat                  │  │  │
│           │              │  │  ┌──────────────────────────┐  │  │  │
│           │              │  │  │  1. Validate Auth Token  │  │  │  │
│           │              │  │  │  2. Rate Limit Check     │  │  │  │
│           │              │  │  │  3. Safety Filter        │──┼──┼──┼─► Crisis Response
│           │              │  │  │  4. Load Context Memory  │  │  │  │
│           │              │  │  │  5. Call Gemini API      │  │  │  │
│           │              │  │  │  6. Save to Firestore    │  │  │  │
│           │              │  │  │  7. Return Response      │  │  │  │
│           │              │  │  └──────────────────────────┘  │  │  │
│           │              │  └────────────────────────────────┘  │  │
│           │              │  ┌────────────────────────────────┐  │  │
│           │              │  │     /api/mood                  │  │  │
│           │              │  │     /api/analytics             │  │  │
│           │              │  │     /api/user                  │  │  │
│           │              │  └────────────────────────────────┘  │  │
│           │              └──────────────────┬───────────────────┘  │
│           │                                 │                      │
│           ▼                                 ▼                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                       FIRESTORE                              │  │
│  │  ┌─────────┐  ┌───────────┐  ┌─────────────┐  ┌───────────┐  │  │
│  │  │  users  │  │ moodLogs  │  │ chatHistory │  │  settings │  │  │
│  │  └─────────┘  └───────────┘  └─────────────┘  └───────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     GEMINI API                               │  │
│  │            (Called ONLY from Cloud Functions)                │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Frontend Responsibilities
- User interface rendering and animations
- Local state management
- Secure token storage (Flutter Secure Storage)
- Offline mood entry queueing
- Input validation (client-side)
- Navigation and routing
- Push notification handling

## Backend Responsibilities
- User authentication verification
- All AI interactions (Gemini API calls)
- Safety content filtering
- Data persistence (Firestore CRUD)
- Rate limiting and abuse protection
- Analytics aggregation
- Scheduled jobs (streak resets, weekly summaries)

## AI Flow & Safety Flow
```
User Message → Cloud Function
                    │
                    ▼
            ┌───────────────┐
            │ Safety Filter │
            │  (Keywords +  │
            │   Patterns)   │
            └───────┬───────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
   [SAFE]                  [CRISIS DETECTED]
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────────┐
│ Load Context  │       │ Return Crisis     │
│ (Last 10 msgs)│       │ Resources JSON    │
└───────┬───────┘       │ (No AI response)  │
        │               └──────────────────┘
        ▼
┌───────────────┐
│ Gemini API    │
│ + System      │
│   Prompt      │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│ Post-Filter   │
│ (Validate     │
│  response)    │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│ Save & Return │
└───────────────┘
```