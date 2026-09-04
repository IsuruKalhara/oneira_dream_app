/// Lightweight, on-device pre-check for expressed self-harm / crisis intent.
///
/// IMPORTANT: this targets first-person present-tense *ideation* ("I want to
/// die", "kill myself"), NOT dream imagery — nightmares about death/dying are
/// extremely common and must NOT be blocked. When it matches, the app shows a
/// supportive resources screen instead of an AI "interpretation". This is a
/// safety net, not a diagnosis; the proxy should run a stronger check too.
class SafetyCheck {
  static final List<RegExp> _patterns = [
    RegExp(r"\b(kill|hurt|harm)(ing)?\s+(myself|me)\b", caseSensitive: false),
    RegExp(r"\bsuicid", caseSensitive: false),
    RegExp(r"\b(want|wanting|going)\s+to\s+die\b", caseSensitive: false),
    RegExp(r"\bend(ing)?\s+(my|it)\s+(life|all)\b", caseSensitive: false),
    RegExp(r"\bself[-\s]?harm", caseSensitive: false),
    RegExp(r"\bno\s+reason\s+to\s+live\b", caseSensitive: false),
    RegExp(r"\b(cut|cutting)\s+myself\b", caseSensitive: false),
  ];

  static bool isConcerning(String text) {
    if (text.trim().isEmpty) return false;
    return _patterns.any((p) => p.hasMatch(text));
  }
}
