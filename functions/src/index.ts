import * as admin from "firebase-admin";
import {
  GoogleGenerativeAI,
  HarmCategory,
  HarmBlockThreshold,
} from "@google/generative-ai";
import {onCall, HttpsError} from "firebase-functions/v2/https";

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(
  process.env.GEMINI_API_KEY || ""
);

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
  conversationHistory: Array<{role: string; content: string}>
): Promise<string> {
  try {
    const model = genAI.getGenerativeModel({
      model: "gemini-1.5-flash",
      systemInstruction: SYSTEM_PROMPT,
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

    // Build chat history
    const history = conversationHistory.slice(-10).map((msg) => ({
      role: msg.role === "user" ? "user" : "model",
      parts: [{text: msg.content}],
    }));

    const chat = model.startChat({history});
    const result = await chat.sendMessage(userMessage);
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
  async (request): Promise<ChatResponse> => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to send messages"
      );
    }

    const {userId, sessionId, message, conversationHistory = []} = request.data as ChatRequest;

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
        // Return immediate crisis response
        const crisisResponse = getCrisisResponse();

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

      // Step 2: Generate AI response
      const aiResponse = await generateAIResponse(message, conversationHistory);

      // Step 3: Save message to Firestore
      const messagesRef = admin.firestore().collection("chat_messages");
      await messagesRef.add({
        sessionId,
        userId,
        role: "user",
        content: message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isCrisis: false,
      });

      await messagesRef.add({
        sessionId,
        userId,
        role: "assistant",
        content: aiResponse,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isCrisis: false,
      });

      // Update session last message time
      await admin.firestore()
        .collection("chat_sessions")
        .doc(sessionId)
        .update({
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        });

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
