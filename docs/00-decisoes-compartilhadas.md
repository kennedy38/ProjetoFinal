# Decisões compartilhadas — MentorIA Acadêmica

> **Documento de referência do trio.** A versão abaixo integra as decisões já acordadas em conversa. Antes da entrega, Hadson, Kennedy e Guilherme devem validar os requisitos, o DER, os custos e o OpenAPI. Em caso de divergência, atualizar este arquivo **e** os demais blocos.

| Campo | Decisão atual |
|---|---|
| Nome do produto | **MentorIA Acadêmica** |
| Domínio | EdTech — gestão de mentorias acadêmicas |
| Quatro atores | Estudante, Mentor, Coordenador, Administrador |
| Arquitetura | Monólito modular |
| Frontend | HTML5, CSS3, JavaScript e Bootstrap 5.3 |
| Runtime/backend | Node.js 24 LTS e Express 5 |
| API | REST + JSON via HTTPS; documentação OpenAPI 3.0 |
| Banco | PostgreSQL com biblioteca `pg` e SQL parametrizado |
| Autenticação / autorização | JWT, `bcryptjs`, RBAC; validar requisitos de segurança e expiração |
| Infraestrutura de referência | AWS Lightsail/Linux + Nginx; staging 1 GB (US$ 7) + produção 2 GB (US$ 12), preços-base AWS; snapshots, domínio, região e impostos ainda dependem de validação de Guilherme |
| Padrões | Controller + Service Layer + Repository |
| Método de documentação | Markdown, draw.io (`.drawio` e `.png`), GitHub |

## Vocabulário comum

- **Disponibilidade:** horário oferecido por um mentor.
- **Agendamento:** pedido feito por estudante para ocupar uma disponibilidade; começa em `PENDENTE`.
- **Sessão de mentoria:** atendimento efetivamente realizado.
- **Avaliação:** opinião do estudante sobre uma sessão já concluída.
- **Notificação:** aviso interno ao aplicativo; não depende de e-mail/SMS.
- **Perfis:** `ESTUDANTE`, `MENTOR`, `COORDENADOR`, `ADMINISTRADOR`.
- **Status de agendamento:** `PENDENTE`, `CONFIRMADO`, `RECUSADO`, `CANCELADO`, `EXPIRADO`, `CONCLUIDO`.
- **Reserva ativa:** somente `PENDENTE` e `CONFIRMADO`; apenas um pedido ativo por disponibilidade.

## Processo principal

Estudante busca mentor e consulta disponibilidade → envia solicitação → sistema registra `PENDENTE` (sem duplicar reserva ativa) → mentor confirma ou recusa → sessão ocorre → mentor registra conclusão → estudante avalia sessão concluída.

## Escopo excluído

Pagamentos/Pix, IA funcional, videochamada nativa, aplicativo móvel nativo, chat em tempo real e integração com e-mail/SMS nesta versão de referência. Se algum item se tornar requisito obrigatório, revisar arquitetura e custos.

## Entidades-base para validação com o DBA

`Usuario`, `PerfilMentor`, `Disciplina`, `MentorDisciplina`, `Disponibilidade`, `Agendamento`, `SessaoMentoria`, `Avaliacao`, `Notificacao` (Could) e `LogAuditoria`. `AutenticacaoService` e `AgendamentoService` são serviços de aplicação, **não** tabelas.

## Padrões e responsabilidades

- **Hadson:** visão do produto, RF/RNF, 16 histórias de usuário, casos de uso, duas atividades UML e qualidade.
- **Kennedy:** documento do Bloco 3, ADRs, C4 (4 níveis), classes e três sequências; integração de nomenclaturas.
- **Guilherme:** banco conceitual/lógico/físico, dicionário LGPD, custos e estimativas, componentes UML, implantação, API e documentação para desenvolvedor.

## Critérios de coerência

1. RF e US precisam corresponder às rotas e fluxos representados no UML e no OpenAPI.
2. O banco deve garantir uma única reserva ativa por disponibilidade, preservando o histórico de recusas/cancelamentos.
3. Não afirmar SLA de 99,9% sem infraestrutura redundante e capacidade de failover.
4. Para custos: link oficial, região, configuração, premissas, data e unidade de cobrança; não inventar valores.
5. Diagramas: título, autores, data no **diagrama**; os slides não exigem data separada.
6. Decisões técnicas: justificar com alternativa descartada; ADRs mantidos como **Propostos** até revisão do grupo.

