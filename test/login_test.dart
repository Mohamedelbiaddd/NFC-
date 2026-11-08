import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_studio/core/app_config.dart';

void main() {
  test('worker usernames map to the synthetic auth address', () {
    expect(
      AppConfig.loginEmail('ahmad'),
      'ahmad@workers.nfc-studio.internal',
    );
    expect(
      AppConfig.loginEmail('  Ahmad.TV  '),
      'ahmad.tv@workers.nfc-studio.internal',
    );
  });

  test('real e-mail logins pass through untouched', () {
    expect(
      AppConfig.loginEmail('mohamed.elbiad.2025@gmail.com'),
      'mohamed.elbiad.2025@gmail.com',
    );
    expect(AppConfig.loginEmail('   '), isNull);
  });
}
