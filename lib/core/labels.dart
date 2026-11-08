import 'package:flutter/material.dart';
import 'i18n.dart';

import 'theme.dart';

Map<String, String> get roleLabels => <String, String>{
  'owner': tr('مالك'),
  'admin': tr('مدير'),
  'editor': tr('محرر ميداني'),
  'viewer': tr('مشاهد'),
};

String roleLabel(String? role) => roleLabels[role] ?? tr('عضو');

Color roleColor(String? role) => switch (role) {
  'owner' => AppColors.warning,
  'admin' => AppColors.primarySoft,
  'editor' => AppColors.accent,
  _ => AppColors.muted,
};

Map<String, String> get activityLabels => <String, String>{
  'profile_created': tr('أضاف شخصاً جديداً'),
  'profile_updated': tr('حدّث بيانات بطاقة'),
  'profile_deleted': tr('حذف بطاقة'),
  'business_created': tr('أضاف نشاطاً تجارياً'),
  'worker_created': tr('أنشأ حساب عامل'),
  'worker_updated': tr('عدّل حساب عامل'),
  'worker_password_reset': tr('أعاد تعيين كلمة مرور عامل'),
  'worker_disabled': tr('غيّر حالة حساب عامل'),
  'worker_deleted': tr('حذف حساب عامل'),
  'card_written': tr('كتب بطاقة NFC'),
  'card_verified': tr('تحقّق من بطاقة NFC'),
  'card_locked': tr('قفل بطاقة NFC'),
  'qr_saved': tr('حفظ رمز QR'),
  'login': tr('سجّل الدخول'),
};

String actionLabel(String action) => activityLabels[action] ?? action;

IconData actionIcon(String action) => switch (action) {
  'profile_created' => Icons.person_add_alt_1_rounded,
  'profile_updated' => Icons.edit_note_rounded,
  'profile_deleted' => Icons.delete_outline_rounded,
  'business_created' => Icons.storefront_rounded,
  'worker_created' => Icons.badge_outlined,
  'worker_updated' => Icons.manage_accounts_outlined,
  'worker_password_reset' => Icons.key_rounded,
  'worker_disabled' => Icons.block_rounded,
  'worker_deleted' => Icons.person_remove_alt_1_rounded,
  'card_written' => Icons.nfc_rounded,
  'card_verified' => Icons.verified_rounded,
  'card_locked' => Icons.lock_rounded,
  'qr_saved' => Icons.qr_code_2_rounded,
  'login' => Icons.login_rounded,
  _ => Icons.history_rounded,
};

Color actionColor(String action) => switch (action) {
  'profile_created' || 'card_written' => AppColors.success,
  'profile_deleted' || 'worker_deleted' || 'worker_disabled' => AppColors.danger,
  'worker_created' || 'worker_password_reset' => AppColors.warning,
  'login' => AppColors.muted,
  _ => AppColors.primarySoft,
};
