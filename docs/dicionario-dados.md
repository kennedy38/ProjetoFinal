# Dicionário de Dados — MentorIA Acadêmica

**Bloco 5 — Banco de Dados** · Responsável: Guilherme · Equipe: Hadson, Kennedy e Guilherme
**Versão:** 1.0 · **Data:** 08/11/2026 · **SGBD:** PostgreSQL 16 (compatível com 13+)
**Fonte de verdade:** `sql/schema.sql` (o dicionário descreve exatamente o que o script cria)

---

## 1. Convenções

| Item | Convenção |
|---|---|
| Nomes | `snake_case`, em português, sem acentos; tabelas no plural; colunas no singular |
| Chave primária | `id bigint GENERATED ALWAYS AS IDENTITY` (exceto `perfis_mentor` e `mentor_disciplinas`) |
| Chave estrangeira | `<entidade>_id`, por exemplo, `mentor_id` e `disciplina_id` |
| Datas e horas | `timestamptz`, sempre com fuso; o servidor grava em UTC e a interface exibe no fuso local |
| Booleanos | adjetivo ou particípio: `ativo`, `ativa`, `lida`, `compareceu` |
| Prefixos de constraints | `pk_` PK · `fk_` FK · `uq_` UNIQUE · `ck_` CHECK · `ex_` EXCLUDE · `ix_` índice · `ux_` índice único · `tg_` trigger · `fn_` função · `vw_` visão · `rn_` regra de negócio validada em trigger |
| Mapeamento para o código | `snake_case` no banco ↔ `camelCase` no JavaScript e no UML (`inicio_em` ↔ `inicioEm`) |

### Legenda — obrigatoriedade
**S** = `NOT NULL` · **N** = aceita `NULL`

### Legenda — classificação de dados (LGPD, Lei 13.709/2018)

| Código | Classe | Significado | Tratamento mínimo |
|---|---|---|---|
| **PI-D** | Dado pessoal direto | Identifica a pessoa por si só (nome, e-mail) | Acesso só por quem precisa; nunca em logs técnicos; anonimizar no descarte |
| **PI-C** | Dado pessoal de contato | Meio de contato informado pelo titular | Exibir só às partes da mentoria confirmada |
| **PI-L** | Texto livre | Campo aberto que *pode* conter dado pessoal, inclusive sensível, por iniciativa do usuário | Orientar na interface a não inserir dados sensíveis; limitar tamanho; não expor em relatórios |
| **PI-I** | Dado pessoal indireto | Identificador ou registro de atividade vinculável a uma pessoa (IDs de usuário, datas de ações) | Expor só ao próprio titular, às partes envolvidas e a perfis autorizados |
| **CRED** | Credencial | Material de autenticação | Somente hash bcrypt; nunca retornar pela API; nunca registrar em log |
| **NP** | Não pessoal | Dado de catálogo ou técnico | Sem restrição específica |

> **Dados pessoais sensíveis (art. 5º, II, da LGPD):** o modelo **não coleta** dados sensíveis (saúde, religião, origem racial, biometria, etc.). Os campos PI-L são o único caminho para isso acontecer por acidente e por isso têm tratamento reforçado.

---

## 2. Tabelas

### 2.1 `usuarios`
Pessoas cadastradas na plataforma. Os quatro atores (Estudante, Mentor, Coordenador e Administrador) são **perfis** desta tabela (RBAC). Exclusão lógica via `ativo`.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `id` | bigint | S | identity | PK `pk_usuarios` | Identificador do usuário | PI-I |
| `nome` | varchar(120) | S | — | `ck_usuarios_nome` (≥ 2 caracteres sem espaços nas pontas) | Nome de exibição | PI-D |
| `email` | varchar(254) | S | — | UNIQUE `uq_usuarios_email`; `ck_usuarios_email_minusculo`; `ck_usuarios_email_formato` | Login e identificação; armazenado em minúsculas | PI-D |
| `senha_hash` | varchar(60) | S | — | `ck_usuarios_senha_bcrypt` (formato `$2a$`, `$2b$` ou `$2y$`) | Hash bcrypt gerado pelo `bcryptjs`; **nunca** a senha | CRED |
| `perfil` | varchar(20) | S | — | `ck_usuarios_perfil` ∈ {ESTUDANTE, MENTOR, COORDENADOR, ADMINISTRADOR} | Perfil de acesso (um por usuário na v1) | PI-I |
| `ativo` | boolean | S | `true` | Trigger `tg_usuarios_proteger_ultimo_admin` | Exclusão lógica; inativo não autentica | PI-I |
| `aceite_privacidade_em` | timestamptz | S | — | — | Momento em que o próprio titular aceitou a política; administrativo requer aceite prévio verificável | PI-I |
| `aceite_privacidade_fonte` | varchar(18) | S | `AUTOCADASTRO` | `ck_usuarios_aceite_fonte` | Origem: AUTOCADASTRO ou INSTITUCIONAL | PI-I |
| `aceite_privacidade_referencia` | varchar(120) | N* | — | `ck_usuarios_aceite_referencia`; obrigatório se fonte INSTITUCIONAL | Referência técnica à evidência de aceite custodiada fora do banco | PI-I |
| `criado_em` | timestamptz | S | `now()` | — | Data de cadastro | PI-I |
| `atualizado_em` | timestamptz | S | `now()` | Trigger `tg_usuarios_atualizado_em` | Última alteração do registro | PI-I |

