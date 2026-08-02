# JOBS DATABASE IMPLEMENTATION SUMMARY

Data: 2026-08-02

Produto: Field Time  
Empresa: JKDD TECH  
Base piloto: EWW  
Prestadora piloto: JKDD Finish & Remodeling Corp

## Objetivo

Implementar a primeira etapa oficial da base de dados de obras do JKDD Field, com importação local de uma planilha Excel atualizada pelo usuário.

## Estrutura criada

```text
data_import/
├── input/
├── processed/
├── archive/
└── reports/

assets/
└── data/
    └── jobs.json
```

O usuário deve colocar a planilha atualizada em:

```text
data_import/input/
```

## Planilhas esperadas

Planilha principal:

```text
JKDD FIELD - BANCO DE DADOS DE OBRAS.xlsx
```

Fonte complementar aceita como fallback:

```text
JKDD FIELD - PILOTO COM CONTROLE DE CUSTOS ADMIN.xlsx
```

## Script criado

```text
tool/import_jobs_from_excel.dart
```

Uso planejado:

```bash
dart run tool/import_jobs_from_excel.dart
```

O script:

- procura arquivo Excel em `data_import/input/`;
- prioriza a planilha principal;
- usa a fonte complementar se a principal não existir;
- identifica a aba com cabeçalhos de obras;
- valida cabeçalhos obrigatórios;
- importa obras válidas;
- preserva caracteres especiais;
- preserva números de obra como texto;
- aplica `active` somente quando `Status` estiver vazio;
- detecta `Job_ID` duplicado;
- detecta `Job_Number` duplicado;
- sinaliza campos obrigatórios ausentes;
- sinaliza obras sem endereço;
- preserva o Excel original;
- copia backup da planilha para `data_import/archive/`;
- gera `assets/data/jobs.json`;
- gera `data_import/processed/jobs_last_import.json`;
- gera `data_import/reports/JOBS_IMPORT_REPORT.md`;
- registra obras removidas da nova planilha no relatório.

## Campos tratados

- `Job_ID`
- `Job_Number`
- `Job_Name`
- `Full_Address`
- `Address`
- `City`
- `County`
- `State`
- `ZIP_Code`
- `Country`
- `Latitude`
- `Longitude`
- `Allowed_Radius_ft`
- `Travel_Bonus_Hours`
- `Status`
- `Client`
- `Supervisor`
- `Start_Date`
- `End_Date`
- `Notes`
- `Access_Instructions`

## JSON gerado

Arquivo:

```text
assets/data/jobs.json
```

Formato:

```json
{
  "metadata": {
    "sourceFile": "...",
    "sourceSheet": "...",
    "processedAt": "...",
    "validJobs": 0
  },
  "jobs": []
}
```

## Aplicativo

Arquivos criados:

- `lib/features/jobs/domain/job.dart`
- `lib/features/jobs/data/job_asset_repository.dart`
- `lib/features/jobs/presentation/jobs_import_screen.dart`

O repositório de assets:

- carrega `assets/data/jobs.json`;
- lista obras;
- filtra obras ativas;
- pesquisa por número, nome, endereço e cidade;
- retorna erro claro se o JSON estiver ausente ou inválido;
- funciona offline porque usa asset local do Flutter.

## Integração com Field Time

O carregamento inicial do Field Time tenta ler `assets/data/jobs.json`.

- Se o JSON tiver obras, elas substituem a lista operacional de obras no snapshot carregado.
- Se o JSON estiver vazio, o app preserva o estado operacional atual.
- Se o JSON estiver ausente ou inválido, o erro fica disponível para a tela administrativa.

O seletor de obras foi atualizado para mostrar:

- número da obra;
- nome;
- endereço completo;
- cidade, quando existir;
- status.

Clock-in e switch-job usam somente obras ativas.

## Interface administrativa

Tela criada:

```text
Importação de Obras
```

A tela mostra:

- último arquivo processado;
- última atualização;
- quantidade de obras;
- quantidade de erros;
- botão `Atualizar Obras`;
- botão `Ver Relatório`.

Na versão Web, `Atualizar Obras` mostra instruções locais para substituir a planilha em `data_import/input/` e executar o script. Upload remoto não foi implementado nesta etapa.

## Preservações

Não foram alterados:

- cálculo de horas;
- múltiplas obras no mesmo dia;
- recibos;
- reembolsos;
- timesheet;
- identidade visual;
- Field Calc;
- publicação atual;
- GitHub Pages.

## Não executado por regra da tarefa

- `flutter analyze`
- `flutter test`
- build Web
- APK
- publicação GitHub Pages

## Próxima etapa recomendada

Após revisão, colocar uma planilha real em `data_import/input/`, executar o script de importação e revisar `data_import/reports/JOBS_IMPORT_REPORT.md` antes de usar a base no campo.
