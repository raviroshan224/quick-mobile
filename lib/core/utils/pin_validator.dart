/// Shared 4-digit PIN validation used everywhere a PIN is *created* (staff
/// creation, staff PIN reset, owner "create your PIN"). Mirrors the
/// server-side `IsNotWeakPin` validator on `SetPinDto` — kept in sync so the
/// client fails fast instead of round-tripping to the server for an obvious
/// rejection, while the server DTO remains the actual enforcement boundary.
library;

/// Trivially guessable 4-digit PINs: all-same-digit and the two straight
/// sequences (ascending/descending) — the same classes of PIN real-world
/// guidance (e.g. Apple's iOS PIN blocklist) rejects.
const Set<String> _weakPins = {
  '0000', '1111', '2222', '3333', '4444', '5555', '6666', '7777', '8888', '9999',
  '0123', '1234', '2345', '3456', '4567', '5678', '6789', '7890',
  '9876', '8765', '7654', '6543', '5432', '4321', '3210', '0987',
};

/// Returns a validation error message, or `null` if [pin] is an acceptable
/// new PIN. Does not validate length/digits-only — pair with the existing
/// "must be 4 digits" check already used at each call site.
String? weakPinError(String pin) {
  if (_weakPins.contains(pin)) {
    return 'This PIN is too easy to guess — avoid repeated digits or simple sequences.';
  }
  return null;
}
