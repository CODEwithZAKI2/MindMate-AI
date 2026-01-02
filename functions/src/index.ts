import * as admin from "firebase-admin";
import {
  GoogleGenerativeAI,
  HarmCategory,
  HarmBlockThreshold,
} from "@google/generative-ai";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

// Initialize Firebase Admin
admin.initializeApp();

// Define secret for Gemini API key
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// Crisis keywords for pre-AI filtering
const CRISIS_KEYWORDS = [
  "suicide",
  "suicidal",
  "kill myself",
  "end my life",
  "want to die",
  "wanna die",
  "self harm",
  "self-harm",
  "cutting myself",
  "hurt myself",
  "harming myself",
  "overdose",
  "jump off",
  "no reason to live",
  "better off dead",
  "don't want to live",
  "ending it all",
  "take my own life",
];

// Safety system prompt for Gemini
const SYSTEM_PROMPT = `You are MindMate, a compassionate AI companion focused on mental wellness support. I was created by a team of engineers and researchers at Taabo Tech. My purpose is to provide supportive listening and gentle guidance. Taabo Tech founded by two Engineers from Somalia named Eng.Omar Mohamud Mohamed Fidow and Eng. Abdulhakim Ali Hassan, with mission to improve mental health through technology.

Core Guidelines:
1. Be empathetic, warm, and non-judgmental
2. Listen actively and validate feelings
3. Ask open-ended questions to encourage reflection
4. Provide supportive guidance, not medical advice
5. Recognize crisis situations and respond appropriately
6. You are allowed to speak the language of the user as needed

Crisis Protocol:
- If user expresses suicidal thoughts or self-harm: Respond with immediate concern and provide region-specific crisis resources
- Use the user's timezone information to provide accurate local crisis hotlines and emergency services
- If timezone is unavailable or unrecognized, default to United States resources (988 Suicide & Crisis Lifeline, Text "HELLO" to 741741, Emergency: 911)
- Provide the country name, primary suicide prevention hotline, text line (if available), emergency number, and 2-3 additional local resources
- Format crisis resources clearly with proper contact numbers
- Never dismiss or minimize crisis expressions
- Always flag crisis situations for human review

Boundaries:
- You are NOT a therapist or medical professional
- Do NOT diagnose mental health conditions
- Do NOT prescribe medications or treatments
- Suggest professional help when appropriate

Response Style:
- Keep responses conversational and warm (2-4 sentences usually)
- Use simple, accessible language
- Show empathy through understanding, not pity
- Encourage small, actionable steps
- Celebrate progress and positive changes

Remember: Your goal is to provide supportive listening and gentle guidance while recognizing when professional help is needed.`;

interface ChatRequest {
  userId: string;
  sessionId: string;
  message: string;
  conversationHistory?: Array<{ role: string; content: string }>;
  userTimezone?: string; // User's timezone name (e.g., "Asia/Shanghai")
}

interface ChatResponse {
  success: boolean;
  message?: string;
  aiResponse?: string;
  isCrisis?: boolean;
  error?: string;
}

/**
 * Checks if message contains crisis keywords
 */
function detectCrisis(message: string): boolean {
  const lowerMessage = message.toLowerCase();
  return CRISIS_KEYWORDS.some((keyword) => lowerMessage.includes(keyword));
}

/**
 * Generate AI response using Gemini
 */
