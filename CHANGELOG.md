# Changelog

Todas as mudancas notaveis do Field Time serao documentadas neste arquivo.

## [Nao publicado]

- Sem mudancas funcionais apos a aprovacao da versao `v1.0.0 - Field Operations Baseline`.
- `pubspec.yaml` preservado em `1.0.0+10`.

## [v1.0.0 - Field Operations Baseline] - 2026-08-02

Status: aprovado como baseline oficial em 2026-08-02.

### Incluido

- Aplicativo Flutter Field Time para registro de ponto em campo.
- Fluxos de registrar entrada, trocar obra e encerrar dia.
- Captura de foto de obra e anexo de recibos para reembolso.
- Timesheet por hoje, semana, mes e ano.
- Persistencia local multiplataforma com `shared_preferences`.
- Suporte Web, Android, iOS e Windows no projeto oficial provisorio.
- Estrutura de testes unitarios, widget e integracao.
- Documentacao de auditoria, validacao, marca e status de versao.

### Alterado

- Diretrizes visuais aprovadas aplicadas ao tema Material 3, faixa de identidade, botoes, badges e aviso de recibos.
- Superficies, bordas e estados ajustados para uma interface operacional mais consistente com Field Time by JKDD Tech.
- `.codex_tooling/` adicionada ao ignore do projeto e cache/tooling local removido da arvore fonte para evitar falha de `dart format .` em cache Gradle quebrado.

### Preservado

- Numero de versao no `pubspec.yaml`: `1.0.0+10`.
- Logica de negocio, GPS, sincronizacao, persistencia e APIs existentes.
- Localizacao oficial provisoria do projeto.

### Limitacoes conhecidas

- O projeto oficial provisorio ainda nao possui repositorio Git inicializado neste caminho.
- `linux`, `macos` e `assets` nao existem na raiz atual.
- Leitura automatica de recibos permanece em modo mock/revisao manual.
- Build Web local precisa ser validado no ambiente do SDK Flutter disponivel.
