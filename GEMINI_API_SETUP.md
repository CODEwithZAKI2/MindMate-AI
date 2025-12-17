# MindMate AI - Gemini API Setup

## Get Your API Key

1. **Sign in to AI Studio** (use your account with credits):
   - Visit: https://aistudio.google.com/app/apikey
   - Make sure you're using the correct Google account (top-right corner)
   - Click "Create API Key" → "Create API key in new project"
   - Copy the API key

2. **Set the API Key in Firebase Functions**:

```powershell
# Run this command in PowerShell (replace YOUR_API_KEY with actual key)
firebase functions:config:set gemini.api_key="YOUR_API_KEY_HERE"
```

3. **Verify the configuration**:

```powershell
firebase functions:config:get
```

You should see:
```json
{
  "gemini": {
    "api_key": "YOUR_API_KEY_HERE"
  }
}
```

## Deploy Cloud Functions

After setting the API key, deploy:

```powershell
cd functions
npm run deploy
```

Or from project root:
```powershell
firebase deploy --only functions
```

## Test the Setup

1. Run the Flutter app: `flutter run`
2. Sign in
3. Navigate to Chat screen
4. Send a message
5. The AI should respond!

## Troubleshooting

**If deployment fails with "quota exceeded":**
- Check you're using the API key from the account with credits
- Verify the key is correctly set: `firebase functions:config:get`

**If AI doesn't respond:**
- Check function logs: `firebase functions:log`
- Look for "Gemini API error" in logs
- Verify the API key has proper permissions in AI Studio

**Local Testing (optional):**
```powershell
# Set key as environment variable for local testing
$env:GEMINI_API_KEY="YOUR_API_KEY_HERE"

# Start emulators
cd functions
npm run serve
```

## Important Notes

- ✅ Firebase account and AI Studio account can be different
- ✅ The API key is just a string - doesn't matter which account created it
- ✅ Keep your API key secret - never commit it to git
- ✅ The key is stored in Firebase Functions config (encrypted)
