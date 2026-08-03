# TIMESHEET TRAVEL BONUS REPORT

Projeto: JKDD Field - Field Time  
Data: 2026-08-02  
Status: implementado por edição; não validado por comando.

## Regra aplicada

- Travel Bonus é calculado uma vez por obra por dia.
- A chave prática é workerId + jobId + workDate.
- Se Santana retornar para a mesma obra no mesmo dia, o bônus daquela obra não é somado novamente.
- Se houver mais de uma obra com bônus no mesmo dia, cada obra gera uma linha separada.

## Arquivos atualizados

- lib/src/domain/field_time_models.dart
- lib/src/presentation/screens/timesheet_screen.dart
- lib/src/timesheet/timesheet_pdf_service.dart
- tool/import_jobs_from_excel.dart

## Timesheet

- Total de bônus usa WorkDay.travelBonusHours com deduplicação por obra.
- Linhas de Travel Bonus aparecem separadas das horas trabalhadas.
- Total por obra soma horas regulares e bônus separado por obra.

## PDF

- PDF em Letter Landscape mantém linhas normais de trabalho.
- Linhas de Travel Bonus são adicionadas separadamente.
- Rodapé mostra total trabalhado, total de Travel Bonus e total geral.
- O serviço tenta carregar o logo oficial Field Time a partir de assets/branding/field_time/field_time_logo_horizontal.png.

## Importador

- Aliases adicionados para Travel Bonus: Bonus, Bonus Viagem, Bonus de Viagem, Horas Bonus e variações.
- Formatos `+1h`, `+2h`, `1h`, `2h`, `1:00` e `01:00` são aceitos.

## Pendências

- Confirmar em execução real os jobs 315 = 1.0, 630 = 2.0 e 2856 = 1.0, pois o usuário proibiu rodar comandos nesta etapa.
