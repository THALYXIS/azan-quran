import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';

// ═════════════════════════════════════════════════════════════
//  إعدادات حساب المواقيت (مشتركة بين صفحة المواقيت وصفحة الإعدادات)
// ═════════════════════════════════════════════════════════════

class MethodOption {
  const MethodOption(this.id, this.method, this.label);
  final String id;
  final CalculationMethod method;
  final String label;
}

const List<MethodOption> kMethods = [
  MethodOption(
      'egyptian', CalculationMethod.egyptian, 'الهيئة المصرية العامة للمساحة'),
  MethodOption(
      'umm_al_qura', CalculationMethod.umm_al_qura, 'أم القرى (مكة المكرمة)'),
  MethodOption('muslim_world_league', CalculationMethod.muslim_world_league,
      'رابطة العالم الإسلامي'),
  MethodOption('karachi', CalculationMethod.karachi,
      'جامعة العلوم الإسلامية بكراتشي'),
  MethodOption('dubai', CalculationMethod.dubai, 'دبي'),
  MethodOption('qatar', CalculationMethod.qatar, 'قطر'),
  MethodOption('kuwait', CalculationMethod.kuwait, 'الكويت'),
  MethodOption('singapore', CalculationMethod.singapore, 'سنغافورة'),
  MethodOption('north_america', CalculationMethod.north_america,
      'أمريكا الشمالية (ISNA)'),
  MethodOption('moon_sighting_committee',
      CalculationMethod.moon_sighting_committee, 'لجنة رؤية الهلال'),
];

MethodOption methodById(String id) =>
    kMethods.firstWhere((m) => m.id == id, orElse: () => kMethods[2]);

/// يختار طريقة الحساب المناسبة حسب الدولة (ويقدر المستخدم يغيّرها)
String autoMethodId(String? cc) {
  switch (cc?.toUpperCase()) {
    case 'EG':
    case 'SD':
    case 'LY':
      return 'egyptian';
    case 'SA':
      return 'umm_al_qura';
    case 'AE':
      return 'dubai';
    case 'QA':
      return 'qatar';
    case 'KW':
      return 'kuwait';
    case 'PK':
    case 'IN':
    case 'BD':
    case 'AF':
      return 'karachi';
    case 'SG':
    case 'MY':
    case 'ID':
      return 'singapore';
    case 'US':
    case 'CA':
      return 'north_america';
    default:
      return 'muslim_world_league';
  }
}

/// صفحة الإعدادات بتزوّد الرقم ده لما أي إعداد يتغيّر،
/// وصفحة المواقيت بتسمعه وتعيد الحساب والجدولة.
final ValueNotifier<int> settingsChanged = ValueNotifier<int>(0);

void notifySettingsChanged() => settingsChanged.value++;