**Índices:** `ix_usuarios_perfil_ativos (perfil) WHERE ativo`.

### 2.2 `perfis_mentor`
Dados complementares de apresentação do mentor (RF006, *Should*). Cardinalidade `Usuario 1 → 0..1 PerfilMentor`.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `usuario_id` | bigint | S | — | PK `pk_perfis_mentor`; FK `fk_perfis_mentor_usuario` → `usuarios.id` (RESTRICT); trigger `tg_perfis_mentor_perfil` (perfil MENTOR e ativo) | Mentor dono do perfil | PI-I |
| `biografia` | varchar(1000) | N | — | — | Apresentação pública do mentor | PI-L |
| `formacao` | varchar(255) | N | — | — | Formação acadêmica declarada | PI-L |
| `contato_sessao` | varchar(255) | N | — | — | Meio de contato ou sala externa para a sessão (sem videochamada própria) | PI-C |

### 2.3 `disciplinas`
Catálogo de disciplinas mantido pela Administração (RF021, *Must*). Exclusão lógica via `ativa`.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `id` | bigint | S | identity | PK `pk_disciplinas` | Identificador | NP |
| `codigo` | varchar(20) | S | — | UNIQUE `uq_disciplinas_codigo`; `ck_disciplinas_codigo` (maiúsculo, ≥ 2 caracteres) | Código institucional, por exemplo, `BD1` | NP |
| `nome` | varchar(120) | S | — | `ck_disciplinas_nome` | Nome da disciplina | NP |
| `ativa` | boolean | S | `true` | — | Disciplina inativa não recebe novos agendamentos | NP |

### 2.4 `mentor_disciplinas`
Associação N:N entre mentores e disciplinas do catálogo.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `mentor_id` | bigint | S | — | PK composta `pk_mentor_disciplinas`; FK `fk_mentor_disciplinas_mentor` → `usuarios.id`; trigger `tg_mentor_disciplinas_perfil` | Mentor | PI-I |
| `disciplina_id` | bigint | S | — | PK composta; FK `fk_mentor_disciplinas_disciplina` → `disciplinas.id` | Disciplina atendida | NP |

**Índices:** PK `(mentor_id, disciplina_id)`; `ix_mentor_disciplinas_disciplina (disciplina_id)` para a busca de mentores por disciplina (RF010).

### 2.5 `disponibilidades`
Horário **oferecido** por um mentor. Disponibilidade não é reserva: a reserva é o agendamento.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `id` | bigint | S | identity | PK `pk_disponibilidades` | Identificador | NP |
| `mentor_id` | bigint | S | — | FK `fk_disponibilidades_mentor` → `usuarios.id`; trigger `tg_disponibilidades_perfil` | Mentor que oferece o horário | PI-I |
| `inicio_em` | timestamptz | S | — | — | Início do horário | PI-I |
| `duracao_minutos` | integer | S | — | `ck_disponibilidades_duracao` (30, 45 ou 60) **[RF008 aprovado no backlog]** | Duração em minutos | NP |
| `ativa` | boolean | S | `true` | — | Horário ofertado ou retirado | NP |
| `criado_em` | timestamptz | S | `now()` | — | Data de criação | NP |

**Restrições de tabela:**
- `uq_disponibilidades_snapshot UNIQUE (id, mentor_id, inicio_em, duracao_minutos)`: alvo da FK composta de `agendamentos`.
- `ex_disponibilidades_mentor_sem_sobreposicao`: `EXCLUDE USING gist (mentor_id WITH =, fn_periodo(inicio_em, duracao_minutos) WITH &&) WHERE (ativa)`. Impede que o **mesmo mentor** tenha duas disponibilidades ativas sobrepostas.

**Índices:** `ix_disponibilidades_mentor_inicio (mentor_id, inicio_em) WHERE ativa` (RF011).