async function generateAIResponse(
  userMessage: string,
  conversationHistory: Array<{ role: string; content: string }>,
  apiKey: string,
  userName?: string,
  sessionSummaries?: string[],
  moodContext?: string,
  userTimezone?: string
): Promise<string> {
  try {
    console.log("[generateAIResponse] Starting with message:", userMessage.substring(0, 50));
    // Initialize Gemini with the provided API key
    const genAI = new GoogleGenerativeAI(apiKey);
    console.log("[generateAIResponse] GenAI initialized");

    // Build contextual prompt with user name and session summaries
    let contextualPrompt = SYSTEM_PROMPT;

    // Add user context if available
    if (userName) {
      contextualPrompt += `\n\nUser Profile Context:\n- User's name: ${userName}\n- Use their name occasionally for warmth and personalization`;
    }

    // Add session summaries for memory continuity
    if (sessionSummaries && sessionSummaries.length > 0) {
      contextualPrompt += `\n\nPrevious Conversation Context (Recent Sessions):\n`;
      sessionSummaries.forEach((summary, index) => {
        contextualPrompt += `${index + 1}. ${summary}\n`;
      });
      contextualPrompt += `\nUse this context to maintain continuity and reference past discussions when relevant.`;
    }

    // Add mood context if available
    if (moodContext) {
      contextualPrompt += `\n\nRecent Mood Context (last 7 days):\n${moodContext}\nUse this to tailor guidance to the user's recent emotional state. Be gentle if mood is declining.`;
    }

    // Add timezone for crisis resource localization
    if (userTimezone) {
      console.log("[generateAIResponse] Adding timezone context:", userTimezone);
      contextualPrompt += `\n\nUser Location Context:\n- Timezone: ${userTimezone}\n- When providing crisis resources, use accurate local hotlines and emergency numbers for this timezone/region.`;
    } else {
      console.log("[generateAIResponse] No timezone provided, will use US default");
    }

    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      systemInstruction: contextualPrompt,
      generationConfig: {
        temperature: 0.9,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 500,
      },
      safetySettings: [
        {
          category: HarmCategory.HARM_CATEGORY_HARASSMENT,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
        {
          category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
        {
          category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
        {
          category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
          threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH,
        },
      ],
    });

    // Build chat history - ensure it starts with user message
    let history = conversationHistory.slice(-10).map((msg) => ({
      role: msg.role === "user" ? "user" : "model",
      parts: [{ text: msg.content }],
    }));

    // Gemini requires history to start with a user message
    // If first message is from model, remove it
    if (history.length > 0 && history[0].role === "model") {
      console.log("[generateAIResponse] Removing leading model message from history");
      history = history.slice(1);
    }

    // If history ends with a user message (which will be repeated), remove it
    if (history.length > 0 && history[history.length - 1].role === "user") {
      console.log("[generateAIResponse] Removing trailing user message from history");
      history = history.slice(0, -1);
    }

    const chat = model.startChat({ history });
    console.log("[generateAIResponse] Sending message to Gemini...");
    const result = await chat.sendMessage(userMessage);
    console.log("[generateAIResponse] Got result from Gemini");
    const response = result.response;

    return response.text();
  } catch (error) {
    console.error("Gemini API error:", error);
    return "I'm having trouble connecting right now. Please try again in a moment. " +
      "If you need immediate support, please reach out to a crisis helpline.";
  }
}

/**
 * Chat message endpoint
 * Handles incoming chat messages and returns AI responses
 */
export const chat = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request): Promise<ChatResponse> => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to send messages"
      );
    }

    const { userId, sessionId, message, conversationHistory = [], userTimezone } = request.data as ChatRequest;
    console.log("[chat] Received request for user:", userId, "session:", sessionId);
    console.log("[chat] User timezone received:", userTimezone || "NOT PROVIDED");

    // Validate inputs
    if (!userId || !sessionId || !message) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: userId, sessionId, or message"
      );
    }

    // Verify user matches authenticated user
    if (request.auth.uid !== userId) {
      throw new HttpsError(
        "permission-denied",
        "User ID does not match authenticated user"
      );
    }

    try {
      // Fetch user profile and session summaries for context
      console.log("[chat] Fetching user profile, summaries, and mood context...");
      let userName: string | undefined;
      let sessionSummaries: string[] = [];
      let moodContext: string | undefined;

      try {
        const userDoc = await admin.firestore()
          .collection("users")
          .doc(userId)
          .get();
        if (userDoc.exists) {
          userName = userDoc.data()?.displayName;
          console.log("[chat] User name fetched:", userName);
        }
      } catch (err) {
        console.error("[chat] Error fetching user profile:", err);
        // Continue without user name if fetch fails
      }

      // Fetch recent session summaries for better context
      try {
        sessionSummaries = await fetchRecentSessionSummaries(userId, sessionId, 5);
        console.log("[chat] Fetched", sessionSummaries.length, "session summaries");
      } catch (err) {
        console.error("[chat] Error fetching session summaries:", err);
        // Continue without summaries if fetch fails
      }

      // Fetch recent mood logs for context
      try {
        moodContext = await fetchRecentMoodContext(userId, 7, 7);
        if (moodContext) {
          console.log("[chat] Mood context prepared");
        }
      } catch (err) {
        console.error("[chat] Error fetching mood context:", err);
        // Continue without mood context if fetch fails
      }

      // Generate AI response with enhanced context including timezone
      console.log("[chat] Calling generateAIResponse with timezone:", userTimezone || "NOT PROVIDED");
      const aiResponse = await generateAIResponse(
        message,
        conversationHistory,
        geminiApiKey.value(),
        userName,
        sessionSummaries,
        moodContext,
        userTimezone
      );
      console.log("[chat] Got AI response:", aiResponse.substring(0, 50));

      // Check if AI detected crisis (simple keyword check in response)
      const isCrisis = detectCrisis(message);

      // Log crisis events for monitoring
      if (isCrisis) {
        admin.firestore().collection("crisis_logs").add({
          userId,
          sessionId,
          message,
          aiResponse: aiResponse.substring(0, 200),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          timezone: userTimezone || "unknown",
        }).catch((err) => console.error("Crisis log error:", err));
      }

      // Save messages to chat_sessions document as array
      const sessionRef = admin.firestore()
        .collection("chat_sessions")
        .doc(sessionId);

      // Use JavaScript Date for consistent UTC timestamp
      const now = admin.firestore.Timestamp.fromDate(new Date());

      // Only save AI response (user message already saved by Flutter for immediate display)
      await sessionRef.update({
        messages: admin.firestore.FieldValue.arrayUnion({
          role: "assistant",
          content: aiResponse,
          timestamp: now,
          safetyFlagged: false,
        }),
        messageCount: admin.firestore.FieldValue.increment(1),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Check if we should generate a summary (after 10+ messages)
      const sessionDoc = await sessionRef.get();
      const sessionData = sessionDoc.data();
      const messageCount = sessionData?.messageCount || 0;

      // Generate summary after 10 messages if not already summarized
      if (messageCount >= 10 && sessionData && !sessionData.summary && sessionData.messages) {
        console.log("[chat] Triggering summary generation for session:", sessionId);
        // Trigger summary generation asynchronously (don't wait for it)
        generateSessionSummary(sessionId, sessionData.messages, geminiApiKey.value())
          .catch((error) => console.error("Summary generation error:", error));
      }

      return {
        success: true,
        message: "Message processed successfully",
        aiResponse,
        isCrisis,
      };
    } catch (error: unknown) {
      console.error("Chat function error:", error);
      const errorMessage = error instanceof Error ? error.message : "Unknown error";
      return {
        success: false,
        error: errorMessage,
      };
    }
  }
);

