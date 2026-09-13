/// Shared phone-number validation for every form that saves a phone number
/// (customer create/edit, quick-add customer at checkout, staff create/edit).
///
/// Nepali mobile numbers are exactly 10 digits and start with 9 — NTC, Ncell
/// and Smart Cell all issue 98 / 97 / 96 prefixes. The backend stores the raw
/// string as-is, so this is the only guard stopping 6-digit or 12–13-digit
/// junk from being saved.
library;

final RegExp _nepaliMobileRe = RegExp(r'^9\d{9}$');

/// Returns a validation error message, or `null` when [value] is acceptable.
///
/// When [required] is false an empty value passes — the field is optional and
/// the caller stores `null`. A non-empty value is always format-checked.
String? phoneNumberError(String? value, {bool required = false}) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    return required ? 'Phone number is required' : null;
  }
  if (!_nepaliMobileRe.hasMatch(phone)) {
    return 'Enter a valid 10-digit mobile number starting with 9';
  }
  return null;
}
