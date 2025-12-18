import * as admin from "firebase-admin";
import {
  GoogleGenerativeAI,
  HarmCategory,
  HarmBlockThreshold,
} from "@google/generative-ai";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";

// Initialize Firebase Admin
admin.initializeApp();

// Define secret for Gemini API key
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// Crisis keywords for pre-AI filtering
const CRISIS_KEYWORDS = [
  "suicide",
  "kill myself",
  "end my life",
  "want to die",
  "self harm",
  "hurt myself",
  "overdose",
  "jump off",
  "no reason to live",
  "better off dead",
];

// Safety system prompt for Gemini
const SYSTEM_PROMPT = `You are MindMate, a compassionate AI companion focused on mental wellness support.

Core Guidelines:
1. Be empathetic, warm, and non-judgmental
2. Listen actively and validate feelings
3. Ask open-ended questions to encourage reflection
4. Provide supportive guidance, not medical advice
5. Recognize crisis situations and respond appropriately

Crisis Protocol:
- If user expresses suicidal thoughts or self-harm: Respond with immediate concern and provide crisis resources
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
  conversationHistory?: Array<{role: string; content: string}>;
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
 * Generate crisis response
 */
function getCrisisResponse(): string {
  return "I'm really concerned about what you've shared. Your safety is the most important thing right now. " +
    "Please reach out to a crisis helpline immediately:\\n\\n" +
    "• National Suicide Prevention Lifeline: 988\\n" +
    "• Crisis Text Line: Text HOME to 741741\\n" +
    "• International: findahelpline.com\\n\\n" +
    "I'm here to listen, but trained counselors can provide the immediate support you need. " +
    "Will you reach out to one of these resources?";
}

/**
 * Generate AI response using Gemini
 */
async function generateAIResponse(
  userMessage: string,
  conversationHistory: Array<{role: string; content: string}>,
  apiKey: string,
  userName?: string,
  sessionSummaries?: string[]
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
      parts: [{text: msg.content}],
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

    const chat = model.startChat({history});
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
  {secrets: ["GEMINI_API_KEY"]},
  async (request): Promise<ChatResponse> => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to send messages"
      );
    }

    const {userId, sessionId, message, conversationHistory = []} = request.data as ChatRequest;
    console.log("[chat] Received request for user:", userId, "session:", sessionId);

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
      // Step 1: Crisis detection
      const isCrisis = detectCrisis(message);

      if (isCrisis) {
        // Get immediate crisis response
        const crisisResponse = getCrisisResponse();

        // Save both user message and crisis response to Firestore
        const sessionRef = admin.firestore()
          .collection("chat_sessions")
          .doc(sessionId);

        const now = admin.firestore.Timestamp.now();

        await sessionRef.update({
          messages: admin.firestore.FieldValue.arrayUnion({
            role: "user",
            content: message,
            timestamp: now,
            safetyFlagged: true,
          }),
          messageCount: admin.firestore.FieldValue.increment(1),
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await sessionRef.update({
          messages: admin.firestore.FieldValue.arrayUnion({
            role: "assistant",
            content: crisisResponse,
            timestamp: now,
            safetyFlagged: true,
          }),
          messageCount: admin.firestore.FieldValue.increment(1),
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Log crisis event (but don't block response)
        admin.firestore().collection("crisis_logs").add({
          userId,
          sessionId,
          message,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          flaggedFor: "crisis_keywords",
        }).catch((err) => console.error("Crisis log error:", err));

        return {
          success: true,
          message: "Crisis detected",
          aiResponse: crisisResponse,
          isCrisis: true,
        };
      }

      // Step 2: Fetch user profile and session summaries for context
      console.log("[chat] Fetching user profile and session summaries...");
      let userName: string | undefined;
      let sessionSummaries: string[] = [];
      
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

      // Step 3: Generate AI response with enhanced context
      console.log("[chat] Calling generateAIResponse...");
      const aiResponse = await generateAIResponse(
        message,
        conversationHistory,
        geminiApiKey.value(),
        userName,
        sessionSummaries
      );
      console.log("[chat] Got AI response:", aiResponse.substring(0, 50));

      // Step 3: Save messages to chat_sessions document as array
      const sessionRef = admin.firestore()
        .collection("chat_sessions")
        .doc(sessionId);

      const now = admin.firestore.Timestamp.now();

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
        isCrisis: false,
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
  messages: Array<{role: string; content: string; timestamp: any}>,
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