/**
 * Generate a summary of a chat session using Gemini AI
 */
async function generateSessionSummary(
  sessionId: string,
  messages: Array<{ role: string; content: string; timestamp: any }>,
  apiKey: string
): Promise<void> {
  try {
    console.log("[generateSessionSummary] Starting for session:", sessionId);

    // Format conversation for summarization
    const conversationText = messages
      .map((msg) => `${msg.role === "user" ? "User" : "AI"}: ${msg.content}`)
      .join("\n\n");

    // Use Gemini to generate a concise summary
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      generationConfig: {
        temperature: 0.3, // Lower temperature for more factual summaries
        maxOutputTokens: 150, // Keep summary concise (~2-3 sentences)
      },
    });

    const prompt = `Summarize the following mental health support conversation in 2-3 sentences. Focus on the main topics discussed, user's emotional state, and key insights or progress. Be concise and factual.

Conversation:
${conversationText}

Summary:`;

    const result = await model.generateContent(prompt);
    const summary = result.response.text().trim();

    console.log("[generateSessionSummary] Generated summary:", summary.substring(0, 100));

    // Save summary to Firestore
    await admin.firestore()
      .collection("chat_sessions")
      .doc(sessionId)
      .update({
        summary: summary,
        summarizedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log("[generateSessionSummary] Summary saved successfully");
  } catch (error) {
    console.error("[generateSessionSummary] Error:", error);
    throw error;
  }
}

