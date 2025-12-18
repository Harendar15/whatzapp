class PhoneUtils {
  /// Remove all non-digits & keep last 10 digits
  static String normalize(String number) {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Compare two numbers safely
  static bool isSame(String a, String b) {
    return normalize(a) == normalize(b);
  }
}
