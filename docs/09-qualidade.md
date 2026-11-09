# MentorIA Acadêmica — Bloco 9: Qualidade e Processo

**Responsável:** Hadson — Pessoa 1, Analista de Requisitos / Product Owner · **Versão:** 1.2 · **Data:** 06/11/2026

Documentos relacionados: [Bloco 1 — Concepção e Escopo](01-concepcao.md) (inclui as premissas P1 a P6) · [Bloco 2 — Requisitos](02-requisitos.md) · Diagramas: [`diagrama-casos-de-uso.drawio`](../diagramas/editaveis/diagrama-casos-de-uso.drawio), [`diagrama-atividades-agendamento.drawio`](../diagramas/editaveis/diagrama-atividades-agendamento.drawio), [`diagrama-atividades-administrativo.drawio`](../diagramas/editaveis/diagrama-atividades-administrativo.drawio)

### 

## 9.1 Glossário

Um vocabulário único evita que o código, o banco e a documentação usem nomes diferentes para a mesma coisa. Os termos abaixo valem para a equipe inteira.

|Termo|Definição|
|-|-|
|**Mentoria**|Atividade de apoio acadêmico em que um mentor ajuda um estudante em uma disciplina.|
|**Sessão**|Um encontro individual de mentoria, com data, hora e duração. No sistema, corresponde a um agendamento que chegou ao status CONCLUIDO.|
|**Estudante**|Usuário que busca mentores, solicita agendamentos e avalia sessões.|
|**Mentor**|Usuário que oferece mentoria em uma ou mais disciplinas, publica horários e decide os pedidos.|
|**Coordenador**|Usuário que acompanha mentorias e consulta relatórios; não altera agendamentos.|
|**Administrador**|Usuário que gerencia contas e perfis.|
|**Perfil (papel)**|Conjunto de permissões de um usuário (RBAC). Cada usuário tem exatamente um perfil nesta versão.|
|**Disciplina**|Componente curricular do catálogo (ex.: Cálculo II).|
|**Catálogo de disciplinas**|Lista oficial de disciplinas, mantida pelo administrador (RF021); os mentores escolhem apenas dela.|
|**Log de auditoria**|Registro de inserção apenas das ações administrativas (autor, ação, alvo, data/hora), sem senha ou token (RNF024).|
|**Disponibilidade (horário)**|Intervalo de tempo publicado por um mentor em que ele pode atender.|
|**Agendamento**|Solicitação de um estudante para ocupar uma disponibilidade, com status próprio.|
|**Agendamento ativo**|Agendamento em status PENDENTE ou CONFIRMADO. Só pode existir um por disponibilidade.|
|**Status**|Estado do agendamento: PENDENTE, CONFIRMADO, RECUSADO, CANCELADO, EXPIRADO ou CONCLUIDO.|
|**Avaliação**|Nota de 1 a 5 e comentário opcional dados pelo estudante a uma sessão concluída.|
|**RBAC**|Controle de acesso baseado em perfis: o que o usuário pode fazer depende do seu perfil.|
|**JWT**|Token assinado que prova a identidade do usuário nas chamadas à API.|
|**Exclusão lógica**|Marcar o registro como inativo em vez de apagá-lo, preservando o histórico.|
|**MoSCoW**|Técnica de priorização: Must, Should, Could, Won’t.|
|**MVP**|Menor versão do produto que entrega o fluxo principal completo (os requisitos Must).|
|**LGPD**|Lei Geral de Proteção de Dados Pessoais (Lei 13.709/2018).|
|**ADR**|Registro de Decisão de Arquitetura: documento curto que explica uma decisão técnica e as alternativas descartadas.|

**Decisão de vocabulário:** usar “agendamento” para o pedido e “sessão” apenas para o encontro realizado, e “disponibilidade” no código e na API (`availability`), “horário” na interface. **Justificativa:** o enunciado mistura “horário”, “agendamento” e “sessão”; fixar o sentido de cada um evita bugs de interpretação entre frontend, backend e testes.

## 9.2 Modelo de domínio

O modelo abaixo é **conceitual**, ou seja, descreve o negócio e não as tabelas. O desenho físico do banco e os diagramas formais (classes e estados em diagrams.net) partem destas definições.

### Entidades e atributos principais

**Nomenclatura compartilhada para o DBA:** `SessaoMentoria` é o nome canônico para o antigo `RegistroSessao`. As entidades de apoio `PerfilMentor` e `LogAuditoria` devem constar na modelagem lógica se as funcionalidades correspondentes permanecerem no escopo. Consulte [modelo do banco](05-banco.md) e [dicionário de dados](dicionario-dados.md).

