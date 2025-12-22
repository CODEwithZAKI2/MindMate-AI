import 'package:equatable/equatable.dart';

/// Represents a crisis hotline resource for a specific country/region
class CrisisResource extends Equatable {
  final String countryCode; // ISO 3166-1 alpha-2 (US, GB, CA, etc.)
  final String countryName;
  final String primaryHotline;
  final String primaryHotlineName;
  final String? textLine;
  final String? textLineInstructions;
  final String? emergencyNumber;
  final List<String>? additionalResources;

  const CrisisResource({
    required this.countryCode,
    required this.countryName,
    required this.primaryHotline,
    required this.primaryHotlineName,
    this.textLine,
    this.textLineInstructions,
    this.emergencyNumber,
    this.additionalResources,
  });

  @override
  List<Object?> get props => [
        countryCode,
        countryName,
        primaryHotline,
        primaryHotlineName,
        textLine,
        textLineInstructions,
        emergencyNumber,
        additionalResources,
      ];

  /// Format crisis resources for display
  String formatForDisplay() {
    final buffer = StringBuffer();
    
    buffer.writeln('**$countryName Resources:**\n');
    buffer.writeln('• **$primaryHotlineName**: $primaryHotline');
    
    if (textLine != null) {
      buffer.writeln('• **Text Line**: $textLineInstructions');
    }
    
    if (emergencyNumber != null) {
      buffer.writeln('• **Emergency**: $emergencyNumber');
    }
    
    if (additionalResources != null && additionalResources!.isNotEmpty) {
      buffer.writeln('\n**Additional Resources:**');
      for (final resource in additionalResources!) {
        buffer.writeln('• $resource');
      }
    }
    
    return buffer.toString();
  }

  factory CrisisResource.fromJson(Map<String, dynamic> json) {
    return CrisisResource(
      countryCode: json['countryCode'] as String,
      countryName: json['countryName'] as String,
      primaryHotline: json['primaryHotline'] as String,
      primaryHotlineName: json['primaryHotlineName'] as String,
      textLine: json['textLine'] as String?,
      textLineInstructions: json['textLineInstructions'] as String?,
      emergencyNumber: json['emergencyNumber'] as String?,
      additionalResources: (json['additionalResources'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'countryCode': countryCode,
      'countryName': countryName,
      'primaryHotline': primaryHotline,
      'primaryHotlineName': primaryHotlineName,
      'textLine': textLine,
      'textLineInstructions': textLineInstructions,
      'emergencyNumber': emergencyNumber,
      'additionalResources': additionalResources,
    };
  }
}
