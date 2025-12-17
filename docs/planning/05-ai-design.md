# MindMate AI – AI Design

## AI System Prompt
```
You are MindMate, a compassionate and supportive virtual wellness companion. Your role is to:

1. LISTEN with empathy and validate the user's feelings
2. REFLECT back what you hear to show understanding
3. GUIDE gently toward positive coping strategies when appropriate
4. ENCOURAGE self-care, professional help when needed, and healthy habits

STRICT BOUNDARIES:
- You are NOT a therapist, doctor, or medical professional
- NEVER diagnose conditions or suggest medications
- NEVER provide specific treatment advice
- If asked about diagnosis/treatment, kindly redirect to professional resources
- ALWAYS maintain a warm, non-judgmental tone

CONVERSATION STYLE:
- Use simple, clear language
- Ask open-ended questions to understand better
- Acknowledge emotions before offering suggestions
- Keep responses concise (2-4 sentences typically)
- Use the user's name occasionally for warmth

CONTEXT AWARENESS:
- Reference previous conversations when relevant
- Notice mood patterns and gently mention observations
- Remember user preferences and adjust accordingly

SAFETY PROTOCOL:
- If the user expresses self-harm or suicidal thoughts, you will NOT receive this message
- The system will handle crisis situations separately
- Focus on supportive, wellness-oriented conversations

Remember: You are a supportive friend, not a replacement for professional mental health care.
```

## Conversation Memory Strategy

**Approach: Sliding Window + Summary Hybrid**

1. **Immediate Context:** Last 10 messages from current session (full content)
2. **Session Summary:** AI-generated 2-3 sentence summary of each past session
3. **User Profile Context:** Key facts extracted over time (stored separately)
4. **Mood Context:** Last 7 days of mood scores with notes

**Why This Approach:**
- Balances token usage with context richness
- Summaries capture essence without token explosion
- Recent messages maintain conversational flow
- Mood context enables pattern-aware responses

**Token Budget Allocation:**
- System prompt: ~400 tokens
- User profile: ~100 tokens
- Session summaries (last 5): ~250 tokens
- Mood context: ~100 tokens
- Recent messages: ~800 tokens
- Current message + response: ~350 tokens
- **Total: ~2000 tokens per request**

## Safety Detection Logic

**Pre-AI Filter (Backend - Before Gemini Call)**

```
CRISIS_KEYWORDS = [
  "kill myself", "suicide", "end my life", "want to die",
  "self-harm", "hurt myself", "cutting myself", "overdose",
  "no reason to live", "better off dead", "goodbye forever"
]

CRISIS_PATTERNS = [
  r"(plan|planning|going) to (kill|hurt|end)",
  r"(bought|have) (pills|gun|rope|knife) for",
  r"(writing|wrote) (my|a) (suicide|goodbye) (note|letter)"
]

ESCALATION_PHRASES = [
  "I have a plan", "I've decided", "tonight", "today is the day"
]
```

**Detection Process:**
1. Normalize input (lowercase, remove special chars)
2. Check against keyword list (exact match)
3. Run regex patterns
4. Check escalation phrases
5. If ANY match → Block AI, return crisis response
6. Log event (anonymized) for safety review

## Fallback & Crisis Responses

**Crisis Response JSON:**
```json
{
  "type": "crisis_intervention",
  "aiResponseBlocked": true,
  "message": "I'm concerned about what you've shared. Your safety matters most right now. Please reach out to a crisis helpline where trained counselors are available 24/7.",
  "resources": [
    {
      "name": "National Suicide Prevention Lifeline",
      "phone": "988",
      "text": "Text HOME to 741741",
      "available": "24/7"
    },
    {
      "name": "Crisis Text Line",
      "phone": null,
      "text": "Text HELLO to 741741",
      "available": "24/7"
    },
    {
      "name": "International Association for Suicide Prevention",
      "url": "https://www.iasp.info/resources/Crisis_Centres/",
      "available": "Directory"
    }
  ],
  "followUp": "If you're in immediate danger, please call emergency services (911) or go to your nearest emergency room."
}
```

**AI Fallback Response (When Gemini Fails):**
```
"I'm having trouble responding right now, but I'm still here for you. 
Would you like to try again, or perhaps do a quick mood check-in instead?"
```