|Entidade|Atributos principais|Regra central|
|-|-|-|
|**Usuário**|id, nome, e-mail, senha (hash), perfil, ativo, aceite da privacidade (data/hora)|E-mail único; exclusão lógica.|
|**PerfilMentor**|usuário, biografia, formação, contato da sessão|Existe apenas para usuários com perfil Mentor.|
|**Disciplina**|id, nome, código, ativa|Catálogo único, mantido pelo administrador (RF021); disciplina inativa não recebe novas associações e não pode ser excluída se houver mentor ou agendamento ligado (RN09).|
|**MentorDisciplina**|mentor, disciplina|Associação muitos-para-muitos sem repetição.|
|**Disponibilidade**|id, mentor, início, duração (30/45/60), ativa|Sem sobreposição para o mesmo mentor; só datas futuras.|
|**Agendamento**|id, disponibilidade, estudante, disciplina, observação, status, justificativa, criado em, respondido em|No máximo um ativo por disponibilidade.|
|**SessaoMentoria**|agendamento, compareceu, duração real, observações|Um por agendamento concluído.|
|**Avaliação**|agendamento, nota (1 a 5), comentário, data|Uma por sessão; só se compareceu.|
|**Notificação**|usuário, mensagem, lida, data|Opcional (RF018, Could).|
|**LogAuditoria**|id, administrador, ação, alvo (tipo e id), data/hora|Somente inserção; sem senha ou token; retenção de 12 meses (RNF024).|

### Relacionamentos

|Relacionamento|Cardinalidade|Observação|
|-|-|-|
|Usuário (Mentor) — Disponibilidade|1 para N|Um mentor publica várias disponibilidades.|
|Mentor — Disciplina|N para N|Via MentorDisciplina.|
|Disponibilidade — Agendamento|1 para N (histórico), **no máximo 1 ativo**|Pode ter vários agendamentos ao longo do tempo (recusados, cancelados), mas apenas um ativo.|
|Usuário (Estudante) — Agendamento|1 para N|Um estudante solicita vários agendamentos.|
|Agendamento — SessaoMentoria|1 para 0..1|Existe após a conclusão.|
|Agendamento — Avaliação|1 para 0..1|Existe se o estudante avaliar.|
|Usuário (Administrador) — LogAuditoria|1 para N|Cada ação administrativa gera um registro.|

### Ciclo de vida do agendamento (máquina de estados)

|De|Para|Quem dispara|Condição|
|-|-|-|-|
|(novo)|PENDENTE|Estudante|Disponibilidade livre; sem conflito do estudante|
|PENDENTE|CONFIRMADO|Mentor|Dono da disponibilidade|
|PENDENTE|RECUSADO|Mentor|Justificativa obrigatória|
|PENDENTE|EXPIRADO|Sistema|48 h sem resposta|
|PENDENTE ou CONFIRMADO|CANCELADO|Estudante (até 2 h antes), Mentor (com justificativa) ou Sistema (quando o administrador desativa o mentor ou o estudante, RN07)|Antes do início|
|CONFIRMADO|CONCLUIDO|Mentor|Horário da sessão já passou|

**Decisão:** os estados finais não têm saída (um agendamento recusado não “volta”; o estudante cria outro). **Justificativa:** preserva a trilha de auditoria e simplifica os relatórios. **Alternativa descartada:** permitir reabrir agendamentos, que complicaria a regra de unicidade do horário ativo.

**Decisões finais de integração:** acrescentam-se RN11 (troca de perfil exige resolução de compromissos futuros), RN12 (cadastro administrativo com aceite prévio do próprio titular e referência de evidência) e RN13 (histórico de disponibilidade imutável). Vide [Bloco 2](02-requisitos.md) e [contrato OpenAPI](../api/openapi.yaml). São regras de projeto e devem receber testes de integração na implementação futura.

## 9.3 Estratégia de testes

### Princípios

1. **Pirâmide de testes:** muitos testes rápidos na base, poucos e caros no topo. Proporção-alvo: \~70% unitários, \~25% integração, \~5% E2E.
2. **Teste a regra de negócio, não o framework.** O valor está em RN01 a RN10 e nos RF, não em verificar o Express.
3. **Rastreabilidade:** cada história de usuário tem ao menos um teste por cenário Given/When/Then; o nome do teste cita o ID (ex.: `US008: bloqueia segunda solicitação ativa`).
4. **Ferramentas oficiais apenas** (escolhas fixadas no projeto): `node:test`, Supertest e Playwright.

### Níveis de teste

