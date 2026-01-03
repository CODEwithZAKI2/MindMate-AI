# Google Cloud Wavenet TTS Setup Guide

This guide explains how to set up Google Cloud Text-to-Speech (Wavenet) for natural, human-like voice output in MindMate AI.

## Why Google Cloud Wavenet?

- **Natural Human-Like Voices**: Wavenet uses deep neural networks to produce voices that sound more natural than traditional TTS
- **Perfect for Mental Wellness**: Warm, empathetic voice quality ideal for therapy/wellness conversations
- **Multiple Voice Options**: Choose from various voice personalities (warm, professional, friendly)
- **High Quality Audio**: Superior clarity and emotional expression

## Free Tier

Google Cloud offers a generous free tier:
- **4 million characters/month** for Wavenet voices
- **No credit card required** for free tier
- MindMate AI includes built-in usage tracking to help you stay within limits

## Setup Instructions

### Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Sign in with your Google account
3. Click **Select a project** → **New Project**
4. Name your project (e.g., "MindMate-TTS")
5. Click **Create**

### Step 2: Enable the Text-to-Speech API

1. In the Cloud Console, go to **APIs & Services** → **Library**
2. Search for "Cloud Text-to-Speech API"
3. Click on it and press **Enable**

### Step 3: Create API Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **API key**
3. Copy the generated API key
4. (Recommended) Click **Edit API key** to restrict it:
   - Under "API restrictions", select "Restrict key"
   - Choose "Cloud Text-to-Speech API"
   - Click **Save**

### Step 4: Configure in MindMate AI

#### Option A: Environment Variable (Recommended for Development)

Add to your `.env` file:
```
GOOGLE_CLOUD_TTS_API_KEY=your_api_key_here
```

#### Option B: In-App Configuration

1. Open MindMate AI
2. Go to **Settings** → **Voice Settings**
3. Tap **Configure Google Cloud TTS**
4. Enter your API key
5. The app will securely store it

## Voice Options

MindMate AI supports multiple Wavenet voices optimized for mental wellness:

### Recommended for Mental Wellness

| Voice | Description | Best For |
|-------|-------------|----------|
| `en-US-Neural2-F` | Warm female voice (default) | General therapy conversations |
| `en-US-Wavenet-F` | Natural female voice | Guided meditations |
| `en-US-Journey-F` | Calm, soothing female | Relaxation exercises |
| `en-US-Neural2-D` | Warm male voice | Users preferring male voice |
| `en-US-Journey-D` | Calm male voice | Sleep stories |

### All Available Voices

```dart
// Wavenet Voices (Most Natural)
'en-US-Wavenet-A' - Male, Deep
'en-US-Wavenet-B' - Male, Warm
'en-US-Wavenet-C' - Female, Bright
'en-US-Wavenet-D' - Male, Standard
'en-US-Wavenet-E' - Female, Gentle
'en-US-Wavenet-F' - Female, Warm (Recommended)
'en-US-Wavenet-G' - Female, Professional
'en-US-Wavenet-H' - Female, Friendly
'en-US-Wavenet-I' - Male, Professional
'en-US-Wavenet-J' - Male, Energetic

// Neural2 Voices (Latest Technology)
'en-US-Neural2-A' - Male, Deep
'en-US-Neural2-C' - Female, Bright
'en-US-Neural2-D' - Male, Warm
'en-US-Neural2-E' - Female, Calm
'en-US-Neural2-F' - Female, Warm (Default)
'en-US-Neural2-G' - Female, Professional
'en-US-Neural2-H' - Female, Friendly

// Journey Voices (Storytelling)
'en-US-Journey-D' - Male, Calming
'en-US-Journey-F' - Female, Soothing
```

## Usage Tracking

MindMate AI automatically tracks your character usage:

```dart
// Get usage statistics
final stats = await voiceCallService.getTtsUsageStats();
print('Used: ${stats['usedCharacters']} / ${stats['limit']}');
print('Remaining: ${stats['remainingCharacters']}');
```

### Usage Warnings

The app will notify you when:
- **90% used**: Warning to reduce usage
- **100% used**: Falls back to Flutter TTS (device voice)

## Fallback Behavior

If Google Cloud TTS is unavailable (no API key, quota exceeded, or network error), the app automatically falls back to Flutter TTS (device's built-in voice). This ensures the voice feature always works.

## Troubleshooting

### "API key not valid" Error
- Verify the API key is correct
- Check if the Text-to-Speech API is enabled
- Ensure no API key restrictions are blocking your app

### "Quota exceeded" Error
- Check your usage in Google Cloud Console
- Wait for the monthly reset
- Consider upgrading to a paid plan

### Voice Not Playing
- Check device volume
- Verify internet connection
- Check if another app is using audio

### Poor Audio Quality
- The default voice (Neural2-F) should sound natural
- If using Flutter TTS fallback, quality may be lower
- Ensure API key is configured correctly

## Cost Estimation

| Usage Level | Characters/Month | Cost |
|-------------|------------------|------|
| Free Tier | 0 - 4,000,000 | $0 |
| Light Use | 4M - 10M | ~$60 |
| Heavy Use | 10M - 50M | ~$300 |

For most personal users, the free tier is sufficient for daily conversations.

## Security Best Practices

1. **Never commit API keys** to version control
2. **Restrict API keys** to only the Text-to-Speech API
3. **Use secure storage** (MindMate uses flutter_secure_storage)
4. **Monitor usage** in Google Cloud Console

## API Reference

### VoiceCallService Methods

```dart
// Initialize TTS (auto-detects best engine)
await voiceCallService.initTts(googleCloudApiKey: 'your_key');

// Set API key later
await voiceCallService.setGoogleCloudApiKey('your_key');

// Check which engine is active
print(voiceCallService.activeTtsEngine); // googleCloudWavenet or flutterTts

// Get usage stats
final stats = await voiceCallService.getTtsUsageStats();

// Change voice
voiceCallService.setPreferredVoice('en-US-Wavenet-F');

// Speak text
await voiceCallService.speak('Hello, how are you feeling today?');

// Stop speaking
await voiceCallService.stopSpeaking();
```

## Support

If you encounter issues:
1. Check the [Google Cloud TTS Documentation](https://cloud.google.com/text-to-speech/docs)
2. Review the troubleshooting section above
3. Check app logs for detailed error messages

---

*Last updated: 2024*