### 2.6 `agendamentos`
Pedido do estudante para ocupar uma disponibilidade. Começa `PENDENTE`. Estados ativos: `PENDENTE` e `CONFIRMADO`. O histórico nunca é apagado.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `id` | bigint | S | identity | PK `pk_agendamentos` | Identificador | PI-I |
| `disponibilidade_id` | bigint | S | — | FK composta `fk_agendamentos_disponibilidade` | Horário solicitado | PI-I |
| `estudante_id` | bigint | S | — | FK `fk_agendamentos_estudante`; trigger `tg_agendamentos_perfil_estudante`; `ck_agendamentos_estudante_nao_e_mentor` | Estudante solicitante | PI-I |
| `mentor_id` | bigint | S | — | FK `fk_agendamentos_mentor`; precisa ser o mesmo da disponibilidade (FK composta) | Mentor responsável | PI-I |
| `disciplina_id` | bigint | S | — | FK `fk_agendamentos_disciplina`; trigger: disciplina ativa e atendida pelo mentor | Disciplina da mentoria | NP |
| `inicio_em` | timestamptz | S | — | Igual ao da disponibilidade (FK composta) **[proposta DBA]** | Cópia controlada do início do horário | PI-I |
| `duracao_minutos` | integer | S | — | Igual ao da disponibilidade (FK composta) **[proposta DBA]** | Cópia controlada da duração | NP |
| `status` | varchar(12) | S | `'PENDENTE'` | `ck_agendamentos_status` ∈ {PENDENTE, CONFIRMADO, RECUSADO, CANCELADO, EXPIRADO, CONCLUIDO}; transições pelo trigger | Estado atual | PI-I |
| `observacao` | varchar(500) | N | — | — | Mensagem do estudante ao solicitar | PI-L |
| `justificativa` | varchar(500) | N | — | — | Motivo de recusa ou cancelamento | PI-L |
| `criado_em` | timestamptz | S | `now()` | Forçado pelo trigger de inserção | Momento da solicitação; base da expiração de 48 h | PI-I |
| `respondido_em` | timestamptz | N | — | `ck_agendamentos_respondido_em` (≥ `criado_em`); preenchido pelo trigger | Momento em que o mentor confirmou ou recusou | PI-I |

**Restrições e índices de regra de negócio:**
- `ux_agendamentos_disponibilidade_ativa`: `UNIQUE (disponibilidade_id) WHERE status IN ('PENDENTE','CONFIRMADO')`. **No máximo um agendamento ativo por disponibilidade.**
- `ex_agendamentos_estudante_sem_sobreposicao`: `EXCLUDE USING gist (estudante_id WITH =, fn_periodo(inicio_em, duracao_minutos) WITH &&) WHERE (status IN ('PENDENTE','CONFIRMADO'))`. **O estudante não pode ter reservas ativas sobrepostas.**
- `uq_agendamentos_id_status UNIQUE (id, status)`: alvo técnico da FK de `sessoes_mentoria`.
- Triggers: `tg_agendamentos_validar_insercao` e `tg_agendamentos_validar_atualizacao` (ver §3).

**Outros índices:** `ix_agendamentos_estudante (estudante_id, inicio_em DESC)`, `ix_agendamentos_mentor_status (mentor_id, status, inicio_em)`, `ix_agendamentos_disciplina (disciplina_id)` e `ix_agendamentos_pendentes_criado (criado_em) WHERE status = 'PENDENTE'` (rotina de expiração).

### 2.7 `sessoes_mentoria`
Atendimento efetivamente registrado pelo mentor. Nome canônico (**não** `RegistroSessao`). Cardinalidade `Agendamento 1 → 0..1 SessaoMentoria`.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `id` | bigint | S | identity | PK `pk_sessoes_mentoria` | Identificador | PI-I |
| `agendamento_id` | bigint | S | — | UNIQUE `uq_sessoes_mentoria_agendamento`; FK composta `fk_sessoes_mentoria_agendamento` → `agendamentos(id, status)` | Agendamento concluído | PI-I |
| `status_agendamento` | varchar(12) | S | `'CONCLUIDO'` | `ck_sessoes_mentoria_status` (= CONCLUIDO) | **Coluna técnica discriminadora**: só permite sessão de agendamento `CONCLUIDO` | NP |
| `compareceu` | boolean | S | — | — | Se o estudante compareceu | PI-I |
| `duracao_real_min` | integer | N | — | `ck_sessoes_mentoria_duracao` (> 0); `ck_sessoes_mentoria_duracao_sem_comparecimento` (NULL se não compareceu) | Duração efetiva | NP |
| `observacoes` | varchar(2000) | N | — | — | Anotações do mentor sobre a sessão | PI-L |
| `registrado_em` | timestamptz | S | `now()` | — | Momento do registro de conclusão | PI-I |

