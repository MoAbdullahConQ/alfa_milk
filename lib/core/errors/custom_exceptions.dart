/// Typed, user-friendly pipeline errors.
///
/// These are thrown by the pipeline so the UI can show friendly messages
/// (never stack traces, Constitution Principle IV). Each error's `toString()`
/// is a complete, user-facing sentence.
///
/// Errors that carry a dynamic `detail` use a `const` constructor — each throw
/// site builds one immutable instance (single-instance per site). Errors with
/// no dynamic data are true singletons exposing a shared `instance`.
library;

/// The selected file is not a valid Alpro report.
class AlproParseError implements Exception {
  const AlproParseError(this.detail);

  final String detail;

  @override
  String toString() => 'The selected file is not a valid Alpro report: $detail';
}

/// The cow list could not be read.
class CowListError implements Exception {
  const CowListError(this.detail);

  final String detail;

  @override
  String toString() => 'The cow list could not be read: $detail';
}

/// The file could not be saved.
class OutputWriteError implements Exception {
  const OutputWriteError(this.detail);

  final String detail;

  @override
  String toString() => 'The file could not be saved: $detail';
}

/// No current cow list is available to filter with.
///
/// Singleton: carries no data, so all uses share one instance.
class NoCowListError implements Exception {
  const NoCowListError._();

  /// The single shared instance.
  static const NoCowListError instance = NoCowListError._();

  @override
  String toString() => 'Import a current cow list before converting.';
}
