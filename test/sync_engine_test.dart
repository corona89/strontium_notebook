import 'package:flutter_test/flutter_test.dart';
import 'package:strontium_notebook/services/sync_engine.dart';

void main() {
  const engine = SyncEngine();

  test('원격만 있으면 pull', () {
    final v = engine.decide(
      localExists: false,
      remoteExists: true,
      localDirty: false,
      localUpdated: null,
      remoteUpdated: DateTime.utc(2026, 1, 1),
      contentsDiffer: true,
      remoteDeletedKnown: false,
    );
    expect(v.op, SyncOp.pull);
  });

  test('로컬이 더 최신이면 원격 충돌 사본을 남기고 push', () {
    final v = engine.decide(
      localExists: true,
      remoteExists: true,
      localDirty: true,
      localUpdated: DateTime.utc(2026, 2, 1),
      remoteUpdated: DateTime.utc(2026, 1, 1),
      contentsDiffer: true,
      remoteDeletedKnown: false,
    );
    expect(v.op, SyncOp.pushKeepRemoteConflict);
  });

  test('원격이 더 최신이고 로컬 dirty면 로컬을 충돌 사본으로', () {
    final v = engine.decide(
      localExists: true,
      remoteExists: true,
      localDirty: true,
      localUpdated: DateTime.utc(2026, 1, 1),
      remoteUpdated: DateTime.utc(2026, 2, 1),
      contentsDiffer: true,
      remoteDeletedKnown: false,
    );
    expect(v.op, SyncOp.pullKeepLocalConflict);
  });

  test('원격 삭제 + 로컬 비dirty면 로컬 휴지통', () {
    final v = engine.decide(
      localExists: true,
      remoteExists: false,
      localDirty: false,
      localUpdated: DateTime.utc(2026, 1, 1),
      remoteUpdated: null,
      contentsDiffer: true,
      remoteDeletedKnown: true,
    );
    expect(v.op, SyncOp.trashLocal);
  });

  test('내용이 같으면 skip', () {
    final v = engine.decide(
      localExists: true,
      remoteExists: true,
      localDirty: false,
      localUpdated: DateTime.utc(2026, 1, 1),
      remoteUpdated: DateTime.utc(2026, 2, 1),
      contentsDiffer: false,
      remoteDeletedKnown: false,
    );
    expect(v.op, SyncOp.skip);
  });
}