**Restrição técnica:** `uq_sessoes_mentoria_id_compareceu UNIQUE (id, compareceu)`, alvo da FK de `avaliacoes`.

### 2.8 `avaliacoes`
Opinião do estudante sobre uma sessão concluída **com comparecimento**. Cardinalidade `SessaoMentoria 1 → 0..1 Avaliacao`.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `id` | bigint | S | identity | PK `pk_avaliacoes` | Identificador | NP |
| `sessao_id` | bigint | S | — | UNIQUE `uq_avaliacoes_sessao`; FK composta `fk_avaliacoes_sessao` → `sessoes_mentoria(id, compareceu)` | Sessão avaliada | PI-I |
| `sessao_compareceu` | boolean | S | `true` | `ck_avaliacoes_compareceu` (= true) | **Coluna técnica discriminadora**: só permite avaliar sessão com comparecimento | NP |
| `nota` | smallint | S | — | `ck_avaliacoes_nota` (1 a 5) | Nota atribuída | PI-I |
| `comentario` | varchar(1000) | N | — | — | Comentário opcional | PI-L |
| `criado_em` | timestamptz | S | `now()` | — | Data da avaliação | PI-I |

> A avaliação não guarda `estudante_id`: o autor é derivado de `sessao → agendamento`. As visões da coordenação não expõem o estudante.

### 2.9 `notificacoes`
Aviso interno ao aplicativo (RF018, *Could*; fora do núcleo do MVP). Sem e-mail ou SMS.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `id` | bigint | S | identity | PK `pk_notificacoes` | Identificador | NP |
| `usuario_id` | bigint | S | — | FK `fk_notificacoes_usuario` → `usuarios.id` (CASCADE) | Destinatário | PI-I |
| `agendamento_id` | bigint | N | — | FK `fk_notificacoes_agendamento` → `agendamentos.id` (SET NULL) | Agendamento relacionado, se houver | PI-I |
| `mensagem` | varchar(500) | S | — | `ck_notificacoes_mensagem` (não vazia) | Texto gerado pelo sistema | PI-L |
| `lida` | boolean | S | `false` | — | Leitura pelo destinatário | NP |
| `criado_em` | timestamptz | S | `now()` | — | Data de criação | PI-I |

**Índices:** `ix_notificacoes_usuario_nao_lidas (usuario_id, criado_em DESC) WHERE NOT lida`, `ix_notificacoes_agendamento`.

### 2.10 `logs_auditoria`
Trilha das ações administrativas (RNF024). **Somente inserção**; sem senha, token ou texto livre.

| Campo | Tipo | Obr. | Padrão | Restrições | Descrição | LGPD |
|---|---|:-:|---|---|---|:-:|
| `id` | bigint | S | identity | PK `pk_logs_auditoria` | Identificador | NP |
| `administrador_id` | bigint | S | — | FK `fk_logs_auditoria_administrador` → `usuarios.id` (RESTRICT); trigger `tg_logs_auditoria_perfil` | Autor da ação (obrigatório) | PI-I |
| `acao` | varchar(60) | S | — | `ck_logs_auditoria_acao` (MAIÚSCULAS_COM_SUBLINHADO) | Código da ação, por exemplo, `DESATIVAR_USUARIO` | NP |
| `tipo_alvo` | varchar(30) | S | — | `ck_logs_auditoria_tipo_alvo` | Tipo do objeto afetado, por exemplo, `USUARIO` ou `DISCIPLINA` | NP |
| `alvo_id` | bigint | S | — | — | ID do objeto afetado | PI-I |
| `criado_em` | timestamptz | S | `now()` | — | Momento da ação | PI-I |

**Proteções:** trigger `tg_logs_auditoria_bloquear_alteracao` (bloqueia UPDATE; DELETE só após a retenção) e `tg_logs_auditoria_bloquear_truncate`.
**Índices:** `ix_logs_auditoria_administrador`, `ix_logs_auditoria_alvo`, `ix_logs_auditoria_criado`.

---

## 3. Funções, triggers e visões