## Pendências interdependentes

- [x] Hadson entregou 21 RF, 16 US e métricas RNF. [ ] Revisar/aceitar os alinhamentos da versão 1.2.
- [ ] Guilherme confirma entidades, FKs, multiplicidades, migrações, índice parcial de reserva ativa e SQL executável.
- [ ] Guilherme confirma infraestrutura e custo com fonte real; Hadson insere na viabilidade.
- [ ] Guilherme confirma endpoints REST/OpenAPI 3.0 e erros `201`, `401`, `403`, `404`, `409`.
- [ ] Kennedy revê C4 Nível 4 e multiplicidades do diagrama de classes após esses alinhamentos.

## Regras complementares aprováveis pelo trio

- A solicitação inicial gera um agendamento `PENDENTE`; apenas o mentor poderá confirmar ou recusar posteriormente.
- Cada disponibilidade pode ter **no máximo um agendamento ativo** (`PENDENTE`/`CONFIRMADO`) por vez; solicitações recusadas ou canceladas permanecem no histórico e não impedem nova solicitação.
- O horário deverá ser futuro para novas solicitações; avaliação só é permitida após a sessão concluída.
- Na primeira versão, cada usuário possui um perfil de acesso; alterações de perfil passam pela administração.
- Notificações são internas; e-mail e SMS externos permanecem fora do escopo.
- O JWT de acesso possui validade **proposta de 15 minutos**, alinhada ao RNF007 do Bloco 2; a autenticação deverá conferir titularidade e perfil nos endpoints protegidos.

## Revisões técnicas ainda necessárias

- [x] **Kennedy:** associações `Usuario`–`Agendamento` (estudante/mentor) e multiplicidades corrigidas no UML. **Validação com o banco de Guilherme permanece pendente.**
- [x] **Kennedy:** corrigida a lista de reservas ativas no `.drawio` e no PNG do C4 Nível 4 (revisar visualmente no aplicativo).
- [x] **Guilherme:** índice de unicidade parcial para reservas ativas incluído; [ ] teste concorrente ainda deve ser repetido no PostgreSQL.
- [x] **Guilherme:** DDL, índices, LGPD e OpenAPI compatibilizados documentalmente; [ ] validar em PostgreSQL.
- [ ] **Hadson:** confirmar RFs, histórias, MoSCoW, métricas e regras de negócio.
- [ ] **Guilherme e Hadson:** fundamentar custos reais e estimativas com fontes e premissas verificáveis.

**Status das escolhas:** propostas técnicas documentadas, ainda sujeitas à validação cruzada dos três integrantes.


## Decisões de integração documentadas — 06/11/2026

| Assunto | Regra única | Evidência / validação |
|---|---|---|
| JWT | Token de acesso 15 minutos; sem refresh token; status ativo e perfil consultados em cada rota autenticada | RNF007, RN10, ADR-007; validar testes de segurança |
| Desempenho | p95 ≤ 300 ms nas operações principais/busca, cenário controlado com 150 usuários simultâneos | RNF001/RNF002; **meta não testada** |
| Escala | 10.000 usuários **cadastrados** e 150 simultâneos previstos; 750 concorrentes é cenário futuro de dimensionamento, não promessa | P1/P2, RNF012 |
| Infraestrutura | Local + 1 GB staging + 2 GB produção (duas Lightsail), PostgreSQL junto da API por instância | custo-base US$ 19/mês; total ilustrativo US$ 21,60–23,60; validar com Guilherme |
| Usuário mentor | `PerfilMentor` complementa `Usuario` (opcional 0..1 por usuário do tipo MENTOR); as disciplinas são catálogo da administração | RF006, RF007, RF021 |
| Agendamento | `PENDENTE` bloqueia o horário; expira após 48 horas sem resposta (`EXPIRADO`); só `PENDENTE`/`CONFIRMADO` são ativos | RN01–RN03, RF014 |
| Sessão | `SessaoMentoria` é nome oficial; **não** usar `RegistroSessao` em novos arquivos | Bloco 9, Bloco 4, contrato do DBA |
| Auditoria | `LogAuditoria` registra ações administrativas, retenção-alvo de 12 meses a validar com responsável LGPD | RNF024 |

