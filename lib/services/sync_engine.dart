/// 로컬/원격 시각과 dirty 플래그로 동기화 동작을 결정한다.
/// 최신 frontmatter `updated`가 이긴다. 같은 시각이면 로컬 dirty가 이긴다.
enum SyncOp {
  skip,
  push,
  pull,
  pushKeepRemoteConflict,
  pullKeepLocalConflict,
  trashLocal,
}

class SyncVerdict {
  const SyncVerdict(this.op, {this.reason = ''});

  final SyncOp op;
  final String reason;
}

class SyncEngine {
  const SyncEngine();

  SyncVerdict decide({
    required bool localExists,
    required bool remoteExists,
    required bool localDirty,
    required DateTime? localUpdated,
    required DateTime? remoteUpdated,
    required bool contentsDiffer,
    required bool remoteDeletedKnown,
  }) {
    if (!localExists && !remoteExists) {
      return const SyncVerdict(SyncOp.skip, reason: '양쪽 없음');
    }
    if (!localExists && remoteExists) {
      return const SyncVerdict(SyncOp.pull, reason: '원격만 있음');
    }
    if (localExists && !remoteExists) {
      if (remoteDeletedKnown && !localDirty) {
        return const SyncVerdict(SyncOp.trashLocal, reason: '원격에서 삭제됨');
      }
      return const SyncVerdict(SyncOp.push, reason: '로컬만 있음');
    }

    final localTs = localUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteTs = remoteUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
    final cmp = localTs.compareTo(remoteTs);

    if (!contentsDiffer) {
      if (localDirty) {
        return const SyncVerdict(SyncOp.push, reason: '내용 동일, dirty 해제용 푸시');
      }
      return const SyncVerdict(SyncOp.skip, reason: '내용 동일');
    }

    if (cmp > 0) {
      return const SyncVerdict(
        SyncOp.pushKeepRemoteConflict,
        reason: '로컬 updated가 더 최신',
      );
    }
    if (cmp < 0) {
      if (localDirty) {
        return const SyncVerdict(
          SyncOp.pullKeepLocalConflict,
          reason: '원격이 더 최신, 로컬 수정분 보존',
        );
      }
      return const SyncVerdict(SyncOp.pull, reason: '원격이 더 최신');
    }

    // 시각이 같으면 로컬 dirty가 이긴다. 그래도 원격 내용은 충돌 사본으로 남긴다.
    if (localDirty) {
      return const SyncVerdict(
        SyncOp.pushKeepRemoteConflict,
        reason: '동일 시각, 로컬 dirty',
      );
    }
    return const SyncVerdict(SyncOp.pull, reason: '동일 시각, 로컬 비dirty');
  }
}
