/// Custom exceptions thrown by `CunningDocumentScanner`.
class CunningDocumentScannerException implements Exception {
  /// A short message describing the error.
  final String message;

  /// Optional code to categorize errors (e.g. 'permission_denied').
  final String? code;

  /// Creates an exception with a [message] and an optional [code].
  const CunningDocumentScannerException(this.message, {this.code});

  /// Named constructor for permission errors.
  const CunningDocumentScannerException.permissionDenied([
    String message = 'Permission not granted',
  ]) : this(message, code: 'permission_denied');

  @override
  String toString() =>
      'CunningDocumentScannerException(${code ?? 'error'}): $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CunningDocumentScannerException &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => message.hashCode ^ code.hashCode;
}