/**
 * Fetch recent session summaries for context
 */
async function fetchRecentSessionSummaries(
  userId: string,
  currentSessionId: string,
  limit: number = 5
): Promise<string[]> {
  try {
    const sessionsSnapshot = await admin.firestore()
      .collection("chat_sessions")
      .where("userId", "==", userId)
      .where("summary", "!=", null)
      .orderBy("summary") // Required for != null query
      .orderBy("startedAt", "desc")
      .limit(limit + 1) // Get one extra to filter out current session
      .get();

    const summaries: string[] = [];

    sessionsSnapshot.docs.forEach((doc) => {
      // Skip current session
      if (doc.id === currentSessionId) return;

      const data = doc.data();
      if (data.summary && summaries.length < limit) {
        summaries.push(data.summary);
      }
    });

    return summaries;
  } catch (error) {
    console.error("[fetchRecentSessionSummaries] Error:", error);
    return [];
  }
}

/**
 * Fetch recent mood context for last N days
 */
async function fetchRecentMoodContext(
  userId: string,
  days: number = 7,
  limit: number = 7
): Promise<string | undefined> {
  try {
    const since = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - days * 24 * 60 * 60 * 1000)
    );

    const snapshot = await admin.firestore()
      .collection("mood_logs")
      .where("userId", "==", userId)
      .where("createdAt", ">=", since)
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    if (snapshot.empty) return undefined;

    const entries: Array<{ score: number; createdAt: Date; note?: string; tags?: string[] }> = snapshot.docs.map((doc) => {
      const data = doc.data() as Record<string, any>;
      return {
        score: data.moodScore as number,
        createdAt: (data.createdAt as admin.firestore.Timestamp).toDate(),
        note: data.note as string | undefined,
        tags: (data.tags as string[] | undefined) ?? [],
      };
    });

    const scores = entries.map((e) => e.score);
    const avg = (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(1);
    const latest = entries[0];
    const oldest = entries[entries.length - 1];
    const trendDelta = latest.score - oldest.score;
    const trend = trendDelta > 0 ? "improving" : trendDelta < 0 ? "declining" : "steady";

    // Build compact lines (max ~7 entries)
    const lines = entries.slice(0, limit).map((e) => {
      const date = e.createdAt.toISOString().split("T")[0];
      const noteText = e.note && e.note.trim().length > 0
        ? ` | note: ${e.note.substring(0, 40)}${e.note.length > 40 ? "..." : ""}`
        : "";
      const tagsText = e.tags && e.tags.length > 0
        ? ` | tags: ${e.tags.join(", ")}`
        : "";
      return `- ${date}: ${e.score}/5${noteText}${tagsText}`;
    });

    return [
      `Avg: ${avg}/5, Latest: ${latest.score}/5 on ${latest.createdAt.toISOString().split("T")[0]}, Trend: ${trend}`,
      ...lines,
    ].join("\n");
  } catch (error) {
    console.error("[fetchRecentMoodContext] Error:", error);
    return undefined;
  }
}

// ================== JOURNAL AI FUNCTIONS ==================

interface JournalReflectionRequest {
  entryId: string;
  content: string;
  userId: string;
  voiceTranscript?: string;
}

