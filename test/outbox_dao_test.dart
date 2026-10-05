import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisism_motorista/data/local/daos/outbox_dao.dart';
import 'package:unisism_motorista/data/local/database.dart';

void main() {
  late AppDatabase db;
  late OutboxDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.outboxDao;
  });

  tearDown(() async {
    await db.close();
  });

  test('markOffline mantém item em status RETRYING e não marca FAILED', () async {
    final id = await dao.enqueue(
      op: 'POST',
      path: '/motorista-app/viagens/1/iniciar',
      body: {'kmInicialHodometro': 1000},
      entityKind: 'iniciarViagem',
      entityId: '1',
    );

    // Simula falha offline
    await dao.markOffline(id, 'Sem conexão');

    final pendentes = await dao.pending();
    expect(pendentes.length, 1);
    expect(pendentes.first.status, OutboxStatus.retrying);
    expect(pendentes.first.lastError, 'Sem conexão');
    expect(pendentes.first.attempts, 0); // não deve queimar contagem
  });

  test('recoverOfflineFailed recupera itens marcados erroneamente como FAILED', () async {
    final id = await dao.enqueue(
      op: 'POST',
      path: '/motorista-app/viagens/1/iniciar',
      body: {'kmInicialHodometro': 1000},
      entityKind: 'iniciarViagem',
      entityId: '1',
    );

    // Simula item que anteriormente ficou como FAILED por erro offline
    await dao.markFailed(id, 'Sem conexão com a internet');

    var pendentes = await dao.pending();
    expect(pendentes, isEmpty);

    // Executa recuperação
    final recovered = await dao.recoverOfflineFailed();
    expect(recovered, 1);

    pendentes = await dao.pending();
    expect(pendentes.length, 1);
    expect(pendentes.first.status, OutboxStatus.retrying);
  });
}
