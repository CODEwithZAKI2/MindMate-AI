# MindMate AI – Data Models

## Users Collection (`/users/{userId}`)
```
{
  id: string (Firebase UID)
  email: string
  displayName: string
  createdAt: timestamp
  lastActiveAt: timestamp
  onboardingComplete: boolean
  disclaimerAcceptedAt: timestamp
  subscriptionTier: "free" | "premium"
  subscriptionExpiresAt: timestamp | null
  timezone: string
  preferredLanguage: string
  accountStatus: "active" | "suspended" | "deleted"
}
```

## Mood Logs Collection (`/users/{userId}/moodLogs/{logId}`)
```
{
  id: string
  userId: string
  moodScore: number (1-5)
  note: string | null (max 500 chars)
  tags: string[] (e.g., ["work", "sleep", "exercise"])
  createdAt: timestamp
  source: "manual" | "chat_derived"
}
```

## Chat History Collection (`/users/{userId}/chatHistory/{sessionId}`)
```
{
  id: string (session ID)
  userId: string
  startedAt: timestamp
  endedAt: timestamp | null
  messageCount: number
  messages: [
    {
      id: string
      role: "user" | "assistant" | "system"
      content: string
      timestamp: timestamp
      safetyFlagged: boolean
    }
  ]
  summary: string | null (AI-generated session summary)
  moodAtStart: number | null
  moodAtEnd: number | null
}
```

## User Preferences Collection (`/users/{userId}/preferences`)
```
{
  userId: string
  notifications: {
    dailyCheckIn: boolean
    dailyCheckInTime: string (HH:mm)
    weeklyInsights: boolean
    streakReminders: boolean
  }
  privacy: {
    analyticsEnabled: boolean
    chatHistoryRetentionDays: number (30 | 90 | 365)
  }
  wellness: {
    preferredExercises: string[]
    triggerTopics: string[] (topics to handle gently)
  }
  ui: {
    darkMode: boolean
    fontSize: "small" | "medium" | "large"
  }
}
```

## Crisis Events Collection (`/crisisEvents/{eventId}`) — Admin Only
```
{
  id: string
  userId: string
  detectedAt: timestamp
  triggerPhrase: string (hashed for privacy)
  resourcesShown: string[]
  followUpScheduled: boolean
}
```