interface JournalReflectionResponse {
  success: boolean;
  safe: boolean;
  reflection?: {
    toneSummary: string;
    reflectionQuestions: string[];
  };
  crisisResponse?: string;
  error?: string;
}

/**
 * Generate AI reflection for journal entry
 * Runs crisis detection before processing
 */
export const generateJournalReflection = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request): Promise<JournalReflectionResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { entryId, content, userId, voiceTranscript } = request.data as JournalReflectionRequest;

    if (!entryId || !content || !userId) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    if (request.auth.uid !== userId) {
      throw new HttpsError("permission-denied", "User ID mismatch");
    }

    // Minimum content length for reflection (unless voice transcript exists)
    const totalContentLength = content.length + (voiceTranscript?.length ?? 0);
    if (totalContentLength < 50) {
      return {
        success: true,
        safe: true,
        reflection: undefined, // No reflection for short entries
      };
    }

    try {
      // SAFETY CHECK: Detect crisis before AI processing
      const combinedContent = voiceTranscript ? `${content}\n\nVoice Note: ${voiceTranscript}` : content;
      const isCrisis = detectCrisis(combinedContent);

      if (isCrisis) {
        console.log("[generateJournalReflection] Crisis detected for entry:", entryId);

        // Log crisis event
        await admin.firestore().collection("crisis_logs").add({
          userId,
          source: "journal",
          entryId,
          content: content.substring(0, 200),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update entry with safety flags
        await admin.firestore().collection("journal_entries").doc(entryId).update({
          safetyFlags: {
            crisisDetected: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        });

        return {
          success: true,
          safe: false,
          crisisResponse: "We noticed you might be going through a difficult time. " +
            "You're not alone, and support is available. " +
            "If you need someone to talk to, please reach out to a trusted person or crisis helpline.",
        };
      }

      // Generate AI reflection
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 200,
        },
      });

      // Build content including voice transcript if available
      const entryContent = voiceTranscript
        ? `Written Entry: ${content}\n\nVoice Note Transcript: ${voiceTranscript}`
        : content;

      const prompt = `You are a supportive, non-clinical wellness companion.
The user just wrote a journal entry${voiceTranscript ? ' (which includes a voice note transcript)' : ''}. Provide:
1. A brief emotional tone summary (1 sentence, max 20 words)
2. 1-2 gentle reflection questions to encourage self-awareness

Rules:
- Never diagnose or label mental conditions
- Use warm, encouraging language
- Avoid assumptions about their situation
- Be compassionate and supportive
- Consider both written and spoken content equally

Entry Content:
${entryContent}

Respond in this exact JSON format:
{
  "toneSummary": "...",
  "reflectionQuestions": ["...", "..."]
}`;

      const result = await model.generateContent(prompt);
      const responseText = result.response.text();

      // Parse JSON response
      let reflection;
      try {
        const jsonMatch = responseText.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          reflection = JSON.parse(jsonMatch[0]);
        } else {
          throw new Error("No JSON found in response");
        }
      } catch (parseError) {
        console.error("[generateJournalReflection] Parse error:", parseError);
        // Fallback: create generic reflection
        reflection = {
          toneSummary: "Thank you for sharing your thoughts today.",
          reflectionQuestions: ["What stood out to you most as you wrote?"],
        };
      }

      // Save reflection to Firestore
      await admin.firestore().collection("journal_entries").doc(entryId).update({
        aiReflection: {
          toneSummary: reflection.toneSummary,
          reflectionQuestions: reflection.reflectionQuestions,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        safetyFlags: {
          crisisDetected: false,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      return {
        success: true,
        safe: true,
        reflection: {
          toneSummary: reflection.toneSummary,
          reflectionQuestions: reflection.reflectionQuestions,
        },
      };
    } catch (error) {
      console.error("[generateJournalReflection] Error:", error);
      return {
        success: false,
        safe: true,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }
);

interface SmartPromptsRequest {
  userId: string;
}

interface SmartPromptsResponse {
  success: boolean;
  prompts?: Array<{ category: string; prompt: string }>;
  error?: string;
}

/**
 * Generate contextual journaling prompts based on user's mood and history
 */
export const generateSmartPrompts = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request): Promise<SmartPromptsResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { userId } = request.data as SmartPromptsRequest;

    if (request.auth.uid !== userId) {
      throw new HttpsError("permission-denied", "User ID mismatch");
    }

    try {
      // Fetch recent mood context
      const moodContext = await fetchRecentMoodContext(userId, 7, 5);

      // Get time of day
      const hour = new Date().getHours();
      const timeOfDay = hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening";

      // Use Gemini to generate personalized prompts
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        generationConfig: {
          temperature: 0.8,
          maxOutputTokens: 300,
        },
      });

      let contextInfo = `Time: ${timeOfDay}`;
      if (moodContext) {
        contextInfo += `\nRecent mood data:\n${moodContext}`;
      }

      const prompt = `Generate 4 personalized journaling prompts for a mental wellness app user.

Context:
${contextInfo}

Categories to cover:
1. gratitude - Something to appreciate
2. reflection - Looking back on experiences  
3. reframing - Finding positive perspectives
4. self_compassion - Being kind to oneself

Rules:
- Each prompt should be 1 question, max 15 words
- Be warm and encouraging
- If mood is low, focus on gentle, supportive prompts
- If mood is good, encourage celebrating wins

Respond in this exact JSON format:
[
  {"category": "gratitude", "prompt": "..."},
  {"category": "reflection", "prompt": "..."},
  {"category": "reframing", "prompt": "..."},
  {"category": "self_compassion", "prompt": "..."}
]`;

      const result = await model.generateContent(prompt);
      const responseText = result.response.text();

      let prompts;
      try {
        const jsonMatch = responseText.match(/\[[\s\S]*\]/);
        if (jsonMatch) {
          prompts = JSON.parse(jsonMatch[0]);
        } else {
          throw new Error("No JSON array found");
        }
      } catch (parseError) {
        // Fallback prompts
        prompts = [
          { category: "gratitude", prompt: "What's one small thing you're grateful for today?" },
          { category: "reflection", prompt: "What moment stood out to you today?" },
          { category: "reframing", prompt: "What's one thing that went better than expected?" },
          { category: "self_compassion", prompt: "What would you tell a friend feeling this way?" },
        ];
      }

      return {
        success: true,
        prompts,
      };
    } catch (error) {
      console.error("[generateSmartPrompts] Error:", error);
      return {
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }
);

