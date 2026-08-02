# Field Time Version

## Identificacao

- Produto: JKDD Field - Field Time
- Empresa: JKDD Tech
- Versao encontrada no `pubspec.yaml`: `1.0.0+10`
- Versao oficial aprovada: `v1.0.0 - Field Operations Baseline`
- Nome da versao aprovado: Field Operations Baseline
- Data: 2026-08-02
- Status: Aprovada para baseline oficial; numero do `pubspec.yaml` mantido em `1.0.0+10`.
- Pasta oficial atual: `C:\Users\SANTANA\Documents\Codex\JKDD_FIELD\001_SOURCE_CODE\009_JKDD_FIELD_TIME_RECORDS_PRODUCTION`

## Principais funcionalidades

- Registro de entrada em obra.
- Troca de obra durante o dia.
- Encerramento do dia com resumo.
- Timesheet por periodo.
- Registro de observacoes do periodo.
- Foto de obra por camera ou galeria.
- Anexo de recibo e pedido de reembolso.
- Persistencia local no dispositivo.
- Indicadores de status online/offline e pendencias de sincronizacao.

## Plataformas disponiveis

- Android: disponivel na estrutura do projeto.
- iOS: disponivel na estrutura do projeto.
- Web: disponivel e com build web ja documentado anteriormente.
- Windows: disponivel na estrutura do projeto.
- Linux: nao configurado.
- macOS: nao configurado.

## Limitacoes conhecidas

- O caminho oficial provisorio nao esta inicializado como repositorio Git.
- Nao ha remoto, branch ou ultimo commit confirmavel neste diretorio.
- `assets` nao existe na raiz e nao esta declarado no `pubspec.yaml`.
- A leitura automatica de recibos ainda usa modo mock e exige revisao manual.
- A pasta contem caches e artefatos gerados, incluindo `.dart_tool` e `build`.
- A migracao para `C:\JKDD_PROJECTS` ainda aguarda aprovacao.
- O cache/tooling local `.codex_tooling` foi retirado da arvore fonte para permitir `dart format .` sem atravessar caches Gradle quebrados.

## Proxima versao planejada

- `v1.1.0 - Project Readiness`
- Escopo sugerido: inicializacao do Git oficial, consolidacao de duplicatas, validacao de migracao controlada para `C:\JKDD_PROJECTS`, revisao de assets e confirmacao das plataformas desktop necessarias.
