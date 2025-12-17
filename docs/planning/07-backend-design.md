# MindMate AI – Backend Design

## Cloud Functions Responsibilities

| Function | Trigger | Purpose |
|----------|---------|---------|
| `sendChatMessage` | HTTP POST | Process user message, safety check, call Gemini, return response |
| `logMood` | HTTP POST | Validate and store mood entry |
| `getMoodTrends` | HTTP GET | Calculate and return mood analytics |
| `generateWeeklySummary` | Scheduled (weekly) | Create AI-generated weekly insights |
| `deleteUserData` | HTTP DELETE | GDPR-compliant data deletion |
| `onUserCreate` | Firestore trigger | Initialize user preferences, send welcome |
| `checkStreaks` | Scheduled (daily) | Update streak counts, trigger notifications |

## API Endpoints
```
BASE_URL: https://{region}-{project}.cloudfunctions.net/api

Authentication: Bearer token (Firebase ID Token)

POST   /chat/message
       Body: { sessionId, message }
       Response: { messageId, content, timestamp } | { crisis: true, resources: [...] }

GET    /chat/sessions
       Query: ?limit=20&before={timestamp}
       Response: { sessions: [...] }

GET    /chat/sessions/{sessionId}
       Response: { session: {...}, messages: [...] }

POST   /mood
       Body: { moodScore, note?, tags? }
       Response: { logId, createdAt }

GET    /mood/logs
       Query: ?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD
       Response: { logs: [...] }

GET    /mood/trends
       Query: ?period=week|month|quarter
       Response: { average, trend, insights }

GET    /user/profile
       Response: { user: {...} }

PATCH  /user/profile
       Body: { displayName?, timezone?, ... }
       Response: { user: {...} }

DELETE /user/account
       Response: { scheduled: true, deleteAt: timestamp }

GET    /user/preferences
       Response: { preferences: {...} }

PATCH  /user/preferences
       Body: { notifications?: {...}, privacy?: {...}, ... }
       Response: { preferences: {...} }
```

## Security Rules (Firestore)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /moodLogs/{logId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /chatHistory/{sessionId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        // Write only through Cloud Functions
        allow write: if false;
      }
      
      match /preferences {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Crisis events - no direct client access
    match /crisisEvents/{eventId} {
      allow read, write: if false;
    }
    
    // Admin collection
    match /admin/{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Rate Limiting & Abuse Protection

| Endpoint | Limit | Window | Action on Exceed |
|----------|-------|--------|------------------|
| `/chat/message` | 30 requests | 1 hour | 429 + 15min cooldown |
| `/mood` | 10 requests | 1 hour | 429 + soft block |
| `/user/*` | 60 requests | 1 hour | 429 |
| Global per user | 200 requests | 1 hour | Temporary suspension |

**Implementation:**
- Use Firebase Realtime Database for fast rate limit counters
- Store: `rateLimits/{userId}/{endpoint}` with TTL
- Cloud Function middleware checks before processing

**Abuse Detection:**
- Flag accounts with repeated crisis triggers (for human review)
- Detect spam patterns (copy-paste, rapid identical messages)
- Monitor for prompt injection attempts
- Log suspicious activity for security review