|Nível|Ferramenta|O que testa|Dados|Quando roda|
|-|-|-|-|-|
|**Unitário**|`node:test` (com `node:assert`)|Funções e serviços de regra: máquina de estados, sobreposição de horários, validações, hash, emissão e leitura de JWT. Banco simulado por funções falsas.|Dados em memória|A cada commit (local) e em cada pull request|
|**Integração**|`node:test` + Supertest|Rotas HTTP reais com PostgreSQL de teste: autenticação, RBAC (401/403), revalidação de usuário ativo e perfil a cada requisição (RN10), desativação com cancelamento em cascata (RN07), validações (400), conflito (409), índice único, paginação, concorrência.|Banco de teste separado, recriado por migração; limpeza entre testes|Em cada pull request|
|**E2E (planejado)**|Playwright|Jornadas completas no navegador, contra um ambiente de teste.|Massa de dados controlada (seed)|Antes de cada release e ao final de cada sprint|

**Decisão:** o PostgreSQL de teste é **real**, não um banco simulado, nos testes de integração. **Justificativa:** a regra mais crítica (um único agendamento ativo) é garantida por um índice do banco; um mock não a exerceria. **Alternativa descartada:** SQLite ou mocks de `pg`, mais rápidos, mas capazes de esconder erros reais de SQL e de concorrência.

### Jornadas E2E planejadas (Playwright)

|ID|Jornada|Cobre|
|-|-|-|
|E2E-1|Fluxo principal completo: estudante solicita → mentor confirma → mentor registra conclusão → estudante avalia|US008, US010, US012, US013|
|E2E-2|Conflito: dois estudantes disputam o mesmo horário|US008, US009|
|E2E-3|Recusa com justificativa e liberação do horário|US010|
|E2E-4|Controle de acesso: cada perfil só acessa suas telas|US003, US014|
|E2E-5|Coordenador gera relatório e exporta CSV|US014, US015|
|E2E-6|Responsividade em 360 px, 768 px e 1280 px|RNF021|
|E2E-7|Administrador desativa um mentor com agendamento ativo: o agendamento vira CANCELADO, o horário é liberado e o acesso do mentor é bloqueado na hora|US003, RNF007|

### Testes não funcionais

* **Carga:** script com k6 ou autocannon simulando 150 usuários simultâneos, uma vez por release (RNF001, RNF002).
* **Segurança:** `npm audit` em cada pull request; testes de 401/403 em todas as rotas (RNF009, RNF011).
* **Acessibilidade e desempenho:** Lighthouse nas telas principais a cada sprint (RNF003, RNF022).
* **Usabilidade:** teste com 5 usuários reais e questionário SUS no piloto (RNF020, RNF023).

### Automação

GitHub Actions executa unitários, integração (com PostgreSQL como serviço do pipeline) e `npm audit` em cada pull request. **Pull request só é aceito com pipeline verde e ao menos 1 revisão.** Os E2E rodam sob demanda e antes de cada release, por serem mais lentos e planejados como etapa posterior.

## 9.4 Metas de cobertura

|Escopo|Métrica|Meta mínima|Meta desejada|Justificativa|
|-|-|-|-|-|
|Regras de negócio (agendamento, disponibilidade, avaliação)|Linhas e ramificações|90%|95%|É o coração do produto e onde um erro causa prejuízo direto.|
|Serviços e utilitários (autenticação, validação)|Linhas|80%|90%|Segurança e validação precisam de alta confiança.|
|Todo o backend|Linhas|75%|85%|Meta global realista para equipe pequena.|
|Todo o backend|Ramificações|65%|75%|Ramificações são mais difíceis de cobrir; meta menor.|
|Rotas da API|Endpoints com teste de integração|100%|100%|Cada endpoint tem caminho feliz, 401/403 e um erro de validação.|
|Histórias de usuário Must|Cenários de aceite automatizados|100%|100%|Garante o MVP em conformidade com o aceite.|
|Jornadas críticas|Testes E2E|6 jornadas (E2E-1 a E2E-5 e E2E-7)|7 jornadas|Cobre o fluxo principal, o acesso e a desativação de usuários.|
|Frontend (JavaScript puro)|Cobertura|Não medida por número|Cobertura indireta via E2E|Medir o frontend simples por linhas gera pouco valor; o E2E valida o comportamento.|

**Como medir:** `node --test --experimental-test-coverage` (confirmar o nome exato da opção na documentação do Node 24 ao configurar). **Política:** a cobertura **não pode diminuir** em um pull request; se ficar abaixo da meta mínima, o pull request é bloqueado. **Ressalva:** cobertura alta não prova qualidade; por isso as metas por história e por jornada complementam os percentuais.

## 9.5 Definition of Ready (DoR)