interface ReframeRequest {
  userId: string;
  text: string;
}

interface ReframeResponse {
  success: boolean;
  reframed?: string;
  error?: string;
}

/**
 * Reframe journal text with CBT-inspired perspective
 */
export const reframeJournalText = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request): Promise<ReframeResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { userId, text } = request.data as ReframeRequest;

    if (!text || text.length < 10) {
      throw new HttpsError("invalid-argument", "Text too short to reframe");
    }

    if (request.auth.uid !== userId) {
      throw new HttpsError("permission-denied", "User ID mismatch");
    }

    try {
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        generationConfig: {
          temperature: 0.6,
          maxOutputTokens: 150,
        },
      });

      const prompt = `The user selected this text from their journal and wants a gentler, more balanced perspective:

"${text}"

Provide a reframed version that:
- Reduces harsh self-criticism
- Offers balanced, compassionate language
- Does NOT diagnose or give clinical advice
- Keeps the original meaning intact
- Uses "I" statements from the user's perspective

Return ONLY the reframed text (1-3 sentences), nothing else.`;

      const result = await model.generateContent(prompt);
      const reframed = result.response.text().trim();

      return {
        success: true,
        reframed,
      };
    } catch (error) {
      console.error("[reframeJournalText] Error:", error);
      return {
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }
);

