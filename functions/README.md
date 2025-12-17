# MindMate AI Cloud Functions

Firebase Cloud Functions for MindMate AI chat backend with Google Gemini AI integration.

## Features

- 🤖 **AI Chat Integration**: Uses Google Gemini 1.5 Flash for empathetic mental wellness conversations
- 🚨 **Crisis Detection**: Pre-AI keyword filtering for immediate crisis response
- 🔒 **Secure**: Authenticated-only access with user verification
- 📝 **Conversation History**: Maintains context with sliding window (last 10 messages)
- ⚡ **Real-time**: Messages saved to Firestore immediately

## Setup

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Set Gemini API Key

Get your API key from [Google AI Studio](https://aistudio.google.com/app/apikey), then:

```bash
firebase functions:config:set gemini.api_key="YOUR_API_KEY_HERE"
```

Or set it as an environment variable for local testing:

```bash
# Windows PowerShell
$env:GEMINI_API_KEY="YOUR_API_KEY_HERE"

# Linux/Mac
export GEMINI_API_KEY="YOUR_API_KEY_HERE"
```

### 3. Build TypeScript

```bash
npm run build
```

### 4. Deploy

```bash
npm run deploy
# or
firebase deploy --only functions
```

## API Endpoint

### `chat` - Process chat messages

**Input:**
```json
{
  "userId": "string",
  "sessionId": "string",
  "message": "string",
  "conversationHistory": [
    {
      "role": "user|assistant",
      "content": "string"
    }
  ]
}
```

**Output:**
```json
{
  "success": true,
  "message": "Message processed successfully",
  "aiResponse": "AI response text...",
  "isCrisis": false
}
```

## Crisis Detection

The function checks for crisis keywords before sending to AI:
- suicide
- kill myself
- end my life
- want to die
- self harm
- hurt myself
- overdose
- jump off
- no reason to live
- better off dead

When detected, it immediately returns crisis resources:
- National Suicide Prevention Lifeline: 988
- Crisis Text Line: Text HOME to 741741
- International: findahelpline.com

## Development

### Local Testing

```bash
npm run serve
# Starts Firebase emulators
```

### Watch Mode

```bash
npm run build:watch
# Auto-compiles TypeScript on changes
```

### Logs

```bash
npm run logs
# or
firebase functions:log
```

## Safety & System Prompt

The AI is configured with:
- **Temperature**: 0.9 (empathetic but focused)
- **Max Tokens**: 500 (concise responses)
- **Safety Settings**: Medium-high blocking for harassment, hate speech, explicit content
- **System Instructions**: Empathetic mental wellness companion with clear boundaries

The system prompt defines:
- ✅ Empathetic, warm, non-judgmental responses
- ✅ Active listening and validation
- ✅ Supportive guidance (not medical advice)
- ✅ Crisis recognition and appropriate responses
- ❌ NO diagnosis or prescriptions
- ❌ NO medical advice
- ❌ NO dismissing crisis expressions

## Architecture

```
functions/
├── src/
│   └── index.ts         # Main functions code
├── lib/                 # Compiled JavaScript (generated)
├── package.json         # Dependencies
├── tsconfig.json        # TypeScript config
└── .eslintrc.js         # Linting rules
```

## Error Handling

- **Unauthenticated**: Returns 401 if user not logged in
- **Invalid Arguments**: Returns 400 if required fields missing
- **Permission Denied**: Returns 403 if userId mismatch
- **Gemini API Error**: Returns fallback message with crisis resources
- **Firestore Error**: Logs error but doesn't block response

## Next Steps

1. Deploy functions: `npm run deploy`
2. Set Gemini API key: `firebase functions:config:set gemini.api_key="YOUR_KEY"`
3. Test from Flutter app
4. Monitor logs: `npm run logs`
5. Adjust safety settings as needed

## Support

For issues or questions, check Firebase Functions docs:
https://firebase.google.com/docs/functions
