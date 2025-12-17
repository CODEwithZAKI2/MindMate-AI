import 'package:logger/logger.dart';

/// Centralized logging utility
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static final Logger _productionLogger = Logger(
    printer: SimplePrinter(printTime: true),
  );

  // Determines whether to use verbose logging
  static bool _isProduction = false;

  static void init({required bool isProduction}) {
    _isProduction = isProduction;
  }

  static Logger get instance => _isProduction ? _productionLogger : _logger;

  // Debug
  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance.d(message, error: error, stackTrace: stackTrace);
  }

  // Info
  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance.i(message, error: error, stackTrace: stackTrace);
  }

  // Warning
  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance.w(message, error: error, stackTrace: stackTrace);
  }

  // Error
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance.e(message, error: error, stackTrace: stackTrace);
  }

  // Fatal/WTF
  static void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance.f(message, error: error, stackTrace: stackTrace);
  }

  // Trace (verbose)
  static void trace(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance.t(message, error: error, stackTrace: stackTrace);
  }

  // Private Constructor
  AppLogger._();
}
