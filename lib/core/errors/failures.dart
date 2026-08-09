/// Base class for all pipeline failures surfaced to the UI.
abstract class Failure {
  const Failure(this.message);

  final String message;
}

/// The selected file is not a valid Alpro report.
class AlproParseFailure extends Failure {
  const AlproParseFailure(super.message);
}

/// The cow list could not be read.
class CowListFailure extends Failure {
  const CowListFailure(super.message);
}

/// The file could not be saved.
class OutputWriteFailure extends Failure {
  const OutputWriteFailure(super.message);
}

/// No current cow list is available to filter with.
class NoCowListFailure extends Failure {
  const NoCowListFailure(super.message);
}