// ================== EMOTIONAL SUMMARY FUNCTION ==================

interface EmotionalSummaryRequest {
  userId: string;
  period: "weekly" | "monthly";
}

interface EmotionalSummaryResponse {
  success: boolean;
  summary?: {
    periodStart: string;
    periodEnd: string;
    entryCount: number;
    averageMood: number;
    moodTrend: string;
    topEmotions: string[];
    highlights: string;
    insights: string;
    encouragement: string;
  };
  error?: string;
}

/**
 * Generate weekly or monthly emotional summary from journal entries
 */
export const generateEmotionalSummary = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request): Promise<EmotionalSummaryResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { userId, period } = request.data as EmotionalSummaryRequest;

    if (request.auth.uid !== userId) {
      throw new HttpsError("permission-denied", "User ID mismatch");
    }

    try {
      // Calculate date range
      const now = new Date();
      let periodStart: Date;
      if (period === "weekly") {
        periodStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      } else {
        periodStart = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      }

      // Fetch entries for the period
      const snapshot = await admin.firestore()
        .collection("journal_entries")
        .where("userId", "==", userId)
        .where("deletedAt", "==", null)
        .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(periodStart))
        .orderBy("createdAt", "desc")
        .get();

      if (snapshot.empty || snapshot.docs.length < 2) {
        return {
          success: true,
          summary: undefined, // Not enough entries for summary
        };
      }

      // Extract entry data
      const entries = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          date: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString().split("T")[0],
          moodScore: data.moodScore as number | null,
          tags: (data.tags as string[]) || [],
          title: data.title as string,
          contentSnippet: (data.content as string).substring(0, 100),
        };
      });

      // Calculate stats
      const moods = entries.filter((e) => e.moodScore != null).map((e) => e.moodScore as number);
      const avgMood = moods.length > 0
        ? Number((moods.reduce((a, b) => a + b, 0) / moods.length).toFixed(1))
        : 0;

      const trendDelta = moods.length >= 2 ? moods[0] - moods[moods.length - 1] : 0;
      const moodTrend = trendDelta > 0 ? "improving" : trendDelta < 0 ? "declining" : "steady";

      // Get top tags
      const tagCounts: Record<string, number> = {};
      entries.forEach((e) => e.tags.forEach((t) => {
        tagCounts[t] = (tagCounts[t] || 0) + 1;
      }));
      const topEmotions = Object.entries(tagCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([tag]) => tag);

      // Generate AI insights
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 350,
        },
      });

      const entrySummaries = entries.slice(0, 10).map((e) =>
        `${e.date}: Mood ${e.moodScore || "?"}. "${e.title}" - ${e.contentSnippet}...`
      ).join("\n");

      const prompt = `Analyze this ${period} journal summary for a wellness app:

Period: ${periodStart.toISOString().split("T")[0]} to ${now.toISOString().split("T")[0]}
Entries: ${entries.length}
Average Mood: ${avgMood}/5
Trend: ${moodTrend}
Top Tags: ${topEmotions.join(", ") || "none"}

Recent Entries:
${entrySummaries}

Generate a supportive summary with:
1. highlights (1-2 sentences: key themes or moments)
2. insights (1-2 sentences: patterns or observations)
3. encouragement (1 sentence: positive, forward-looking)

Rules:
- Be warm and supportive
- Never diagnose or give clinical advice
- Focus on growth and self-compassion

Respond in JSON:
{
  "highlights": "...",
  "insights": "...",
  "encouragement": "..."
}`;

      const result = await model.generateContent(prompt);
      const responseText = result.response.text();

      let aiContent;
      try {
        const jsonMatch = responseText.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          aiContent = JSON.parse(jsonMatch[0]);
        } else {
          throw new Error("No JSON found");
        }
      } catch {
        aiContent = {
          highlights: "You've been consistently journaling - that's wonderful!",
          insights: "Regular reflection is a powerful tool for self-awareness.",
          encouragement: "Keep nurturing this practice.",
        };
      }

      const summary = {
        periodStart: periodStart.toISOString().split("T")[0],
        periodEnd: now.toISOString().split("T")[0],
        entryCount: entries.length,
        averageMood: avgMood,
        moodTrend,
        topEmotions,
        highlights: aiContent.highlights,
        insights: aiContent.insights,
        encouragement: aiContent.encouragement,
      };

      // Save summary to Firestore
      await admin.firestore().collection("emotional_summaries").add({
        userId,
        period,
        ...summary,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        summary,
      };
    } catch (error) {
      console.error("[generateEmotionalSummary] Error:", error);
      return {
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }
);

