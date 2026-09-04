/// Lightweight, on-device pre-check for expressed self-harm / crisis intent.
///
/// IMPORTANT: this targets first-person present-tense *ideation* ("I want to
/// die", "kill myself"), NOT dream imagery — nightmares about death/dying are
/// extremely common and must NOT be blocked. The earlier pattern also matched
/// "…kill me", which fired on the single most common nightmare narrative
/// ("a man was trying to kill me") and answered an ordinary dream with a
/// crisis card. When this matches, the app shows a supportive resources screen
/// instead of an AI "interpretation". This is a safety net, not a diagnosis;
/// the proxy runs the same check server-side — keep the two lists in sync
/// (dreamlore/worker/src/index.js).
class SafetyCheck {
  static final List<RegExp> _patterns = [
    RegExp(r"\b(kill|hurt|harm)(ing)?\s+myself\b", caseSensitive: false),
    RegExp(r"\b(cut|cutting)\s+myself\b", caseSensitive: false),
    RegExp(r"\bsuicid", caseSensitive: false),
    RegExp(r"\b(want|wanting|wanna|going)\s+to\s+die\b", caseSensitive: false),
    RegExp(r"\bwanna\s+die\b", caseSensitive: false),
    RegExp(r"\bend(ing)?\s+(my|it)\s+(life|all)\b", caseSensitive: false),
    RegExp(r"\bself[-\s]?harm", caseSensitive: false),
    RegExp(r"\bno\s+(reason|point)\s+(to\s+live|in\s+living)\b",
        caseSensitive: false),
    RegExp(r"\bbetter\s+off\s+without\s+me\b", caseSensitive: false),
  ];

  static bool isConcerning(String text) {
    if (text.trim().isEmpty) return false;
    return _patterns.any((p) => p.hasMatch(text));
  }
}
