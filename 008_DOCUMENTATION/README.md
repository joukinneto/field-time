# Etapa 009 - Registro de Ponto

Implementa Clock In, Clock Out, Break, Transfer, validacao GPS/geofence, persistencia local planejada com Drift/SQLite, fila de sincronizacao, Riverpod controllers e testes.

## Arquitetura
- Domain: entidades, enums, value objects, failures e contratos.
- Application: use cases, services, validators, controllers, providers e DTOs.
- Data: tabelas Drift, repositorio local e fila de sync.
- Presentation: tela, estado e widgets.
- Sync: fila, retry/backoff, conflitos, status e logs.
- GPS: localizacao, permissao, precisao, geofence e fallback offline.

## Comandos obrigatorios
- dart format .
- flutter analyze
- flutter test
- dart run build_runner build --delete-conflicting-outputs

## Regras de negocio
- Um trabalhador nao pode ter dois turnos abertos na mesma empresa.
- Clock Out exige turno aberto e nenhuma pausa ativa.
- Break Start exige turno aberto e nenhuma pausa ativa.
- Break End exige pausa ativa.
- Transfer exige turno aberto, sem pausa ativa e obra destino diferente da obra atual.
- GPS precisa ter precisao aceitavel, idade maxima respeitada e distancia dentro do geofence.
