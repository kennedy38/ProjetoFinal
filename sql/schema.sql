-- =====================================================================
--  MentorIA Acadêmica — Modelo físico do banco de dados
--  Bloco 5 — Banco de Dados | Responsável: Guilherme
--  Equipe: Hadson, Kennedy e Guilherme | Versão 1.0 | 08/11/2026
--
--  SGBD alvo : PostgreSQL 16 (compatível com 13 ou superior)
--  Execução  : em um banco VAZIO (ex.: mentoria_academica), conectado
--              com o usuário dono do banco. Rodar o arquivo inteiro de
--              uma vez (pgAdmin 4 → Query Tool → F5).
--  Transação : o script inteiro roda em BEGIN/COMMIT; se qualquer
--              comando falhar, nada é criado.
--
--  Fontes das regras: Contrato de Integração v1.0 (06/11/2026) e
--  00-decisoes-compartilhadas.md. Itens marcados com [PROPOSTA DBA]
--  ainda dependem de validação do grupo (ver 05-banco-de-dados.md, §9).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 0. Extensões e funções utilitárias
-- ---------------------------------------------------------------------

-- btree_gist permite combinar igualdade (=) de inteiros com sobreposição
-- de intervalos (&&) em uma EXCLUSION CONSTRAINT. É uma extensão "contrib"
-- oficial, distribuída com o PostgreSQL e marcada como confiável (trusted)
-- desde a versão 13, então o dono do banco pode criá-la.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Converte (início, duração em minutos) em um intervalo de tempo [início, fim).
-- O limite superior é aberto: uma sessão das 10:00 às 11:00 NÃO conflita
-- com outra que começa às 11:00.
-- Marcada como IMMUTABLE de forma consciente: somar apenas minutos a um
-- timestamptz não depende do fuso horário (diferente de somar dias ou meses).
-- Isso permite usar a função dentro de índices e EXCLUDE constraints.
CREATE OR REPLACE FUNCTION fn_periodo(p_inicio timestamptz, p_minutos integer)
RETURNS tstzrange
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT tstzrange(p_inicio, p_inicio + make_interval(mins => p_minutos), '[)');
$$;

COMMENT ON FUNCTION fn_periodo(timestamptz, integer) IS
    'Intervalo [inicio, inicio + minutos) usado nas regras anti-sobreposição.';


-- ---------------------------------------------------------------------
-- 1. usuarios — identidade e perfil de acesso (RBAC)
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
    id                     bigint       GENERATED ALWAYS AS IDENTITY,
    nome                   varchar(120) NOT NULL,
    email                  varchar(254) NOT NULL,
    senha_hash             varchar(60)  NOT NULL,
    perfil                 varchar(20)  NOT NULL,
    ativo                  boolean      NOT NULL DEFAULT true,
    aceite_privacidade_em  timestamptz  NOT NULL,
    aceite_privacidade_fonte varchar(18) NOT NULL DEFAULT 'AUTOCADASTRO',
    aceite_privacidade_referencia varchar(120),
    criado_em              timestamptz  NOT NULL DEFAULT now(),
    atualizado_em          timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_usuarios PRIMARY KEY (id),
    CONSTRAINT uq_usuarios_email UNIQUE (email),
    CONSTRAINT ck_usuarios_nome CHECK (length(btrim(nome)) >= 2),
    -- O Service normaliza o e-mail para minúsculas; o banco garante isso,
    -- e assim o UNIQUE simples já é case-insensitive na prática.
    CONSTRAINT ck_usuarios_email_minusculo CHECK (email = lower(email)),
    CONSTRAINT ck_usuarios_email_formato CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    -- Defesa em profundidade: hash bcrypt sintaticamente válido, com custo >= 12
    -- conforme RNF006 (mínimo do grupo). Validar o hash REAL cabe ao bcryptjs;
    -- esse CHECK não é prova criptográfica de que a senha foi corretamente derivada.
    CONSTRAINT ck_usuarios_senha_bcrypt CHECK (senha_hash ~ '^\$2[aby]\$(1[2-9]|2[0-9]|3[01])\$[./A-Za-z0-9]{53}$'),
    CONSTRAINT ck_usuarios_perfil CHECK (perfil IN ('ESTUDANTE', 'MENTOR', 'COORDENADOR', 'ADMINISTRADOR')),
    -- O administrador NÃO aceita a política em nome do titular: exige prova externa verificável.
    CONSTRAINT ck_usuarios_aceite_fonte CHECK (aceite_privacidade_fonte IN ('AUTOCADASTRO', 'INSTITUCIONAL')),
    CONSTRAINT ck_usuarios_aceite_referencia CHECK (
        (aceite_privacidade_fonte = 'AUTOCADASTRO' AND aceite_privacidade_referencia IS NULL)
        OR (aceite_privacidade_fonte = 'INSTITUCIONAL'
            AND length(btrim(coalesce(aceite_privacidade_referencia, ''))) >= 6)
    )
);