/**
 * Transcribe audio from Firebase Storage URL using Gemini
 * Downloads audio, sends to Gemini for transcription, updates entry
 */
export const transcribeAudio = onCall(
  { secrets: [geminiApiKey], region: "us-central1" },
  async (request) => {
    const { audioUrl, entryId, userId } = request.data;

    if (!audioUrl || !entryId || !userId) {
      throw new HttpsError(
        "invalid-argument",
        "audioUrl, entryId, and userId are required"
      );
    }

    try {
      console.log("[transcribeAudio] Starting transcription for entry:", entryId);

      // Initialize Gemini with audio-capable model
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        safetySettings: [
          {
            category: HarmCategory.HARM_CATEGORY_HARASSMENT,
            threshold: HarmBlockThreshold.BLOCK_NONE,
          },
          {
            category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,
            threshold: HarmBlockThreshold.BLOCK_NONE,
          },
          {
            category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
            threshold: HarmBlockThreshold.BLOCK_NONE,
          },
          {
            category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
            threshold: HarmBlockThreshold.BLOCK_NONE,
          },
        ],
      });

      // Extract bucket and path from Firebase Storage URL
      // New format: https://firebasestorage.googleapis.com/v0/b/{bucket}.firebasestorage.app/o/{path}?...
      // Old format: https://firebasestorage.googleapis.com/v0/b/{bucket}.appspot.com/o/{path}?...
      const bucketMatch = audioUrl.match(/\/b\/([^/]+)\//);
      const pathMatch = audioUrl.match(/\/o\/(.+?)\?/);

      if (!bucketMatch || !pathMatch) {
        console.error("[transcribeAudio] Invalid URL format:", audioUrl);
        throw new Error("Invalid storage URL format");
      }

      const bucketName = bucketMatch[1];
      const storagePath = decodeURIComponent(pathMatch[1]);
      console.log("[transcribeAudio] Bucket:", bucketName, "Path:", storagePath);

      const bucket = admin.storage().bucket(bucketName);
      const file = bucket.file(storagePath);
      const [audioBuffer] = await file.download();
      const base64Audio = audioBuffer.toString("base64");

      console.log("[transcribeAudio] Audio downloaded, size:", audioBuffer.length);

      // Send to Gemini for transcription
      const result = await model.generateContent([
        {
          inlineData: {
            mimeType: "audio/mp4",
            data: base64Audio,
          },
        },
        {
          text: `Transcribe this audio recording accurately. 
          - Output ONLY the transcribed text, nothing else
          - Include punctuation and proper capitalization
          - If the audio is in a language other than English, transcribe in that language
          - If the audio is unclear or silent, respond with "[inaudible]"`,
        },
      ]);

      const transcript = result.response.text().trim();
      console.log("[transcribeAudio] Transcription complete:", transcript.substring(0, 100));

      // Update journal entry with transcript (top-level collection)
      await admin.firestore()
        .collection("journal_entries")
        .doc(entryId)
        .update({
          voiceTranscript: transcript,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      return {
        success: true,
        transcript,
      };
    } catch (error) {
      console.error("[transcribeAudio] Error:", error);
      return {
        success: false,
        error: error instanceof Error ? error.message : "Transcription failed",
      };
    }
  }
);
