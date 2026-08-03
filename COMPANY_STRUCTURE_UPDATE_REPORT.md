# COMPANY STRUCTURE UPDATE REPORT

Projeto: JKDD Field - Field Time  
Data: 2026-08-02  
Status: atualizado por edição; sem testes executados.

## Estrutura oficial preservada

- Contratante: EWW.
- Empresa prestadora: JKDD Finish & Remodeling Corp.
- Responsável/colaborador: Santana.
- Employee ID: TER-0001.

Hierarquia operacional:

EWW -> JKDD Finish & Remodeling Corp -> Santana

## Campos preservados/criados

- contractingCompanyId: alias de companyId.
- subcontractorCompanyId: alias de subcontractor.id.
- responsibleWorkerId: alias de worker.id.

Esses campos foram incluídos na serialização do snapshot para deixar a estrutura explícita sem migrar dados antigos.

## Dados alterados

- assets/data/employees.json: supervisor alterado de nome antigo para Santana.
- Telefones fictícios removidos do JSON operacional.
- EMPLOYEES_IMPORT_REPORT.md atualizado para registrar a remoção dos telefones fictícios.

## Módulos impactados

- Home.
- Check-in/check-out por carregamento do snapshot.
- Troca de obra.
- Recibos e reembolsos, por preservação do worker/subcontractor no snapshot.
- Timesheet e PDF.
- Supervisor Center seed.

## Riscos

- Dados já salvos em dispositivos com nomes antigos precisam ser validados em runtime.
- A migração feita nesta etapa atualiza o perfil carregado sem apagar histórico, mas não foi executado teste automatizado.
