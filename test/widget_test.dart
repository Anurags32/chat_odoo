import 'package:flutter_test/flutter_test.dart';
import 'package:nspl_odoo/features/call/data/models/call_model.dart';
import 'package:nspl_odoo/features/call/data/providers/call_provider.dart';

void main() {
  group('CallModel & CallStateData State Machine Tests', () {
    test('Default CallStateData should be idle with no active call', () {
      final state = CallStateData();
      expect(state.status, CallState.idle);
      expect(state.activeCall, isNull);
      expect(state.isIncoming, isFalse);
      expect(state.isMuted, isFalse);
      expect(state.isSpeakerOn, isTrue);
      expect(state.durationSeconds, 0);
    });

    test(
      'Outgoing call initiation enters connecting state with participant info',
      () {
        final state = CallStateData(
          activeCall: CallModel(
            id: 42,
            callType: CallType.audio,
            state: CallState.connecting,
            startTime: DateTime.now(),
            caller: CallParticipant(partnerId: 1, name: 'Me'),
            callee: CallParticipant(partnerId: 99, name: 'Alice'),
          ),
          status: CallState.connecting,
          isIncoming: false,
          channelId: 42,
          partnerName: 'Alice',
        );

        expect(state.status, CallState.connecting);
        expect(state.isIncoming, isFalse);
        expect(state.channelId, 42);
        expect(state.partnerName, 'Alice');
        expect(state.activeCall?.callee.partnerId, 99);
      },
    );

    test('CallModel.copyWith updates status, id, and duration accurately', () {
      final initialCall = CallModel(
        id: 10,
        callType: CallType.video,
        state: CallState.connecting,
        startTime: DateTime.now(),
        caller: CallParticipant(partnerId: 1, name: 'Caller'),
        callee: CallParticipant(partnerId: 2, name: 'Callee'),
      );

      final connectedCall = initialCall.copyWith(
        state: CallState.connected,
        duration: 45,
        answerTime: DateTime.now(),
      );

      expect(connectedCall.state, CallState.connected);
      expect(connectedCall.duration, 45);
      expect(connectedCall.answerTime, isNotNull);
      expect(connectedCall.id, 10);
      expect(connectedCall.callType, CallType.video);
    });

    test(
      'State transition to ended preserves duration and participant record',
      () {
        final call = CallModel(
          id: 77,
          callType: CallType.audio,
          state: CallState.ended,
          startTime: DateTime.now(),
          duration: 120,
          endReason: 'normal',
          caller: CallParticipant(partnerId: 1, name: 'Me'),
          callee: CallParticipant(partnerId: 2, name: 'Bob'),
        );

        final state = CallStateData(
          activeCall: call,
          status: CallState.ended,
          durationSeconds: 120,
        );

        expect(state.status, CallState.ended);
        expect(state.durationSeconds, 120);
        expect(state.activeCall?.endReason, 'normal');
      },
    );
  });
}
