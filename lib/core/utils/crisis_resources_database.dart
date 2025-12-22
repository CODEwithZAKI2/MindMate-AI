import '../../domain/entities/crisis_resource.dart';

/// Comprehensive international crisis resources database
class CrisisResourcesDatabase {
  /// Get all available crisis resources
  static Map<String, CrisisResource> getAllResources() {
    return {
      'US': _usResources,
      'CA': _canadaResources,
      'GB': _ukResources,
      'AU': _australiaResources,
      'NZ': _newZealandResources,
      'IE': _irelandResources,
      'IN': _indiaResources,
      'ZA': _southAfricaResources,
    };
  }

  /// Get crisis resource by country code (returns US as fallback)
  static CrisisResource getByCountryCode(String countryCode) {
    final resources = getAllResources();
    return resources[countryCode.toUpperCase()] ?? _usResources;
  }

  /// Get crisis resource by timezone (best effort)
  static CrisisResource getByTimezone(String timezone) {
    // Map common timezone prefixes to country codes
    if (timezone.startsWith('America/')) {
      if (timezone.contains('Toronto') ||
          timezone.contains('Vancouver') ||
          timezone.contains('Edmonton') ||
          timezone.contains('Montreal')) {
        return _canadaResources;
      }
      return _usResources;
    } else if (timezone.startsWith('Europe/London')) {
      return _ukResources;
    } else if (timezone.startsWith('Europe/Dublin')) {
      return _irelandResources;
    } else if (timezone.startsWith('Australia/')) {
      return _australiaResources;
    } else if (timezone.startsWith('Pacific/Auckland')) {
      return _newZealandResources;
    } else if (timezone.startsWith('Asia/Kolkata') ||
        timezone.startsWith('Asia/Calcutta')) {
      return _indiaResources;
    } else if (timezone.startsWith('Africa/Johannesburg')) {
      return _southAfricaResources;
    }

    // Default fallback
    return _usResources;
  }

  /// United States
  static const _usResources = CrisisResource(
    countryCode: 'US',
    countryName: 'United States',
    primaryHotline: '988',
    primaryHotlineName: 'Suicide & Crisis Lifeline',
    textLine: '741741',
    textLineInstructions: 'Text "HELLO" to 741741',
    emergencyNumber: '911',
    additionalResources: [
      'Veterans Crisis Line: 988 (Press 1)',
      'Trevor Project (LGBTQ+ Youth): 1-866-488-7386',
      'Trans Lifeline: 1-877-565-8860',
      'SAMHSA National Helpline: 1-800-662-4357',
    ],
  );

  /// Canada
  static const _canadaResources = CrisisResource(
    countryCode: 'CA',
    countryName: 'Canada',
    primaryHotline: '988',
    primaryHotlineName: 'Suicide Crisis Helpline',
    textLine: '45645',
    textLineInstructions: 'Text "TALK" to 45645',
    emergencyNumber: '911',
    additionalResources: [
      'Kids Help Phone: 1-800-668-6868',
      'Hope for Wellness (Indigenous): 1-855-242-3310',
      'Trans Lifeline Canada: 1-877-330-6366',
      'Talk Suicide Canada: 1-833-456-4566',
    ],
  );

  /// United Kingdom
  static const _ukResources = CrisisResource(
    countryCode: 'GB',
    countryName: 'United Kingdom',
    primaryHotline: '116 123',
    primaryHotlineName: 'Samaritans',
    textLine: '85258',
    textLineInstructions: 'Text "SHOUT" to 85258',
    emergencyNumber: '999 or 112',
    additionalResources: [
      'CALM (Campaign Against Living Miserably): 0800 58 58 58',
      'Papyrus (Under 35s): 0800 068 4141',
      'The Mix (Under 25s): 0808 808 4994',
      'Mind Infoline: 0300 123 3393',
    ],
  );

  /// Australia
  static const _australiaResources = CrisisResource(
    countryCode: 'AU',
    countryName: 'Australia',
    primaryHotline: '13 11 14',
    primaryHotlineName: 'Lifeline',
    textLine: '0477 13 11 14',
    textLineInstructions: 'Text Lifeline at 0477 13 11 14',
    emergencyNumber: '000',
    additionalResources: [
      'Beyond Blue: 1300 22 4636',
      'Kids Helpline: 1800 55 1800',
      'MensLine Australia: 1300 78 99 78',
      'QLife (LGBTI): 1800 184 527',
    ],
  );

  /// New Zealand
  static const _newZealandResources = CrisisResource(
    countryCode: 'NZ',
    countryName: 'New Zealand',
    primaryHotline: '1737',
    primaryHotlineName: 'Need to Talk?',
    textLine: '1737',
    textLineInstructions: 'Text or call 1737',
    emergencyNumber: '111',
    additionalResources: [
      'Lifeline: 0800 543 354',
      'Suicide Crisis Helpline: 0508 828 865',
      'Youthline: 0800 376 633',
      'Depression Helpline: 0800 111 757',
    ],
  );

  /// Ireland
  static const _irelandResources = CrisisResource(
    countryCode: 'IE',
    countryName: 'Ireland',
    primaryHotline: '116 123',
    primaryHotlineName: 'Samaritans',
    textLine: '50808',
    textLineInstructions: 'Text "HELLO" to 50808',
    emergencyNumber: '999 or 112',
    additionalResources: [
      'Pieta House: 1800 247 247',
      'Aware: 1800 80 48 48',
      'Childline: 1800 66 66 66',
      'LGBT Ireland: 1890 929 539',
    ],
  );

  /// India
  static const _indiaResources = CrisisResource(
    countryCode: 'IN',
    countryName: 'India',
    primaryHotline: '9152987821',
    primaryHotlineName: 'AASRA',
    emergencyNumber: '112',
    additionalResources: [
      'iCall (TISS): 9152987821',
      'Snehi: 91-22-27546669',
      'Vandrevala Foundation: 1860-2662-345',
      'Fortis Stress Helpline: 8376804102',
    ],
  );

  /// South Africa
  static const _southAfricaResources = CrisisResource(
    countryCode: 'ZA',
    countryName: 'South Africa',
    primaryHotline: '0800 567 567',
    primaryHotlineName: 'SADAG (South African Depression and Anxiety Group)',
    textLine: '31393',
    textLineInstructions: 'Text "Hi" to 31393',
    emergencyNumber: '10111 or 112',
    additionalResources: [
      'Suicide Crisis Line: 0800 567 567',
      'LifeLine: 0861 322 322',
      'Childline: 0800 055 555',
      'TEARS Foundation: 010 590 5920',
    ],
  );

  /// Get international fallback resources
  static const internationalFallback = CrisisResource(
    countryCode: 'INTL',
    countryName: 'International',
    primaryHotline: 'findahelpline.com',
    primaryHotlineName: 'International Association for Suicide Prevention',
    additionalResources: [
      'Find A Helpline: findahelpline.com',
      'Befrienders Worldwide: befrienders.org',
      'International Association for Suicide Prevention: iasp.info/resources',
    ],
  );
}
