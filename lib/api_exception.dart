// lib/api_exception.dart

/// A custom exception to represent API-related errors in a user-friendly way.
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() {
    return message;
  }
}