COMMENT ON TABLE  usuarios IS 'Usuários da plataforma. Os quatro atores são perfis (RBAC), não tabelas separadas. Exclusão lógica via ativo.';
COMMENT ON COLUMN usuarios.senha_hash IS 'Hash bcrypt (bcryptjs). Nunca armazenar senha ou JWT em texto claro.';
COMMENT ON COLUMN usuarios.aceite_privacidade_em IS 'Momento efetivo do aceite do titular; não é o horário da criação administrativa.';
COMMENT ON COLUMN usuarios.aceite_privacidade_fonte IS 'AUTOCADASTRO: aceite na interface; INSTITUCIONAL: aceite prévio comprovado, nunca pelo administrador.';
COMMENT ON COLUMN usuarios.aceite_privacidade_referencia IS 'Identificador de evidência armazenada em repositório institucional protegido, sem anexar dados sensíveis.';

-- Busca de usuários ativos por perfil (ex.: listagem de mentores, contagem de administradores).
CREATE INDEX ix_usuarios_perfil_ativos ON usuarios (perfil) WHERE ativo;


-- ---------------------------------------------------------------------
-- 2. perfis_mentor — dados complementares do mentor (0..1 por usuário MENTOR)
-- ---------------------------------------------------------------------
CREATE TABLE perfis_mentor (
    usuario_id      bigint        NOT NULL,
    biografia       varchar(1000),
    formacao        varchar(255),
    contato_sessao  varchar(255),

    -- A PK é o próprio usuario_id: garante a cardinalidade 1 → 0..1.
    CONSTRAINT pk_perfis_mentor PRIMARY KEY (usuario_id),
    CONSTRAINT fk_perfis_mentor_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT
);

COMMENT ON TABLE  perfis_mentor IS 'Dados de apresentação do mentor (RF006, Should). Apenas usuários com perfil MENTOR.';
COMMENT ON COLUMN perfis_mentor.contato_sessao IS 'Meio de contato/sala externa para a sessão (dado pessoal).';


-- ---------------------------------------------------------------------
-- 3. disciplinas — catálogo mantido pela administração (RF021)
-- ---------------------------------------------------------------------
CREATE TABLE disciplinas (
    id      bigint       GENERATED ALWAYS AS IDENTITY,
    codigo  varchar(20)  NOT NULL,
    nome    varchar(120) NOT NULL,
    ativa   boolean      NOT NULL DEFAULT true,

    CONSTRAINT pk_disciplinas PRIMARY KEY (id),
    CONSTRAINT uq_disciplinas_codigo UNIQUE (codigo),
    CONSTRAINT ck_disciplinas_codigo CHECK (codigo = upper(codigo) AND length(btrim(codigo)) >= 2),
    CONSTRAINT ck_disciplinas_nome CHECK (length(btrim(nome)) >= 2)
);

COMMENT ON TABLE disciplinas IS 'Catálogo de disciplinas (RF021, Must). Exclusão lógica via ativa.';


