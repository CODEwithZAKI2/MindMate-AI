# MindMate AI – Risks & Mitigations

## Ethical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| User relies on app instead of professional help | High | High | Clear disclaimers, periodic prompts to seek professional help, resource links |
| AI provides harmful advice | Medium | Critical | Strict system prompt, post-response filtering, no medical claims |
| False negative in crisis detection | Medium | Critical | Conservative keyword list, regular updates, human review queue |
| User data breach | Low | Critical | Encryption, minimal data collection, regular security audits |

## Legal/Store Review Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| App Store rejection (health claims) | Medium | High | Clear "wellness, not medical" positioning, prominent disclaimers |
| GDPR/CCPA non-compliance | Medium | High | Data export feature, deletion within 30 days, privacy policy |
| Terms of service violations (Gemini) | Low | High | Stay within Gemini acceptable use, no medical claims |
| Liability for user actions | Medium | Medium | Terms of service, disclaimers, crisis protocol documentation |

**App Store Preparation:**
- Category: Health & Fitness (NOT Medical)
- Description emphasizes "wellness companion" not "therapy"
- Screenshots show disclaimer
- Privacy nutrition labels completed accurately

## AI Misuse Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Prompt injection attacks | Medium | Medium | Input sanitization, system prompt protection, output validation |
| Users testing AI limits | High | Low | Rate limiting, conversation monitoring, graceful handling |
| AI generating inappropriate content | Low | High | Post-response filtering, Gemini safety settings maxed |
| Context memory exploitation | Low | Medium | Memory sanitization, session isolation |

**AI Safety Configuration:**
- Gemini safety settings: BLOCK_MEDIUM_AND_ABOVE for all categories
- Custom post-filter for wellness-specific concerns
- Automatic session reset after crisis detection
- Daily automated testing with adversarial prompts