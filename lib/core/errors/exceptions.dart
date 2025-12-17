/// Custom exceptions for the app
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Network exceptions
class NetworkException extends AppException {
  NetworkException([String message = 'Network error occurred'])
      : super(message, code: 'NETWORK_ERROR');
}

class NoInternetException extends NetworkException {
  NoInternetException()
      : super('No internet connection. Please check your network.');
}

class TimeoutException extends NetworkException {
  TimeoutException() : super('Request timed out. Please try again.');
}

class ServerException extends NetworkException {
  ServerException([String message = 'Server error occurred'])
      : super(message);
}

/// Authentication exceptions
class AuthException extends AppException {
  AuthException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException()
      : super('Invalid email or password', code: 'INVALID_CREDENTIALS');
}

class UserNotFoundException extends AuthException {
  UserNotFoundException()
      : super('User not found', code: 'USER_NOT_FOUND');
}

class UserDisabledException extends AuthException {
  UserDisabledException()
      : super('This account has been disabled', code: 'USER_DISABLED');
}

class EmailAlreadyInUseException extends AuthException {
  EmailAlreadyInUseException()
      : super('Email address is already in use', code: 'EMAIL_IN_USE');
}

class WeakPasswordException extends AuthException {
  WeakPasswordException()
      : super('Password is too weak', code: 'WEAK_PASSWORD');
}

class TokenExpiredException extends AuthException {
  TokenExpiredException()
      : super('Session expired. Please sign in again', code: 'TOKEN_EXPIRED');
}

/// Data exceptions
class DataException extends AppException {
  DataException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class DataNotFoundException extends DataException {
  DataNotFoundException([String message = 'Data not found'])
      : super(message, code: 'DATA_NOT_FOUND');
}

class DataParsingException extends DataException {
  DataParsingException([String message = 'Failed to parse data'])
      : super(message, code: 'PARSING_ERROR');
}

class InvalidDataException extends DataException {
  InvalidDataException([String message = 'Invalid data provided'])
      : super(message, code: 'INVALID_DATA');
}

/// Rate limit exceptions
class RateLimitException extends AppException {
  final Duration? retryAfter;

  RateLimitException({
    String message = 'Too many requests. Please try again later.',
    this.retryAfter,
  }) : super(message, code: 'RATE_LIMIT_EXCEEDED');
}

/// Storage exceptions
class StorageException extends AppException {
  StorageException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class StorageReadException extends StorageException {
  StorageReadException()
      : super('Failed to read data from storage', code: 'STORAGE_READ_ERROR');
}

class StorageWriteException extends StorageException {
  StorageWriteException()
      : super('Failed to write data to storage', code: 'STORAGE_WRITE_ERROR');
}

/// Chat exceptions
class ChatException extends AppException {
  ChatException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class CrisisDetectedException extends ChatException {
  final Map<String, dynamic> resources;

  CrisisDetectedException(this.resources)
      : super(
          'Crisis situation detected',
          code: 'CRISIS_DETECTED',
        );
}

class MessageTooLongException extends ChatException {
  MessageTooLongException()
      : super(
          'Message is too long. Please keep it under 500 characters.',
          code: 'MESSAGE_TOO_LONG',
        );
}

class SessionNotFoundException extends ChatException {
  SessionNotFoundException()
      : super('Chat session not found', code: 'SESSION_NOT_FOUND');
}

/// Mood exceptions
class MoodException extends AppException {
  MoodException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class InvalidMoodScoreException extends MoodException {
  InvalidMoodScoreException()
      : super(
          'Mood score must be between 1 and 5',
          code: 'INVALID_MOOD_SCORE',
        );
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(
    String message, {
    this.fieldErrors,
    String? code,
  }) : super(message, code: code ?? 'VALIDATION_ERROR');
}

/// Permission exceptions
class PermissionException extends AppException {
  PermissionException([String message = 'Permission denied'])
      : super(message, code: 'PERMISSION_DENIED');
}

class NotAuthorizedException extends PermissionException {
  NotAuthorizedException()
      : super('You are not authorized to perform this action');
}

/// API exceptions
class ApiException extends AppException {
  final int? statusCode;

  ApiException(
    String message, {
    this.statusCode,
    String? code,
    dynamic originalError,
  }) : super(message, code: code, originalError: originalError);
}

class UnauthorizedApiException extends ApiException {
  UnauthorizedApiException()
      : super(
          'Unauthorized. Please sign in again.',
          statusCode: 401,
          code: 'UNAUTHORIZED',
        );
}

class ForbiddenApiException extends ApiException {
  ForbiddenApiException()
      : super(
          'You do not have permission to access this resource.',
          statusCode: 403,
          code: 'FORBIDDEN',
        );
}

class NotFoundApiException extends ApiException {
  NotFoundApiException([String message = 'Resource not found'])
      : super(message, statusCode: 404, code: 'NOT_FOUND');
}

class BadRequestApiException extends ApiException {
  BadRequestApiException([String message = 'Bad request'])
      : super(message, statusCode: 400, code: 'BAD_REQUEST');
}

class InternalServerApiException extends ApiException {
  InternalServerApiException()
      : super(
          'Server error occurred. Please try again later.',
          statusCode: 500,
          code: 'INTERNAL_SERVER_ERROR',
        );
}

/// Unknown exception
class UnknownException extends AppException {
  UnknownException({dynamic originalError})
      : super(
          'An unexpected error occurred',
          code: 'UNKNOWN_ERROR',
          originalError: originalError,
        );
}
