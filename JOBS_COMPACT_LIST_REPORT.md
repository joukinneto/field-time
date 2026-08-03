# JOBS COMPACT LIST REPORT

Projeto: JKDD Field - Field Time  
Data: 2026-08-02  
Status: implementado por edição; revisão visual pendente.

## Arquivo principal

- lib/src/presentation/screens/time_records_screen.dart

## Mudanças implementadas

- Lista de obras deixou de usar cartões grandes.
- Mobile usa linhas compactas de obra.
- Desktop usa até duas colunas compactas.
- A linha principal mostra número, nome, status e indicador de Travel Bonus quando o bônus é maior que zero.
- Endereço completo não aparece mais na linha principal.
- Busca por número, nome, endereço e cidade.
- Filtros: ativa, inativa, com bônus e todas.
- Toque na obra abre detalhes.

## Detalhes da obra

Mostra, quando houver dado real:

- número;
- nome;
- endereço;
- cidade/estado/ZIP;
- status;
- Travel Bonus;
- cliente;
- supervisor;
- empresa prestadora;
- instruções de acesso;
- link pesquisável de mapa.

## Nova obra

- Botão de solicitação de nova obra incluído.
- O formulário coleta número, nome, endereço, cidade, estado, ZIP e nota.
- Duplicidade por número ou endereço é sinalizada.
- Nenhuma obra nova é persistida nesta etapa.

## Pendências

- Implementar abertura nativa do app de mapas com dependência própria após aprovação.
- Diferenciar visualmente botão de supervisor/admin versus colaborador após revisar permissões finais.