O grupo de produção acadêmica tem três integrantes; a estimativa de equipe de desenvolvimento futura no Bloco 7 utiliza quatro profissionais hipotéticos.

O modelo definitivo está descrito em [Banco de dados](05-banco.md), [Dicionário de dados](dicionario-dados.md) e [Documentação de desenvolvimento](08-dev.md).


## Integração de Guilherme — revisão de 09/11/2026

- [x] DDL e dicionário entregues; **10 tabelas** com `BIGINT` como PK/FK, `pg`, índice parcial e exclusion constraint; execução da suíte atual T00–T43 (44 casos) ainda pendente.
- [x] Duração das disponibilidades fixada pelo RF008 em **30/45/60 minutos**; OpenAPI e SQL corrigidos.
- [x] RF001: autocadastro somente de **ESTUDANTE**; demais perfis provisionados pela administração com evidência de aceite prévio do titular.
- [x] `POST /api/administracao/usuarios` e CSV de RF020 documentados no OpenAPI; agora **31 operações**.
- [x] Bloco 7 usa as **16 histórias e 75 pontos** de Hadson, **Sprint 0 + 5 sprints**, equipe hipotética por 12 semanas; custo-base projetado **R$ 262.934,16** com contingência.
- [x] AWS detalhada para São Paulo: US$ 19/mês de instâncias; cenário estimado US$ 21,25 antes de impostos, sem garantia de desempenho.
- [x] RPO 24 h, RTO 4 h, disponibilidade 99,5% e p95 ≤ 300 ms são metas ainda não testadas em produção.
- [x] UML de classes harmonizado com `BIGINT` (tipo `Long`) e campos do SQL; PNG atualizado.
- [ ] Executar `sql/schema.sql` e **44 casos SQL T00–T43** em PostgreSQL; não declarar aprovação sem log do banco.
- [x] RN11–RN13 especificadas em requisitos, SQL, dicionário e OpenAPI; [ ] trio precisa ler e ratificar as escolhas propostas.
- [ ] Conferir visualmente os nove UML no Draw.io, aprovar parâmetros e apresentar como projeto hipotético, não como sistema implementado.


## Decisões de compatibilização final — 09/11/2026

As decisões abaixo são a **proposta técnica consolidada para entrega acadêmica**, e precisam ser conhecidas pelos três integrantes; não constituem aprovação individual registrada de Hadson ou Guilherme.

1. **Identificadores:** `Long` no UML significa `BIGINT` PostgreSQL e `integer/int64` no OpenAPI. O `UUID` antigo foi retirado do diagrama de classes. Horários usam `inicioEm: DateTime` e `duracaoMinutos: Int` (banco: `inicio_em`, `duracao_minutos`). `SessaoMentoria` guarda `compareceu` e `duracaoRealMin`; `Avaliacao` aponta para a sessão, sem coluna redundante `estudante_id`.
2. **RN11 — troca de perfil:** o administrador não pode trocar o perfil de mentor que tenha disponibilidades ativas futuras nem reservas futuras PENDENTE/CONFIRMADO; estudante com reservas futuras também deve resolvê-las primeiro. O backend cancela/encerra compromissos e inativa horários, se autorizado, **antes** de solicitar alteração; caso contrário, retorna HTTP 409. A desativação da conta continua seguindo RN07 com cancelamento automático transacional.
3. **RN12 — aceite do titular:** cadastro administrativo só ocorre **depois** de aceite real do titular em canal institucional. O contrato exige `aceiteTitularEm` e `referenciaAceite`; o banco registra origem `INSTITUCIONAL` e referência ao comprovante protegido. Sem evidência, não se cria a conta (HTTP 422). Não se presume que um administrador tenha aceitado a política em nome do usuário. O autocadastro segue a opção `AUTOCADASTRO`.
4. **RN13 — histórico de disponibilidade:** sem agendamento, editar futuro horário é permitido; havendo qualquer agendamento histórico, não alterar mentor/início/duração: inativar o horário e criar outro. Se houver pedido ativo, cancelar/recusar primeiro e só depois inativar. Essa regra protege o snapshot e as chaves estrangeiras do SQL.
5. **SQL:** os casos T00–T43 e o DDL atualizado estão disponíveis **para execução** em PostgreSQL. Sem servidor PostgreSQL acessível nesta revisão, não há alegação de testes executados ou aprovados. As instruções resumidas de execução estão no [README principal](../README.md).