Uma história só entra na sprint se atender a **todos** os itens:

* \[ ] Escrita no formato “Como \[persona], quero \[ação], para \[objetivo]”.
* \[ ] Tem critérios de aceite Given/When/Then, incluindo ao menos um cenário de erro.
* \[ ] Está ligada a um ou mais RF e a requisitos não funcionais aplicáveis.
* \[ ] Foi estimada em story points pelo time (Planning Poker) e não passa de 8 pontos; acima disso, é dividida.
* \[ ] Dependências identificadas (ex.: US008 depende de US005) e resolvidas ou planejadas.
* \[ ] Regras de negócio e textos de erro esclarecidos com o PO.
* \[ ] Protótipo ou esboço da tela disponível, se houver interface.
* \[ ] Cabe em uma sprint e é testável de forma independente.

**Por que importa:** história mal definida é a maior causa de retrabalho; a DoR protege a sprint e a equipe.

## 9.6 Definition of Done (DoD)

### Nível de história — uma história só está pronta se:

* \[ ] Todos os critérios de aceite foram implementados e demonstrados ao PO.
* \[ ] Código revisado por pelo menos 1 colega via pull request, sem pendências.
* \[ ] Testes unitários e de integração escritos e passando; pipeline do GitHub Actions verde.
* \[ ] Cobertura da história dentro das metas da seção 9.4, sem queda da cobertura geral.
* \[ ] Consultas SQL parametrizadas; nenhum segredo no código (tudo no `.env`, fora do GitHub).
* \[ ] Rotas protegidas por RBAC, com teste de 401 e 403.
* \[ ] Endpoint documentado no OpenAPI 3.0 e documentação em Markdown atualizada.
* \[ ] Interface responsiva (360 px a 1920 px) e sem erros no console do navegador.
* \[ ] Mensagens de erro em português claro e sem dados sensíveis em logs.
* \[ ] Implantada no ambiente de teste e sem defeitos conhecidos de severidade alta.

### Nível de sprint e de release

* \[ ] **Sprint:** todas as histórias da meta cumprem a DoD; Sprint Review feita com o PO; Retrospectiva registrada em Markdown.
* \[ ] **Release:** E2E-1 a E2E-5 e E2E-7 passando; teste de carga atendendo RNF001 e RNF002; `npm audit` sem altas ou críticas; backup restaurado com sucesso; HTTPS ativo e verificado; política de privacidade publicada.

## 9.7 Metodologia: Scrum

### Comparação Scrum × Kanban

|Critério|Scrum|Kanban|Melhor aqui|
|-|-|-|-|
|Estrutura de tempo|Sprints fixas de 2 semanas com meta|Fluxo contínuo, sem iterações|Scrum: o trabalho acadêmico tem prazos e entregas marcadas|
|Planejamento|Planning por sprint, estimativas em pontos|Pull contínuo, foco em lead time|Scrum: permite prever quanto cabe até a entrega|
|Papéis|Product Owner, Scrum Master, Time|Sem papéis obrigatórios|Scrum: o enunciado já define Hadson como PO|
|Mudança de prioridade|Entre sprints (protege o time)|A qualquer momento|Neutro: escopo fechado favorece Scrum|
|Cerimônias|Planning, Daily, Review, Retrospectiva|Opcionais|Scrum: a Review gera evidências para o trabalho acadêmico|
|Métricas|Velocidade, burndown|Lead time, WIP|Scrum: velocidade ajuda a negociar o escopo|
|Overhead|Médio|Baixo|Kanban, mas o overhead é aceitável para 4 pessoas|
|Adequação a suporte contínuo|Menor|Maior|Kanban seria melhor após a entrega, em manutenção|

**Decisão: Scrum, com um quadro Kanban dentro da sprint** (colunas A fazer, Em andamento, Em revisão, Pronto), no GitHub Projects.

**Justificativa:** (1) o prazo é fixo e acadêmico, o que combina com sprints com meta; (2) a equipe é pequena e inexperiente em processos, e os eventos do Scrum dão ritmo e pontos de verificação; (3) a velocidade medida permite renegociar escopo de forma objetiva usando a priorização MoSCoW; (4) a Sprint Review produz evidência documentada. **Alternativa descartada:** Kanban puro, por não dar previsibilidade de entrega. **Quando reconsiderar:** após a entrega, em fase de manutenção, o Kanban seria mais adequado.

### Adaptações honestas

* **Equipe de estudantes com outras matérias:** a capacidade real é menor que em um time profissional; por isso a velocidade assumida (20 a 25 pontos) é conservadora e será recalibrada após a Sprint 1.
* **Scrum Master:** função rotativa entre os membros a cada sprint, para todos praticarem a facilitação. Hadson mantém o papel fixo de PO.
* **Daily:** 15 minutos, assíncrona por mensagem em dias sem encontro presencial.

