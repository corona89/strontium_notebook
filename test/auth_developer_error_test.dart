import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strontium_notebook/services/auth_service.dart';

void main() {
  test('sign_in_failed + 코드 10은 DEVELOPER_ERROR', () {
    expect(
      isGoogleSignInDeveloperError(
        PlatformException(code: 'sign_in_failed', message: 'l1.d: 10:'),
      ),
      isTrue,
    );
  });

  test('다른 실패는 아님', () {
    expect(
      isGoogleSignInDeveloperError(
        PlatformException(code: 'sign_in_failed', message: '12501'),
      ),
      isFalse,
    );
  });
}
