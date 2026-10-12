/// Central configuration for the AI integration.
///
/// **Model choice — gemini-3.5-flash**
/// Gemini 1.5 Flash and Gemini 2.0 Flash are both deprecated and shut down.
/// Gemini 3.5 Flash went GA on May 19 2026 (Google I/O), is explicitly marked
/// "Stable" in the Google AI documentation, has no scheduled shutdown date,
/// and is the recommended production replacement for all previous Flash models.
/// Source: https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash
library;

/// The Gemini model ID used for AI heuristic suggestions.
/// Change this one constant when Google releases a newer stable model.
const String kGeminiModel = 'gemini-3.5-flash';

/// Human-readable label shown in the Settings screen.
const String kGeminiModelLabel = 'Gemini 3.5 Flash (Google AI Studio)';

/// Base URL template for the Gemini generateContent endpoint.
/// Use [kGeminiModel] to build the full URL.
const String kGeminiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/';
