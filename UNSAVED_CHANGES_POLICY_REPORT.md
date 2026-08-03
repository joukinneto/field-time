# UNSAVED CHANGES POLICY REPORT

Projeto: JKDD Field - Field Time  
Data: 2026-08-02  
Status: política iniciada por edição; cobertura completa pendente.

## Implementado nesta etapa

- O seletor de idioma deixou de salvar automaticamente.
- Alterações de idioma ficam como rascunho local.
- A UI mostra "Alterações não salvas".
- Botão "Salvar alterações" fica desabilitado até haver mudança.
- Botão "Descartar" restaura o idioma atualmente salvo.
- Chaves PT/EN/ES foram adicionadas para mensagens de alterações não salvas.

## Arquivos alterados

- lib/src/presentation/screens/time_records_screen.dart
- lib/src/localization/app_language.dart

## Pendências

- Guardar navegação ao sair da tela de configurações.
- Aplicar a mesma política a todos os formulários administrativos.
- Exibir recuperação de rascunho após reiniciar o app.
- Validar visualmente o fluxo em iPhone Safari.

## Observação

Nenhum comando de teste ou build foi executado porque a tarefa proibiu validação automatizada nesta etapa.