| Objeto | Tipo | Tabela | Regra garantida |
|---|---|---|---|
| `fn_periodo(inicio, minutos)` | função IMMUTABLE | — | Converte horário em intervalo `[início, fim)` para as regras de sobreposição |
| `tg_usuarios_atualizado_em` | trigger BEFORE UPDATE | usuarios | Mantém `atualizado_em` |
| `tg_usuarios_proteger_ultimo_admin` | trigger BEFORE UPDATE/DELETE | usuarios | Impede desativar, rebaixar ou excluir o último administrador ativo (com *advisory lock*) |
| `tg_usuarios_proteger_compromissos_perfil` | trigger BEFORE UPDATE OF perfil | usuarios | RN11: bloqueia mudança de perfil de mentor/estudante com compromissos futuros ativos |
| `tg_perfis_mentor_perfil`, `tg_mentor_disciplinas_perfil`, `tg_disponibilidades_perfil` | trigger BEFORE INSERT | várias | Usuário referenciado precisa ser MENTOR e estar ativo |
| `tg_agendamentos_perfil_estudante` | trigger BEFORE INSERT | agendamentos | Solicitante precisa ser ESTUDANTE ativo |
| `tg_logs_auditoria_perfil` | trigger BEFORE INSERT | logs_auditoria | Autor precisa ser ADMINISTRADOR ativo |
| `tg_agendamentos_validar_insercao` | trigger BEFORE INSERT | agendamentos | Nasce PENDENTE; disponibilidade ativa; mentor ativo; horário futuro; disciplina ativa e do mentor; `criado_em` do servidor |
| `tg_agendamentos_validar_atualizacao` | trigger BEFORE UPDATE | agendamentos | Máquina de estados; EXPIRADO só após 48 h; campos de identificação imutáveis; `respondido_em` automático |
| `tg_disponibilidades_proteger_atualizacao` | trigger BEFORE UPDATE | disponibilidades | RN13: horário com histórico é imutável; reserva ativa impede inativar |
| `tg_logs_auditoria_bloquear_alteracao` / `_truncate` | trigger | logs_auditoria | Auditoria somente inserção; expurgo apenas após a retenção |
| `vw_mentorias_coordenacao` | visão | — | Lista de mentorias para a coordenação (RF019), sem o estudante |
| `vw_relatorio_avaliacoes` | visão | — | Médias por mentor e disciplina (RF020), sem o estudante |

### Códigos de erro emitidos pelo banco (para o Service traduzir em HTTP)

| SQLSTATE | Nome | Origem típica | HTTP sugerido |
|---|---|---|---|
| `23505` | unique_violation | e-mail duplicado; segundo agendamento ativo; avaliação duplicada | **409 Conflict** |
| `23P01` | exclusion_violation | horários sobrepostos do mentor ou do estudante | **409 Conflict** |
| `23514` | check_violation | CHECK ou regra `rn_*` (perfil, transição, 48 h, último administrador) | 409 (estado/conflito) ou 422 (dado inválido) |
| `23503` | foreign_key_violation | referência inexistente ou combinação inconsistente | 404 (recurso inexistente) ou 409 |
| `42501` | insufficient_privilege | tentativa de alterar auditoria | 403 / 500 (não deve vir da API) |

---

## 4. Retenção e ciclo de vida dos dados

> Somente a retenção de 12 meses da auditoria consta nos documentos do grupo, e ainda está marcada "a validar". **Os demais prazos são propostas do DBA** e precisam ser aprovados pelo trio (e pela instituição, se o sistema for adotado de verdade).

| Tabela | Retenção proposta | Ação ao fim do prazo | Base legal sugerida (LGPD, art. 7º) | Status |
|---|---|---|---|---|
| `usuarios` | Enquanto a conta estiver ativa; após a desativação, 24 meses | Anonimizar `nome` e `email` (ex.: `anonimo-<id>@removido.invalid`), substituir `senha_hash` por hash aleatório e remover `perfis_mentor` | V (execução do serviço) | Proposta |
| `perfis_mentor` | Enquanto o mentor estiver ativo | Excluir a linha | V | Proposta |
| `agendamentos`, `sessoes_mentoria`, `avaliacoes` | 24 meses após a sessão ou o encerramento | Limpar campos PI-L (`observacao`, `justificativa`, `observacoes`, `comentario`); manter as linhas para os relatórios agregados | V e IX (legítimo interesse: qualidade acadêmica) | Proposta |
| `notificacoes` | 6 meses | Excluir | V | Proposta |
| `logs_auditoria` | 12 meses | Excluir (o trigger só permite apagar fora da janela) | II (obrigação de prestação de contas) / IX | **Decisão do grupo, a validar** |
| `disciplinas` | Indefinida (catálogo) | — | — | Sem dado pessoal |

**Direitos do titular (art. 18):** acesso e portabilidade (consulta dos próprios dados via API), correção (perfil), eliminação ou anonimização (rotina acima) e informação sobre compartilhamento (não há compartilhamento com terceiros nesta versão).
