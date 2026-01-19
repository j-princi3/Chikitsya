class DeIdentifier {
  static String redact(String text) {
    String cleaned = text;

    // Remove phone numbers (Indian + generic)
    cleaned = cleaned.replaceAll(
      RegExp(r'(\+91[\-\s]?)?[0]?[6-9]\d{9}'),
      '[REDACTED_PHONE]',
    );

    // Remove email addresses
    cleaned = cleaned.replaceAll(
      RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b'),
      '[REDACTED_EMAIL]',
    );

    // Remove Aadhaar-like / ID numbers (12 digits)
    cleaned = cleaned.replaceAll(
      RegExp(r'\b\d{12}\b'),
      '[REDACTED_ID]',
    );

    // Remove common patient identifiers
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(Patient Name|Name|IPD No|UHID|Admission No|Mobile No|Phone|Contact)\s*[:\-]?\s*.*',
        caseSensitive: false,
      ),
      '[REDACTED_IDENTIFIER]',
    );

    // Remove dates of birth
    cleaned = cleaned.replaceAll(
      RegExp(r'\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}\b'),
      '[REDACTED_DATE]',
    );

    return cleaned.trim();
  }
}