-- ---------------------------------------------------------------------
-- 4. mentor_disciplinas — vínculo N:N entre mentor e disciplina
-- ---------------------------------------------------------------------
CREATE TABLE mentor_disciplinas (
    mentor_id      bigint NOT NULL,
    disciplina_id  bigint NOT NULL,

    -- PK composta = "mentorId + disciplinaId únicos em conjunto".
    CONSTRAINT pk_mentor_disciplinas PRIMARY KEY (mentor_id, disciplina_id),
    CONSTRAINT fk_mentor_disciplinas_mentor FOREIGN KEY (mentor_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT,
    CONSTRAINT fk_mentor_disciplinas_disciplina FOREIGN KEY (disciplina_id)
        REFERENCES disciplinas (id) ON DELETE RESTRICT
);

COMMENT ON TABLE mentor_disciplinas IS 'Disciplinas que cada mentor atende. O mentor se vincula ao catálogo; não cria disciplinas.';

-- A PK já indexa (mentor_id, disciplina_id); este índice atende a busca
-- "mentores por disciplina" (GET /api/mentores?disciplinaId=..., RF010).
CREATE INDEX ix_mentor_disciplinas_disciplina ON mentor_disciplinas (disciplina_id);


-- ---------------------------------------------------------------------
-- 5. disponibilidades — horários oferecidos pelo mentor
-- ---------------------------------------------------------------------
CREATE TABLE disponibilidades (
    id               bigint      GENERATED ALWAYS AS IDENTITY,
    mentor_id        bigint      NOT NULL,
    inicio_em        timestamptz NOT NULL,
    duracao_minutos  integer     NOT NULL,
    ativa            boolean     NOT NULL DEFAULT true,
    criado_em        timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_disponibilidades PRIMARY KEY (id),
    -- Chave candidata usada pela FK composta de agendamentos: garante que o
    -- agendamento copie exatamente o mentor e o horário da disponibilidade.
    CONSTRAINT uq_disponibilidades_snapshot UNIQUE (id, mentor_id, inicio_em, duracao_minutos),
    -- RF008: os únicos formatos permitidos de sessão são 30, 45 ou 60 minutos.
    CONSTRAINT ck_disponibilidades_duracao CHECK (duracao_minutos IN (30, 45, 60)),
    CONSTRAINT fk_disponibilidades_mentor FOREIGN KEY (mentor_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT,
    -- REGRA: um mentor não pode ter duas disponibilidades ATIVAS sobrepostas.
    CONSTRAINT ex_disponibilidades_mentor_sem_sobreposicao
        EXCLUDE USING gist (
            mentor_id                              WITH =,
            fn_periodo(inicio_em, duracao_minutos) WITH &&
        ) WHERE (ativa)
);

COMMENT ON TABLE disponibilidades IS 'Horário oferecido por um mentor. Não é reserva: a reserva é o agendamento.';

-- Listagem de horários futuros de um mentor (GET /api/mentores/{id}/disponibilidades, RF011).
CREATE INDEX ix_disponibilidades_mentor_inicio ON disponibilidades (mentor_id, inicio_em) WHERE ativa;


-- ---------------------------------------------------------------------
-- 6. agendamentos — pedido do estudante para ocupar uma disponibilidade
-- ---------------------------------------------------------------------
CREATE TABLE agendamentos (
    id                  bigint       GENERATED ALWAYS AS IDENTITY,
    disponibilidade_id  bigint       NOT NULL,
    estudante_id        bigint       NOT NULL,
    mentor_id           bigint       NOT NULL,
    disciplina_id       bigint       NOT NULL,
    -- Cópia controlada do horário da disponibilidade (ver FK composta abaixo).
    -- Necessária para a EXCLUSION CONSTRAINT do estudante. [PROPOSTA DBA]
    inicio_em           timestamptz  NOT NULL,
    duracao_minutos     integer      NOT NULL,
    status              varchar(12)  NOT NULL DEFAULT 'PENDENTE',
    observacao          varchar(500),
    justificativa       varchar(500),
    criado_em           timestamptz  NOT NULL DEFAULT now(),
    respondido_em       timestamptz,

    CONSTRAINT pk_agendamentos PRIMARY KEY (id),
    -- Chave candidata usada por sessoes_mentoria para exigir status CONCLUIDO.
    CONSTRAINT uq_agendamentos_id_status UNIQUE (id, status),
    CONSTRAINT ck_agendamentos_status CHECK (status IN
        ('PENDENTE', 'CONFIRMADO', 'RECUSADO', 'CANCELADO', 'EXPIRADO', 'CONCLUIDO')),
    CONSTRAINT ck_agendamentos_estudante_nao_e_mentor CHECK (estudante_id <> mentor_id),
    CONSTRAINT ck_agendamentos_respondido_em CHECK (respondido_em IS NULL OR respondido_em >= criado_em),

    -- REGRA: mentor_id e horário do agendamento PRECISAM ser os da disponibilidade.
    -- NO ACTION (padrão) em UPDATE: horário de disponibilidade com histórico não muda.
    CONSTRAINT fk_agendamentos_disponibilidade
        FOREIGN KEY (disponibilidade_id, mentor_id, inicio_em, duracao_minutos)
        REFERENCES disponibilidades (id, mentor_id, inicio_em, duracao_minutos)
        ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT fk_agendamentos_estudante FOREIGN KEY (estudante_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT,
    CONSTRAINT fk_agendamentos_mentor FOREIGN KEY (mentor_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT,
    CONSTRAINT fk_agendamentos_disciplina FOREIGN KEY (disciplina_id)
        REFERENCES disciplinas (id) ON DELETE RESTRICT,

    -- REGRA: o mesmo estudante não pode ter reservas ATIVAS em horários sobrepostos.
    CONSTRAINT ex_agendamentos_estudante_sem_sobreposicao
        EXCLUDE USING gist (
            estudante_id                           WITH =,
            fn_periodo(inicio_em, duracao_minutos) WITH &&
        ) WHERE (status IN ('PENDENTE', 'CONFIRMADO'))
);

COMMENT ON TABLE  agendamentos IS 'Pedido de reserva. Começa PENDENTE; ativos = PENDENTE e CONFIRMADO. Histórico nunca é apagado.';
COMMENT ON COLUMN agendamentos.inicio_em IS 'Cópia do horário da disponibilidade, garantida pela FK composta.';
COMMENT ON COLUMN agendamentos.respondido_em IS 'Preenchido pelo banco quando o mentor confirma ou recusa.';

-- REGRA CENTRAL: no máximo UM agendamento ativo por disponibilidade.
-- Índice único PARCIAL: só participam linhas PENDENTE/CONFIRMADO, então
-- recusados, cancelados, expirados e concluídos permanecem no histórico
-- sem bloquear novas solicitações.
CREATE UNIQUE INDEX ux_agendamentos_disponibilidade_ativa
    ON agendamentos (disponibilidade_id)
    WHERE status IN ('PENDENTE', 'CONFIRMADO');

-- "Meus agendamentos" do estudante e do mentor.
CREATE INDEX ix_agendamentos_estudante ON agendamentos (estudante_id, inicio_em DESC);
CREATE INDEX ix_agendamentos_mentor_status ON agendamentos (mentor_id, status, inicio_em);
CREATE INDEX ix_agendamentos_disciplina ON agendamentos (disciplina_id);
-- Rotina de expiração de 48 h: varre apenas os pendentes.
CREATE INDEX ix_agendamentos_pendentes_criado ON agendamentos (criado_em) WHERE status = 'PENDENTE';


-- ---------------------------------------------------------------------
-- 7. sessoes_mentoria — atendimento efetivamente registrado
-- ---------------------------------------------------------------------
CREATE TABLE sessoes_mentoria (
    id                  bigint        GENERATED ALWAYS AS IDENTITY,
    agendamento_id      bigint        NOT NULL,
    -- Coluna discriminadora técnica: sempre 'CONCLUIDO'. Junto com a FK
    -- composta, impede sessão de agendamento não concluído e impede que o
    -- agendamento saia de CONCLUIDO depois que a sessão existe.
    status_agendamento  varchar(12)   NOT NULL DEFAULT 'CONCLUIDO',
    compareceu          boolean       NOT NULL,
    duracao_real_min    integer,
    observacoes         varchar(2000),
    registrado_em       timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_sessoes_mentoria PRIMARY KEY (id),
    CONSTRAINT uq_sessoes_mentoria_agendamento UNIQUE (agendamento_id),       -- 1 → 0..1
    CONSTRAINT uq_sessoes_mentoria_id_compareceu UNIQUE (id, compareceu),     -- alvo da FK de avaliacoes
    CONSTRAINT ck_sessoes_mentoria_status CHECK (status_agendamento = 'CONCLUIDO'),
    CONSTRAINT ck_sessoes_mentoria_duracao CHECK (duracao_real_min IS NULL OR duracao_real_min > 0),
    CONSTRAINT ck_sessoes_mentoria_duracao_sem_comparecimento CHECK (compareceu OR duracao_real_min IS NULL),
    CONSTRAINT fk_sessoes_mentoria_agendamento FOREIGN KEY (agendamento_id, status_agendamento)
        REFERENCES agendamentos (id, status) ON UPDATE NO ACTION ON DELETE RESTRICT
);

COMMENT ON TABLE sessoes_mentoria IS 'Sessão de mentoria (nome canônico; não usar RegistroSessao). Só existe para agendamento CONCLUIDO.';


-- ---------------------------------------------------------------------
-- 8. avaliacoes — opinião do estudante sobre a sessão
-- ---------------------------------------------------------------------
CREATE TABLE avaliacoes (
    id                 bigint        GENERATED ALWAYS AS IDENTITY,
    sessao_id          bigint        NOT NULL,
    -- Discriminadora técnica: sempre true. Com a FK composta, só permite
    -- avaliar sessão em que o estudante compareceu.
    sessao_compareceu  boolean       NOT NULL DEFAULT true,
    nota               smallint      NOT NULL,
    comentario         varchar(1000),
    criado_em          timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_avaliacoes PRIMARY KEY (id),
    CONSTRAINT uq_avaliacoes_sessao UNIQUE (sessao_id),                       -- sem avaliação duplicada
    CONSTRAINT ck_avaliacoes_nota CHECK (nota BETWEEN 1 AND 5),              -- faixa 1 a 5
    CONSTRAINT ck_avaliacoes_compareceu CHECK (sessao_compareceu),
    CONSTRAINT fk_avaliacoes_sessao FOREIGN KEY (sessao_id, sessao_compareceu)
        REFERENCES sessoes_mentoria (id, compareceu) ON UPDATE NO ACTION ON DELETE RESTRICT
);

COMMENT ON TABLE avaliacoes IS 'Avaliação 1–5 de sessão concluída com comparecimento. Visões gerenciais não identificam o estudante.';


-- ---------------------------------------------------------------------
-- 9. notificacoes — avisos internos (RF018, Could — fora do núcleo do MVP)
-- ---------------------------------------------------------------------
CREATE TABLE notificacoes (
    id              bigint       GENERATED ALWAYS AS IDENTITY,
    usuario_id      bigint       NOT NULL,
    agendamento_id  bigint,
    mensagem        varchar(500) NOT NULL,
    lida            boolean      NOT NULL DEFAULT false,
    criado_em       timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_notificacoes PRIMARY KEY (id),
    CONSTRAINT ck_notificacoes_mensagem CHECK (length(btrim(mensagem)) > 0),
    CONSTRAINT fk_notificacoes_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios (id) ON DELETE CASCADE,
    CONSTRAINT fk_notificacoes_agendamento FOREIGN KEY (agendamento_id)
        REFERENCES agendamentos (id) ON DELETE SET NULL
);

COMMENT ON TABLE notificacoes IS 'Aviso interno ao aplicativo. Sem e-mail/SMS (fora do escopo).';

CREATE INDEX ix_notificacoes_usuario_nao_lidas ON notificacoes (usuario_id, criado_em DESC) WHERE NOT lida;
CREATE INDEX ix_notificacoes_agendamento ON notificacoes (agendamento_id);


-- ---------------------------------------------------------------------
-- 10. logs_auditoria — trilha de ações administrativas (RNF024)
-- ---------------------------------------------------------------------
CREATE TABLE logs_auditoria (
    id                bigint       GENERATED ALWAYS AS IDENTITY,
    administrador_id  bigint       NOT NULL,
    acao              varchar(60)  NOT NULL,
    tipo_alvo         varchar(30)  NOT NULL,
    alvo_id           bigint       NOT NULL,
    criado_em         timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_logs_auditoria PRIMARY KEY (id),
    -- Códigos em MAIÚSCULAS_COM_SUBLINHADO (ex.: DESATIVAR_USUARIO, ALTERAR_PERFIL).
    CONSTRAINT ck_logs_auditoria_acao CHECK (acao ~ '^[A-Z][A-Z_]{2,59}$'),
    CONSTRAINT ck_logs_auditoria_tipo_alvo CHECK (tipo_alvo ~ '^[A-Z][A-Z_]{2,29}$'),
    CONSTRAINT fk_logs_auditoria_administrador FOREIGN KEY (administrador_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT
);

COMMENT ON TABLE logs_auditoria IS 'Somente inserção. Sem senha, token ou dado pessoal livre. Retenção-alvo 12 meses (a validar).';

CREATE INDEX ix_logs_auditoria_administrador ON logs_auditoria (administrador_id, criado_em DESC);
CREATE INDEX ix_logs_auditoria_alvo ON logs_auditoria (tipo_alvo, alvo_id);
CREATE INDEX ix_logs_auditoria_criado ON logs_auditoria (criado_em);


-- =====================================================================
-- 11. Funções de gatilho (triggers) — regras que CHECK/FK não expressam
--     Erros usam SQLSTATE padrão + nome de regra (CONSTRAINT) para que a
--     camada Service traduza em HTTP 409/422 de forma previsível.
-- =====================================================================

-- 11.1 Mantém usuarios.atualizado_em.
CREATE OR REPLACE FUNCTION fn_definir_atualizado_em()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.atualizado_em := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_usuarios_atualizado_em
    BEFORE UPDATE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_definir_atualizado_em();


-- 11.2 Exige que o usuário referenciado tenha determinado perfil e esteja ativo
--      NO MOMENTO do registro. Argumentos: (nome_da_coluna, perfil_exigido).
--      Por que trigger e não FK composta com perfil? Porque a FK "congelaria"
--      o perfil do usuário para sempre; aqui, uma mudança de perfil feita pela
--      administração não reescreve o histórico.
CREATE OR REPLACE FUNCTION fn_exigir_perfil()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_coluna          text   := TG_ARGV[0];
    v_perfil_exigido  text   := TG_ARGV[1];
    v_usuario_id      bigint := (to_jsonb(NEW) ->> v_coluna)::bigint;
    v_perfil          text;
    v_ativo           boolean;
BEGIN
    SELECT perfil, ativo INTO v_perfil, v_ativo
      FROM usuarios
     WHERE id = v_usuario_id;

    IF NOT FOUND THEN
        RETURN NEW;  -- a FK correspondente reporta o erro de referência
    END IF;

    IF v_perfil <> v_perfil_exigido THEN
        RAISE EXCEPTION 'Usuário % tem perfil %, mas %.% exige perfil %',
                        v_usuario_id, v_perfil, TG_TABLE_NAME, v_coluna, v_perfil_exigido
            USING ERRCODE = 'check_violation',
                  CONSTRAINT = 'rn_perfil_' || TG_TABLE_NAME;
    END IF;

    IF NOT v_ativo THEN
        RAISE EXCEPTION 'Usuário % está inativo e não pode ser usado em %', v_usuario_id, TG_TABLE_NAME
            USING ERRCODE = 'check_violation',
                  CONSTRAINT = 'rn_usuario_ativo_' || TG_TABLE_NAME;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_perfis_mentor_perfil
    BEFORE INSERT OR UPDATE OF usuario_id ON perfis_mentor
    FOR EACH ROW EXECUTE FUNCTION fn_exigir_perfil('usuario_id', 'MENTOR');

CREATE TRIGGER tg_mentor_disciplinas_perfil
    BEFORE INSERT OR UPDATE OF mentor_id ON mentor_disciplinas
    FOR EACH ROW EXECUTE FUNCTION fn_exigir_perfil('mentor_id', 'MENTOR');

CREATE TRIGGER tg_disponibilidades_perfil
    BEFORE INSERT OR UPDATE OF mentor_id ON disponibilidades
    FOR EACH ROW EXECUTE FUNCTION fn_exigir_perfil('mentor_id', 'MENTOR');

CREATE TRIGGER tg_agendamentos_perfil_estudante
    BEFORE INSERT ON agendamentos
    FOR EACH ROW EXECUTE FUNCTION fn_exigir_perfil('estudante_id', 'ESTUDANTE');

CREATE TRIGGER tg_logs_auditoria_perfil
    BEFORE INSERT ON logs_auditoria
    FOR EACH ROW EXECUTE FUNCTION fn_exigir_perfil('administrador_id', 'ADMINISTRADOR');


-- 11.3 Validações na CRIAÇÃO do agendamento.
CREATE OR REPLACE FUNCTION fn_agendamento_validar_insercao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_disponibilidade_ativa  boolean;
    v_disciplina_ativa       boolean;
BEGIN
    -- Toda solicitação nasce PENDENTE (o mentor confirma ou recusa depois).
    IF NEW.status <> 'PENDENTE' THEN
        RAISE EXCEPTION 'Novo agendamento deve iniciar como PENDENTE (recebido: %)', NEW.status
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_inicia_pendente';
    END IF;

    SELECT ativa INTO v_disponibilidade_ativa
      FROM disponibilidades WHERE id = NEW.disponibilidade_id;
    IF FOUND AND NOT v_disponibilidade_ativa THEN
        RAISE EXCEPTION 'Disponibilidade % está inativa', NEW.disponibilidade_id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_disponibilidade_ativa';
    END IF;

    -- Mentor precisa permanecer ativo e com perfil MENTOR no momento da reserva.
    -- Sem isso, a alteração de perfil prevista no RF005 permitiria criar reservas
    -- com um antigo mentor que agora é ESTUDANTE (perfil revogado no RBAC).
    IF EXISTS (SELECT 1 FROM usuarios
                WHERE id = NEW.mentor_id AND (NOT ativo OR perfil <> 'MENTOR')) THEN
        RAISE EXCEPTION 'Mentor % está inativo ou sem perfil MENTOR', NEW.mentor_id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_mentor_ativo';
    END IF;

    -- "O horário deverá ser futuro para novas solicitações."
    IF NEW.inicio_em <= now() THEN
        RAISE EXCEPTION 'Só é possível solicitar horários futuros'
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_horario_futuro';
    END IF;

    -- A disciplina precisa estar ativa e entre as atendidas pelo mentor.
    SELECT ativa INTO v_disciplina_ativa FROM disciplinas WHERE id = NEW.disciplina_id;
    IF FOUND AND NOT v_disciplina_ativa THEN
        RAISE EXCEPTION 'Disciplina % está inativa', NEW.disciplina_id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_disciplina_ativa';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM mentor_disciplinas
                    WHERE mentor_id = NEW.mentor_id AND disciplina_id = NEW.disciplina_id) THEN
        RAISE EXCEPTION 'O mentor % não atende a disciplina %', NEW.mentor_id, NEW.disciplina_id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_disciplina_do_mentor';
    END IF;

    -- Datas de controle são do servidor, não do cliente (base da expiração de 48 h).
    NEW.criado_em     := now();
    NEW.respondido_em := NULL;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_agendamentos_validar_insercao
    BEFORE INSERT ON agendamentos
    FOR EACH ROW EXECUTE FUNCTION fn_agendamento_validar_insercao();


-- 11.4 Máquina de estados do agendamento (transições permitidas):
--      PENDENTE   → CONFIRMADO | RECUSADO | CANCELADO | EXPIRADO
--      CONFIRMADO → CONCLUIDO  | CANCELADO
--      RECUSADO, CANCELADO, EXPIRADO e CONCLUIDO são estados finais.
--      QUEM pode fazer cada transição (RBAC) é responsabilidade do Service.
CREATE OR REPLACE FUNCTION fn_agendamento_validar_atualizacao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.disponibilidade_id <> OLD.disponibilidade_id
       OR NEW.estudante_id    <> OLD.estudante_id
       OR NEW.mentor_id       <> OLD.mentor_id
       OR NEW.disciplina_id   <> OLD.disciplina_id
       OR NEW.inicio_em       <> OLD.inicio_em
       OR NEW.duracao_minutos <> OLD.duracao_minutos
       OR NEW.criado_em       <> OLD.criado_em THEN
        RAISE EXCEPTION 'Dados de identificação do agendamento % são imutáveis', OLD.id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_imutavel';
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NOT (
               (OLD.status = 'PENDENTE'   AND NEW.status IN ('CONFIRMADO', 'RECUSADO', 'CANCELADO', 'EXPIRADO'))
            OR (OLD.status = 'CONFIRMADO' AND NEW.status IN ('CONCLUIDO', 'CANCELADO'))
        ) THEN
            RAISE EXCEPTION 'Transição de status inválida: % → %', OLD.status, NEW.status
                USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_transicao';
        END IF;

        -- Expiração só depois de 48 horas sem resposta (RF014).
        IF NEW.status = 'EXPIRADO' AND OLD.criado_em > now() - interval '48 hours' THEN
            RAISE EXCEPTION 'Agendamento % ainda está dentro do prazo de resposta de 48 horas', OLD.id
                USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_agendamento_expiracao_48h';
        END IF;

        -- Registra o momento da resposta do mentor.
        IF OLD.status = 'PENDENTE' AND NEW.status IN ('CONFIRMADO', 'RECUSADO') THEN
            NEW.respondido_em := now();
        ELSE
            NEW.respondido_em := OLD.respondido_em;
        END IF;
    ELSE
        NEW.respondido_em := OLD.respondido_em;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_agendamentos_validar_atualizacao
    BEFORE UPDATE ON agendamentos
    FOR EACH ROW EXECUTE FUNCTION fn_agendamento_validar_atualizacao();


-- 11.5 Impede desativar, rebaixar ou excluir o ÚLTIMO administrador ativo.
--      Concorrência: o advisory lock serializa as alterações de administradores.
--      Com o nível padrão READ COMMITTED, a transação que espera enxerga o
--      resultado da que terminou antes e é barrada corretamente.
CREATE OR REPLACE FUNCTION fn_proteger_ultimo_administrador()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_outros_admins integer;
BEGIN
    IF OLD.perfil = 'ADMINISTRADOR' AND OLD.ativo AND (
           TG_OP = 'DELETE'
        OR NEW.perfil <> 'ADMINISTRADOR'
        OR NOT NEW.ativo
    ) THEN
        PERFORM pg_advisory_xact_lock(7340001);  -- chave fixa da regra "último administrador"

        SELECT count(*) INTO v_outros_admins
          FROM usuarios
         WHERE perfil = 'ADMINISTRADOR'
           AND ativo
           AND id <> OLD.id;

        IF v_outros_admins = 0 THEN
            RAISE EXCEPTION 'Operação negada: o usuário % é o último administrador ativo', OLD.id
                USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_ultimo_administrador';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_usuarios_proteger_ultimo_admin
    BEFORE UPDATE OF perfil, ativo OR DELETE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_proteger_ultimo_administrador();


-- 11.6 Impede mudança de perfil que abandone compromissos futuros.
--      O Service deve cancelar/encerrar reservas e inativar horários futuros
--      ANTES de rebaixar MENTOR ou trocar o perfil de ESTUDANTE. Sem isso,
--      a verificação RBAC na próxima requisição esconderia compromissos ativos.
CREATE OR REPLACE FUNCTION fn_proteger_compromissos_ao_mudar_perfil()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.perfil IS DISTINCT FROM OLD.perfil AND OLD.ativo THEN
        IF OLD.perfil = 'MENTOR' AND (
            EXISTS (SELECT 1 FROM agendamentos
                    WHERE mentor_id = OLD.id
                      AND status IN ('PENDENTE','CONFIRMADO') AND inicio_em > now())
            OR EXISTS (SELECT 1 FROM disponibilidades
                       WHERE mentor_id = OLD.id AND ativa AND inicio_em > now())
        ) THEN
            RAISE EXCEPTION 'Inative disponibilidades e encerre reservas futuras do mentor % antes de trocar seu perfil', OLD.id
                USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_perfil_compromissos_ativos';
        ELSIF OLD.perfil = 'ESTUDANTE' AND EXISTS (
            SELECT 1 FROM agendamentos WHERE estudante_id = OLD.id
             AND status IN ('PENDENTE','CONFIRMADO') AND inicio_em > now()
        ) THEN
            RAISE EXCEPTION 'Encerre reservas futuras do estudante % antes de trocar seu perfil', OLD.id
                USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_perfil_compromissos_ativos';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_usuarios_proteger_compromissos_perfil
    BEFORE UPDATE OF perfil ON usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_proteger_compromissos_ao_mudar_perfil();

-- 11.7 Protege a disponibilidade: com histórico, o intervalo não muda;
--      com agendamento ativo, também não se permite inativar o horário.
CREATE OR REPLACE FUNCTION fn_proteger_disponibilidade_atualizacao()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF (NEW.mentor_id IS DISTINCT FROM OLD.mentor_id
        OR NEW.inicio_em IS DISTINCT FROM OLD.inicio_em
        OR NEW.duracao_minutos IS DISTINCT FROM OLD.duracao_minutos)
       AND EXISTS (SELECT 1 FROM agendamentos WHERE disponibilidade_id = OLD.id) THEN
        RAISE EXCEPTION 'Disponibilidade % possui histórico: inative e crie outra para alterar horário', OLD.id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_disponibilidade_historico_imutavel';
    END IF;
    IF OLD.ativa AND NOT NEW.ativa AND EXISTS (
        SELECT 1 FROM agendamentos WHERE disponibilidade_id = OLD.id
           AND status IN ('PENDENTE','CONFIRMADO')
    ) THEN
        RAISE EXCEPTION 'Disponibilidade % possui agendamento ativo e não pode ser inativada', OLD.id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'rn_disponibilidade_reserva_ativa';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_disponibilidades_proteger_atualizacao
    BEFORE UPDATE OF mentor_id, inicio_em, duracao_minutos, ativa ON disponibilidades
    FOR EACH ROW EXECUTE FUNCTION fn_proteger_disponibilidade_atualizacao();

-- 11.8 Auditoria somente inserção: bloqueia UPDATE e TRUNCATE; DELETE só
--      para registros fora da janela de retenção (expurgo da política LGPD).
CREATE OR REPLACE FUNCTION fn_logs_auditoria_somente_insercao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'TRUNCATE') THEN
        RAISE EXCEPTION 'logs_auditoria aceita somente inserção (% bloqueado)', TG_OP
            USING ERRCODE = 'insufficient_privilege', CONSTRAINT = 'rn_auditoria_imutavel';
    END IF;

    -- [A VALIDAR] retenção-alvo de 12 meses (00-decisoes-compartilhadas.md).
    IF OLD.criado_em > now() - interval '12 months' THEN
        RAISE EXCEPTION 'Registro de auditoria % ainda está no prazo de retenção', OLD.id
            USING ERRCODE = 'insufficient_privilege', CONSTRAINT = 'rn_auditoria_retencao';
    END IF;

    RETURN OLD;
END;
$$;

CREATE TRIGGER tg_logs_auditoria_bloquear_alteracao
    BEFORE UPDATE OR DELETE ON logs_auditoria
    FOR EACH ROW EXECUTE FUNCTION fn_logs_auditoria_somente_insercao();

CREATE TRIGGER tg_logs_auditoria_bloquear_truncate
    BEFORE TRUNCATE ON logs_auditoria
    FOR EACH STATEMENT EXECUTE FUNCTION fn_logs_auditoria_somente_insercao();


-- =====================================================================
-- 12. Visões gerenciais (Coordenador — RF019 e RF020)
--     Minimização de dados (LGPD): nenhuma visão expõe o estudante.
-- =====================================================================

-- Acompanhamento de mentorias (GET /api/coordenacao/mentorias).
CREATE VIEW vw_mentorias_coordenacao AS
SELECT a.id                 AS agendamento_id,
       a.status,
       a.inicio_em,
       a.duracao_minutos,
       a.criado_em,
       a.respondido_em,
       a.mentor_id,
       m.nome               AS mentor_nome,
       d.id                 AS disciplina_id,
       d.codigo             AS disciplina_codigo,
       d.nome               AS disciplina_nome,
       s.compareceu,
       s.duracao_real_min,
       (av.id IS NOT NULL)  AS avaliada
  FROM agendamentos a
  JOIN usuarios     m  ON m.id = a.mentor_id
  JOIN disciplinas  d  ON d.id = a.disciplina_id
  LEFT JOIN sessoes_mentoria s  ON s.agendamento_id = a.id
  LEFT JOIN avaliacoes       av ON av.sessao_id     = s.id;

COMMENT ON VIEW vw_mentorias_coordenacao IS 'Mentorias para a coordenação, sem identificação do estudante.';

-- Relatório agregado de avaliações (GET /api/coordenacao/relatorios).
CREATE VIEW vw_relatorio_avaliacoes AS
SELECT a.mentor_id,
       m.nome                    AS mentor_nome,
       d.id                      AS disciplina_id,
       d.nome                    AS disciplina_nome,
       count(av.id)              AS total_avaliacoes,
       round(avg(av.nota), 2)    AS media_nota,
       min(av.nota)              AS menor_nota,
       max(av.nota)              AS maior_nota
  FROM avaliacoes       av
  JOIN sessoes_mentoria s ON s.id = av.sessao_id
  JOIN agendamentos     a ON a.id = s.agendamento_id
  JOIN usuarios         m ON m.id = a.mentor_id
  JOIN disciplinas      d ON d.id = a.disciplina_id
 GROUP BY a.mentor_id, m.nome, d.id, d.nome;

COMMENT ON VIEW vw_relatorio_avaliacoes IS 'Médias de avaliação por mentor e disciplina; anônimo para o estudante.';

COMMIT;

-- =====================================================================
-- OPCIONAL (produção): papéis com privilégio mínimo. Executar como
-- superusuário, separadamente, trocando as senhas por valores fortes.
-- ---------------------------------------------------------------------
-- -- Dono do schema: executa schema.sql e as migrações
-- CREATE ROLE mentoria_owner LOGIN PASSWORD '<definir_no_servidor>';
-- ALTER DATABASE mentoria_academica OWNER TO mentoria_owner;
--
-- -- Aplicação (Node.js/pg): só DML, sem DDL e sem alterar auditoria
-- CREATE ROLE mentoria_app LOGIN PASSWORD '<definir_no_servidor>';
-- GRANT CONNECT ON DATABASE mentoria_academica TO mentoria_app;
-- GRANT USAGE ON SCHEMA public TO mentoria_app;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO mentoria_app;
-- REVOKE UPDATE ON logs_auditoria FROM mentoria_app;
-- GRANT DELETE ON notificacoes TO mentoria_app;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO mentoria_app;
-- ALTER ROLE mentoria_app SET statement_timeout = '5s';
-- ALTER ROLE mentoria_app SET idle_in_transaction_session_timeout = '30s';
--
-- -- Backup (pg_dump): somente leitura
-- CREATE ROLE mentoria_backup LOGIN PASSWORD '<definir_no_servidor>';
-- GRANT CONNECT ON DATABASE mentoria_academica TO mentoria_backup;
-- GRANT USAGE ON SCHEMA public TO mentoria_backup;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO mentoria_backup;
-- GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO mentoria_backup;
-- =====================================================================
