import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/utils/ad_debug_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('agentDebugLogToFile does not throw without path_provider plugin', () async {
    await expectLater(
      agentDebugLogToFile(
        sessionId: 'test',
        fileName: 'test-agent.log',
        location: 'test',
        message: 'hello',
        hypothesisId: 'H1',
      ),
      completes,
    );
  });
}
