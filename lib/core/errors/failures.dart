import 'package:equatable/equatable.dart';

/// Base class for failures (for use with Either pattern)
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => message;
}

/// Network failures
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Network error occurred'])
      : super(message, code: 'NETWORK_FAILURE');
}

class NoInternetFailure extends NetworkFailure {
  const NoInternetFailure()
      : super('No internet connection. Please check your network.');
}

class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure() : super('Request timed out. Please try again.');
}

class ServerFailure extends NetworkFailure {
  const ServerFailure([String message = 'Server error occurred'])
      : super(message);
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure(String message, {String? code})
      : super(message, code: code);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure()
      : super('Invalid email or password', code: 'INVALID_CREDENTIALS');
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure()
      : super('User not found', code: 'USER_NOT_FOUND');
}

class UserDisabledFailure extends AuthFailure {
  const UserDisabledFailure()
      : super('This account has been disabled', code: 'USER_DISABLED');
}

class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure()
      : super('Email address is already in use', code: 'EMAIL_IN_USE');
}

class TokenExpiredFailure extends AuthFailure {
  const TokenExpiredFailure()
      : super('Session expired. Please sign in again', code: 'TOKEN_EXPIRED');
}

/// Data failures
class DataFailure extends Failure {
  const DataFailure(String message, {String? code})
      : super(message, code: code);
}

class DataNotFoundFailure extends DataFailure {
  const DataNotFoundFailure([String message = 'Data not found'])
      : super(message, code: 'DATA_NOT_FOUND');
}

class DataParsingFailure extends DataFailure {
  const DataParsingFailure([String message = 'Failed to parse data'])
      : super(message, code: 'PARSING_ERROR');
}

class InvalidDataFailure extends DataFailure {
  const InvalidDataFailure([String message = 'Invalid data provided'])
      : super(message, code: 'INVALID_DATA');
}

/// Rate limit failures
class RateLimitFailure extends Failure {
  final Duration? retryAfter;

  const RateLimitFailure({
    String message = 'Too many requests. Please try again later.',
    this.retryAfter,
  }) : super(message, code: 'RATE_LIMIT_EXCEEDED');

  @override
  List<Object?> get props => [message, code, retryAfter];
}

/// Storage failures
class StorageFailure extends Failure {
  const StorageFailure(String message, {String? code})
      : super(message, code: code);
}

class StorageReadFailure extends StorageFailure {
  const StorageReadFailure()
      : super('Failed to read data from storage', code: 'STORAGE_READ_ERROR');
}

class StorageWriteFailure extends StorageFailure {
  const StorageWriteFailure()
      : super('Failed to write data to storage', code: 'STORAGE_WRITE_ERROR');
}

/// Chat failures
class ChatFailure extends Failure {
  const ChatFailure(String message, {String? code})
      : super(message, code: code);
}

class CrisisDetectedFailure extends ChatFailure {
  final Map<String, dynamic> resources;

  const CrisisDetectedFailure(this.resources)
      : super('Crisis situation detected', code: 'CRISIS_DETECTED');

  @override
  List<Object?> get props => [message, code, resources];
}

class MessageTooLongFailure extends ChatFailure {
  const MessageTooLongFailure()
      : super(
          'Message is too long. Please keep it under 500 characters.',
          code: 'MESSAGE_TOO_LONG',
        );
}

class SessionNotFoundFailure extends ChatFailure {
  const SessionNotFoundFailure()
      : super('Chat session not found', code: 'SESSION_NOT_FOUND');
}

/// Mood failures
class MoodFailure extends Failure {
  const MoodFailure(String message, {String? code})
      : super(message, code: code);
}

class InvalidMoodScoreFailure extends MoodFailure {
  const InvalidMoodScoreFailure()
      : super('Mood score must be between 1 and 5', code: 'INVALID_MOOD_SCORE');
}

/// Validation failures
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure(
    String message, {
    this.fieldErrors,
    String? code,
  }) : super(message, code: code ?? 'VALIDATION_ERROR');

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

/// Permission failures
class PermissionFailure extends Failure {
  const PermissionFailure([String message = 'Permission denied'])
      : super(message, code: 'PERMISSION_DENIED');
}

class NotAuthorizedFailure extends PermissionFailure {
  const NotAuthorizedFailure()
      : super('You are not authorized to perform this action');
}

/// API failures
class ApiFailure extends Failure {
  final int? statusCode;

  const ApiFailure(
    String message, {
    this.statusCode,
    String? code,
  }) : super(message, code: code);

  @override
  List<Object?> get props => [message, code, statusCode];
}

class UnauthorizedApiFailure extends ApiFailure {
  const UnauthorizedApiFailure()
      : super(
          'Unauthorized. Please sign in again.',
          statusCode: 401,
          code: 'UNAUTHORIZED',
        );
}

class ForbiddenApiFailure extends ApiFailure {
  const ForbiddenApiFailure()
      : super(
          'You do not have permission to access this resource.',
          statusCode: 403,
          code: 'FORBIDDEN',
        );
}

class NotFoundApiFailure extends ApiFailure {
  const NotFoundApiFailure([String message = 'Resource not found'])
      : super(message, statusCode: 404, code: 'NOT_FOUND');
}

class BadRequestApiFailure extends ApiFailure {
  const BadRequestApiFailure([String message = 'Bad request'])
      : super(message, statusCode: 400, code: 'BAD_REQUEST');
}

class InternalServerApiFailure extends ApiFailure {
  const InternalServerApiFailure()
      : super(
          'Server error occurred. Please try again later.',
          statusCode: 500,
          code: 'INTERNAL_SERVER_ERROR',
        );
}

/// Unknown failure
class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'An unexpected error occurred'])
      : super(message, code: 'UNKNOWN_ERROR');
}

/// Cache failure
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error occurred'])
      : super(message, code: 'CACHE_ERROR');
}