### Cerimônias

|Evento|Duração|Frequência|Resultado|
|-|-|-|-|
|Sprint Planning|1 h 30 min|Início da sprint|Meta e backlog da sprint|
|Daily|15 min|Diária (ou assíncrona)|Bloqueios identificados|
|Refinamento|1 h|Meio da sprint|Histórias prontas pela DoR|
|Sprint Review|1 h|Fim da sprint|Demonstração ao PO e feedback|
|Retrospectiva|45 min|Fim da sprint|1 a 3 melhorias acionáveis|

### Proposta de plano de sprints

|Sprint|Meta|Histórias|Pontos|
|-|-|-|-|
|0|Fundação: repositório, ambiente, pipeline, esquema do banco, spikes (PostgreSQL, Nginx)|Não pontuada|—|
|1|Acesso, administração e catálogo|US001, US002, US003, US016|17|
|2|Cadastros do mentor e descoberta|US004, US005, US006, US007|16|
|3|Solicitação e resposta (núcleo de risco)|US008, US009, US010|18|
|4|Fechamento do fluxo principal e acompanhamento|US011, US012, US013, US014|16|
|5|Relatórios e estabilização (E2E, carga, ajustes)|US015|8|
|**Total**||**16 histórias**|**75**|

**Por que essa ordem:**

* **US016 antes de US004:** o mentor só cadastra disciplinas se o catálogo existir.
* **US003 na Sprint 1 (8 pontos):** usuários, perfis e a revalidação por requisição (RN10) sustentam todas as demais histórias; é melhor acertar cedo.
* **US008 e US009 juntas na Sprint 3:** o índice único parcial e a resposta 409 nascem com a solicitação, e a Sprint 3 concentra o maior risco do MVP cedo o bastante para haver tempo de corrigir.
* **Sprint 1 abaixo do teto:** a equipe ainda está calibrando velocidade e dominando PostgreSQL e Nginx.
* **Sprint 5 leve em pontos de propósito:** absorve E2E, teste de carga e ajustes; é folga de qualidade, não ociosidade.

**Mudança em relação à versão 1.0:** o plano passou de 4 para 5 sprints. Com 75 pontos e velocidade de 20 a 25, 4 sprints seriam possíveis no papel, mas sem sprint de estabilização; manter a última leve é a decisão mais segura para um MVP com concorrência e controle de acesso.

### Métricas do processo

|Métrica|Meta|
|-|-|
|Velocidade da sprint|Recalibrada após a Sprint 1; variação de até 20% entre sprints|
|Histórias concluídas ÷ planejadas|≥ 85%|
|Defeitos de severidade alta abertos ao fim da sprint|0|
|Tempo de revisão de pull request|≤ 24 h|
|Pipeline verde na branch principal|100% do tempo|

\---

# Pendências e próximos passos

## Pontos para a equipe confirmar

|#|Ponto|Padrão assumido|
|-|-|-|
|1|Tamanho da equipe e velocidade|4 profissionais na equipe hipotética de implementação (trio acadêmico = 3 pessoas); 20 a 25 pontos por sprint (P5)|
|2|Escala de uso do piloto|1.500 estudantes, 120 mentores, 150 simultâneos (P1, P2)|
|3|Plano e custo da AWS|Lightsail staging 1 GB + produção 2 GB; subtotal US$ 19/mês (instâncias), total ilustrativo US$ 21,60–23,60/mês com snapshots e domínio; **conferir impostos, região e consumo**|
|4|Regra de cancelamento|Estudante até 2 h antes; expiração de pendência em 48 h|
|5|Anonimato das avaliações para o coordenador|Sem nome do estudante (RNF018)|
|6|Notificações e recuperação de senha por e-mail|Opcionais, fora do MVP (RF003 Should, RF018 Could)|
|7|**RF021 e US016 (catálogo de disciplinas)**|Mantidos: o projeto pede **mínimo** de 20 RF e 15 histórias; 21 RF e 16 US são válidos|
|8|Desativar usuário cancela os agendamentos ativos futuros (RN07)|Cancelamento automático com liberação dos horários; regra nova, a aprovar pelo PO|
|9|Revalidação de usuário ativo e perfil no banco a cada requisição (RN10, RNF007)|Adotada; custo de uma consulta extra por requisição, aceitável na escala de P2. Registrar no ADR de autenticação|
|10|Retenção de 12 meses da trilha de auditoria (RNF024)|Validar com o encarregado de dados (LGPD)|



