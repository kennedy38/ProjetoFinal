-- =====================================================================
--  MentorIA Acadêmica — Testes de validação do schema.sql
--  Bloco 5 | Responsável: Guilherme | Equipe: Hadson, Kennedy e Guilherme
--  Versão 1.1 | 09/11/2026 (44 casos planejados (T00–T43); execução PostgreSQL ainda necessária)
--
--  COMO USAR (pgAdmin 4):
--    1. Execute antes o schema.sql no banco mentoria_academica.
--    2. Abra outro Query Tool no MESMO banco, cole este arquivo e pressione F5.
--    3. Veja a aba "Messages": cada regra aparece como "[OK] Txx ...".
--       Se alguma regra falhar, a execução PARA com "FALHOU: Txx ...".
--  O script roda dentro de BEGIN ... ROLLBACK: nenhum dado fica gravado.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Massa de dados (valores fictícios com formato bcrypt/custo 12: não são hashes de senhas reais)
-- ---------------------------------------------------------------------
INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em) VALUES
  ('Ana Estudante',   'ana@teste.br',    '$2b$12$' || repeat('A', 53), 'ESTUDANTE',     now()),
  ('Bruno Estudante', 'bruno@teste.br',  '$2b$12$' || repeat('B', 53), 'ESTUDANTE',     now()),
  ('Carla Mentora',   'carla@teste.br',  '$2b$12$' || repeat('C', 53), 'MENTOR',        now()),
  ('Diego Mentor',    'diego@teste.br',  '$2b$12$' || repeat('D', 53), 'MENTOR',        now()),
  ('Elisa Coord',     'elisa@teste.br',  '$2b$12$' || repeat('E', 53), 'COORDENADOR',   now()),
  ('Fabio Admin',     'fabio@teste.br',  '$2b$12$' || repeat('F', 53), 'ADMINISTRADOR', now());

INSERT INTO disciplinas (codigo, nome) VALUES
  ('BD1', 'Banco de Dados I'),
  ('APS', 'Análise e Projeto de Sistemas'),
  ('CALC1', 'Cálculo I');

INSERT INTO perfis_mentor (usuario_id, biografia, formacao, contato_sessao)
SELECT id, 'Monitora de BD', 'Bacharel em CC', 'sala virtual institucional'
  FROM usuarios WHERE email = 'carla@teste.br';

INSERT INTO mentor_disciplinas (mentor_id, disciplina_id)
SELECT u.id, d.id FROM usuarios u, disciplinas d
 WHERE (u.email = 'carla@teste.br' AND d.codigo IN ('BD1', 'APS'))
    OR (u.email = 'diego@teste.br' AND d.codigo = 'APS');

-- Horários de referência: depois de amanhã, 10:00 UTC
CREATE TEMP TABLE ref AS
SELECT date_trunc('day', now()) + interval '2 days 10 hours' AS h;

-- Carla: 10:00–11:00 e 11:00–12:00 (encostados, não sobrepostos)
INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
SELECT u.id, r.h, 60 FROM usuarios u, ref r WHERE u.email = 'carla@teste.br';
INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
SELECT u.id, r.h + interval '1 hour', 60 FROM usuarios u, ref r WHERE u.email = 'carla@teste.br';
-- Diego: 10:30–11:30 (sobrepõe o horário da Carla, mas é OUTRO mentor)
INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
SELECT u.id, r.h + interval '30 minutes', 60 FROM usuarios u, ref r WHERE u.email = 'diego@teste.br';
DO $$ BEGIN RAISE NOTICE '[OK] T00 massa de dados criada; mentores diferentes podem ter horários sobrepostos'; END $$;


-- ---------------------------------------------------------------------
-- USUÁRIOS
-- ---------------------------------------------------------------------
DO $$ BEGIN
  INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em)
  VALUES ('Outra Ana', 'ana@teste.br', '$2b$12$' || repeat('Z', 53), 'ESTUDANTE', now());
  RAISE EXCEPTION 'FALHOU: T01 e-mail duplicado foi aceito';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE '[OK] T01 e-mail duplicado bloqueado';
END $$;

DO $$ BEGIN
  INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em)
  VALUES ('Gil', 'gil@teste.br', 'minhaSenha123', 'ESTUDANTE', now());
  RAISE EXCEPTION 'FALHOU: T02 senha em texto claro foi aceita';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T02 senha fora do formato bcrypt bloqueada';
END $$;

DO $$ BEGIN
  INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em)
  VALUES ('Hugo', 'hugo@teste.br', '$2b$12$' || repeat('H', 53), 'PROFESSOR', now());
  RAISE EXCEPTION 'FALHOU: T03 perfil inexistente foi aceito';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T03 perfil fora da lista bloqueado';
END $$;

DO $$ BEGIN
  INSERT INTO perfis_mentor (usuario_id, biografia)
  SELECT id, 'não sou mentora' FROM usuarios WHERE email = 'ana@teste.br';
  RAISE EXCEPTION 'FALHOU: T04 perfil de mentor para estudante foi aceito';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T04 perfis_mentor exige usuário MENTOR';
END $$;


-- Teste complementar após harmonização com RNF006: custo bcrypt inferior a 12.
DO $$ BEGIN
  INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em)
  VALUES ('Teste Custo', 'custo@teste.br', '$2b$10$' || repeat('K', 53), 'ESTUDANTE', now());
  RAISE EXCEPTION 'FALHOU: T38 hash com custo 10 foi aceito';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T38 custo bcrypt inferior a 12 bloqueado';
END $$;

-- ---------------------------------------------------------------------
-- DISPONIBILIDADES
-- ---------------------------------------------------------------------
DO $$ BEGIN
  INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
  SELECT u.id, r.h + interval '30 minutes', 60 FROM usuarios u, ref r WHERE u.email = 'carla@teste.br';
  RAISE EXCEPTION 'FALHOU: T05 horário sobreposto do mesmo mentor foi aceito';
EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE '[OK] T05 horários sobrepostos do mesmo mentor bloqueados';
END $$;

DO $$ BEGIN
  INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
  SELECT u.id, r.h + interval '5 hours', 60 FROM usuarios u, ref r WHERE u.email = 'ana@teste.br';
  RAISE EXCEPTION 'FALHOU: T06 estudante criou disponibilidade';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T06 disponibilidade exige usuário MENTOR';
END $$;


-- Teste complementar RF008: duração de 90 min fora das opções 30, 45, 60.
DO $$ BEGIN
  INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
  SELECT u.id, r.h + interval '6 hours', 90
    FROM usuarios u, ref r WHERE u.email = 'carla@teste.br';
  RAISE EXCEPTION 'FALHOU: T39 duração de 90 min foi aceita';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T39 duração diferente de 30, 45 ou 60 bloqueada';
END $$;

-- ---------------------------------------------------------------------
-- AGENDAMENTOS — criação e conflitos
-- ---------------------------------------------------------------------
-- Ana solicita Carla 10:00 em BD1 (deve funcionar)
INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos, observacao)
SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos, 'Dúvida sobre normalização'
  FROM disponibilidades dp
  JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'carla@teste.br'
  JOIN ref r ON dp.inicio_em = r.h
  CROSS JOIN (SELECT id FROM usuarios WHERE email = 'ana@teste.br') e
  CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'BD1') d;
DO $$ BEGIN
  IF (SELECT status FROM agendamentos ORDER BY id DESC LIMIT 1) <> 'PENDENTE' THEN
    RAISE EXCEPTION 'FALHOU: T07 agendamento não nasceu PENDENTE';
  END IF;
  RAISE NOTICE '[OK] T07 solicitação válida criada como PENDENTE';
END $$;

DO $$ BEGIN
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
  SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos
    FROM disponibilidades dp
    JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'carla@teste.br'
    JOIN ref r ON dp.inicio_em = r.h
    CROSS JOIN (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') e
    CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'BD1') d;
  RAISE EXCEPTION 'FALHOU: T08 segundo agendamento ativo na mesma disponibilidade foi aceito';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE '[OK] T08 dois agendamentos ativos na mesma disponibilidade bloqueados (índice parcial)';
END $$;

DO $$ BEGIN
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
  SELECT dp.id, e.id, (SELECT id FROM usuarios WHERE email = 'diego@teste.br'), d.id, dp.inicio_em, dp.duracao_minutos
    FROM disponibilidades dp
    JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'carla@teste.br'
    JOIN ref r ON dp.inicio_em = r.h + interval '1 hour'
    CROSS JOIN (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') e
    CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'APS') d;
  RAISE EXCEPTION 'FALHOU: T09 mentor diferente do dono da disponibilidade foi aceito';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '[OK] T09 mentor do agendamento precisa ser o da disponibilidade (FK composta)';
END $$;

DO $$ BEGIN
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
  SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em + interval '15 minutes', dp.duracao_minutos
    FROM disponibilidades dp
    JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'carla@teste.br'
    JOIN ref r ON dp.inicio_em = r.h + interval '1 hour'
    CROSS JOIN (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') e
    CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'APS') d;
  RAISE EXCEPTION 'FALHOU: T10 horário diferente do da disponibilidade foi aceito';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '[OK] T10 horário do agendamento precisa ser o da disponibilidade (FK composta)';
END $$;

DO $$ BEGIN
  -- Ana já tem 10:00–11:00 PENDENTE com Carla; tenta Diego 10:30–11:30
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
  SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos
    FROM disponibilidades dp
    JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'diego@teste.br'
    CROSS JOIN (SELECT id FROM usuarios WHERE email = 'ana@teste.br') e
    CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'APS') d;
  RAISE EXCEPTION 'FALHOU: T11 reservas sobrepostas do mesmo estudante foram aceitas';
EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE '[OK] T11 reservas ativas sobrepostas do mesmo estudante bloqueadas (exclusion constraint)';
END $$;

DO $$ BEGIN
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
  SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos
    FROM disponibilidades dp
    JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'diego@teste.br'
    CROSS JOIN (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') e
    CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'CALC1') d;
  RAISE EXCEPTION 'FALHOU: T12 disciplina não atendida pelo mentor foi aceita';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T12 disciplina precisa estar entre as do mentor';
END $$;

DO $$ BEGIN
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos, status)
  SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos, 'CONFIRMADO'
    FROM disponibilidades dp
    JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'diego@teste.br'
    CROSS JOIN (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') e
    CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'APS') d;
  RAISE EXCEPTION 'FALHOU: T13 agendamento criado já CONFIRMADO';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T13 agendamento sempre nasce PENDENTE';
END $$;

DO $$ BEGIN
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
  SELECT dp.id, dp.mentor_id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos
    FROM disponibilidades dp
    JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'diego@teste.br'
    CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'APS') d;
  RAISE EXCEPTION 'FALHOU: T14 mentor agendou como estudante';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T14 agendamento exige estudante com perfil ESTUDANTE';
END $$;


-- ---------------------------------------------------------------------
-- AGENDAMENTOS — máquina de estados e expiração
-- ---------------------------------------------------------------------
DO $$ BEGIN
  UPDATE agendamentos SET status = 'CONCLUIDO'
   WHERE estudante_id = (SELECT id FROM usuarios WHERE email = 'ana@teste.br') AND status = 'PENDENTE';
  RAISE EXCEPTION 'FALHOU: T15 PENDENTE → CONCLUIDO foi aceito';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T15 transição inválida PENDENTE → CONCLUIDO bloqueada';
END $$;

DO $$ BEGIN
  UPDATE agendamentos SET status = 'EXPIRADO'
   WHERE estudante_id = (SELECT id FROM usuarios WHERE email = 'ana@teste.br') AND status = 'PENDENTE';
  RAISE EXCEPTION 'FALHOU: T16 expirou antes de 48 horas';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T16 expiração antes de 48 h bloqueada';
END $$;

-- Mentor RECUSA → horário liberado e histórico preservado
UPDATE agendamentos SET status = 'RECUSADO', justificativa = 'Conflito de agenda'
 WHERE estudante_id = (SELECT id FROM usuarios WHERE email = 'ana@teste.br') AND status = 'PENDENTE';
INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos
  FROM disponibilidades dp
  JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'carla@teste.br'
  JOIN ref r ON dp.inicio_em = r.h
  CROSS JOIN (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') e
  CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'BD1') d;
DO $$ BEGIN
  IF (SELECT count(*) FROM agendamentos a JOIN disponibilidades dp ON dp.id = a.disponibilidade_id
       JOIN ref r ON dp.inicio_em = r.h) <> 2
     OR (SELECT respondido_em FROM agendamentos WHERE status = 'RECUSADO') IS NULL THEN
    RAISE EXCEPTION 'FALHOU: T17 histórico/respondido_em incorretos';
  END IF;
  RAISE NOTICE '[OK] T17 recusa libera o horário, mantém histórico e grava respondido_em';
END $$;

-- Expiração após 48 h: simula a passagem do tempo desligando o gatilho só neste teste
ALTER TABLE agendamentos DISABLE TRIGGER tg_agendamentos_validar_atualizacao;
UPDATE agendamentos SET criado_em = now() - interval '49 hours'
 WHERE estudante_id = (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') AND status = 'PENDENTE';
ALTER TABLE agendamentos ENABLE TRIGGER tg_agendamentos_validar_atualizacao;
-- Consulta que a rotina de expiração do backend executará:
UPDATE agendamentos SET status = 'EXPIRADO'
 WHERE status = 'PENDENTE' AND criado_em < now() - interval '48 hours';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM agendamentos WHERE status = 'EXPIRADO') THEN
    RAISE EXCEPTION 'FALHOU: T18 rotina de expiração não expirou';
  END IF;
  RAISE NOTICE '[OK] T18 pendente com mais de 48 h passa a EXPIRADO';
END $$;

-- Fluxo feliz completo: Ana → Carla 11:00 (APS) → CONFIRMADO → CONCLUIDO → sessão → avaliação
INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos
  FROM disponibilidades dp
  JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'carla@teste.br'
  JOIN ref r ON dp.inicio_em = r.h + interval '1 hour'
  CROSS JOIN (SELECT id FROM usuarios WHERE email = 'ana@teste.br') e
  CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'APS') d;

CREATE TEMP TABLE ag_feliz AS
SELECT a.id FROM agendamentos a JOIN ref r ON a.inicio_em = r.h + interval '1 hour';

UPDATE agendamentos SET status = 'CONFIRMADO' WHERE id = (SELECT id FROM ag_feliz);

DO $$ BEGIN
  INSERT INTO sessoes_mentoria (agendamento_id, compareceu, duracao_real_min)
  VALUES ((SELECT id FROM ag_feliz), true, 55);
  RAISE EXCEPTION 'FALHOU: T19 sessão registrada para agendamento não concluído';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '[OK] T19 sessão só existe para agendamento CONCLUIDO';
END $$;

UPDATE agendamentos SET status = 'CONCLUIDO' WHERE id = (SELECT id FROM ag_feliz);
INSERT INTO sessoes_mentoria (agendamento_id, compareceu, duracao_real_min, observacoes)
VALUES ((SELECT id FROM ag_feliz), true, 55, 'Revisão de diagramas UML');
DO $$ BEGIN RAISE NOTICE '[OK] T20 sessão registrada após conclusão'; END $$;

DO $$ BEGIN
  INSERT INTO sessoes_mentoria (agendamento_id, compareceu) VALUES ((SELECT id FROM ag_feliz), true);
  RAISE EXCEPTION 'FALHOU: T21 segunda sessão para o mesmo agendamento';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE '[OK] T21 no máximo uma sessão por agendamento';
END $$;

DO $$ BEGIN
  UPDATE agendamentos SET status = 'CANCELADO' WHERE id = (SELECT id FROM ag_feliz);
  RAISE EXCEPTION 'FALHOU: T22 agendamento concluído foi reaberto';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T22 CONCLUIDO é estado final';
END $$;


-- ---------------------------------------------------------------------
-- AVALIAÇÕES
-- ---------------------------------------------------------------------
DO $$ BEGIN
  INSERT INTO avaliacoes (sessao_id, nota)
  SELECT id, 6 FROM sessoes_mentoria WHERE agendamento_id = (SELECT id FROM ag_feliz);
  RAISE EXCEPTION 'FALHOU: T23 nota 6 aceita';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T23 nota fora de 1 a 5 bloqueada';
END $$;

INSERT INTO avaliacoes (sessao_id, nota, comentario)
SELECT id, 5, 'Excelente' FROM sessoes_mentoria WHERE agendamento_id = (SELECT id FROM ag_feliz);
DO $$ BEGIN RAISE NOTICE '[OK] T24 avaliação válida registrada'; END $$;

DO $$ BEGIN
  INSERT INTO avaliacoes (sessao_id, nota)
  SELECT id, 4 FROM sessoes_mentoria WHERE agendamento_id = (SELECT id FROM ag_feliz);
  RAISE EXCEPTION 'FALHOU: T25 avaliação duplicada aceita';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE '[OK] T25 avaliação duplicada da mesma sessão bloqueada';
END $$;

-- Sessão sem comparecimento (Bruno ↔ Diego) não pode ser avaliada
INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos
  FROM disponibilidades dp
  JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'diego@teste.br'
  CROSS JOIN (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') e
  CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'APS') d;
UPDATE agendamentos SET status = 'CONFIRMADO'
 WHERE mentor_id = (SELECT id FROM usuarios WHERE email = 'diego@teste.br');
UPDATE agendamentos SET status = 'CONCLUIDO'
 WHERE mentor_id = (SELECT id FROM usuarios WHERE email = 'diego@teste.br');
INSERT INTO sessoes_mentoria (agendamento_id, compareceu)
SELECT id, false FROM agendamentos WHERE mentor_id = (SELECT id FROM usuarios WHERE email = 'diego@teste.br');

DO $$ BEGIN
  INSERT INTO avaliacoes (sessao_id, nota)
  SELECT s.id, 3 FROM sessoes_mentoria s WHERE NOT s.compareceu;
  RAISE EXCEPTION 'FALHOU: T26 avaliação de sessão sem comparecimento aceita';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '[OK] T26 só avalia sessão com comparecimento';
END $$;

DO $$ BEGIN
  UPDATE sessoes_mentoria SET compareceu = false, duracao_real_min = NULL
   WHERE agendamento_id = (SELECT id FROM ag_feliz);
  RAISE EXCEPTION 'FALHOU: T27 sessão avaliada mudou para sem comparecimento';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '[OK] T27 sessão já avaliada não pode virar "não compareceu"';
END $$;


-- ---------------------------------------------------------------------
-- DISPONIBILIDADE COM HISTÓRICO
-- ---------------------------------------------------------------------
DO $$ BEGIN
  UPDATE disponibilidades SET inicio_em = inicio_em + interval '3 hours'
   WHERE id = (SELECT disponibilidade_id FROM agendamentos WHERE id = (SELECT id FROM ag_feliz));
  RAISE EXCEPTION 'FALHOU: T28 horário com histórico foi alterado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T28 horário de disponibilidade com histórico é imutável';
END $$;


-- ---------------------------------------------------------------------
-- ADMINISTRAÇÃO E AUDITORIA
-- ---------------------------------------------------------------------
DO $$ BEGIN
  UPDATE usuarios SET ativo = false WHERE email = 'fabio@teste.br';
  RAISE EXCEPTION 'FALHOU: T29 último administrador desativado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T29 desativar o último administrador ativo é bloqueado';
END $$;

DO $$ BEGIN
  UPDATE usuarios SET perfil = 'COORDENADOR' WHERE email = 'fabio@teste.br';
  RAISE EXCEPTION 'FALHOU: T30 último administrador rebaixado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T30 rebaixar o último administrador ativo é bloqueado';
END $$;

-- Com um segundo administrador, desativar o primeiro passa a ser permitido
INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em)
VALUES ('Gabi Admin', 'gabi@teste.br', '$2b$12$' || repeat('G', 53), 'ADMINISTRADOR', now());
UPDATE usuarios SET ativo = false WHERE email = 'fabio@teste.br';
INSERT INTO logs_auditoria (administrador_id, acao, tipo_alvo, alvo_id)
SELECT g.id, 'DESATIVAR_USUARIO', 'USUARIO', f.id
  FROM usuarios g, usuarios f WHERE g.email = 'gabi@teste.br' AND f.email = 'fabio@teste.br';
DO $$ BEGIN RAISE NOTICE '[OK] T31 com dois administradores, um pode ser desativado (e a ação é auditada)'; END $$;

DO $$ BEGIN
  UPDATE logs_auditoria SET acao = 'OUTRA_ACAO';
  RAISE EXCEPTION 'FALHOU: T32 log de auditoria alterado';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE '[OK] T32 log de auditoria não pode ser alterado';
END $$;

DO $$ BEGIN
  DELETE FROM logs_auditoria;
  RAISE EXCEPTION 'FALHOU: T33 log dentro da retenção apagado';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE '[OK] T33 log dentro do prazo de retenção não pode ser apagado';
END $$;

DO $$ BEGIN
  INSERT INTO logs_auditoria (administrador_id, acao, tipo_alvo, alvo_id)
  SELECT id, 'ALTERAR_PERFIL', 'USUARIO', id FROM usuarios WHERE email = 'elisa@teste.br';
  RAISE EXCEPTION 'FALHOU: T34 coordenador gravou log administrativo';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T34 autor do log precisa ser ADMINISTRADOR';
END $$;


-- ---------------------------------------------------------------------
-- HORÁRIO FUTURO E MENTOR ATIVO
-- ---------------------------------------------------------------------
INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
SELECT id, now() - interval '3 hours', 60 FROM usuarios WHERE email = 'diego@teste.br';
DO $$ BEGIN
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
  SELECT dp.id, (SELECT id FROM usuarios WHERE email = 'ana@teste.br'), dp.mentor_id,
         (SELECT id FROM disciplinas WHERE codigo = 'APS'), dp.inicio_em, dp.duracao_minutos
    FROM disponibilidades dp WHERE dp.inicio_em < now();
  RAISE EXCEPTION 'FALHOU: T36 solicitação para horário passado aceita';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T36 só é possível solicitar horários futuros';
END $$;

INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
SELECT u.id, r.h + interval '6 hours', 60 FROM usuarios u, ref r WHERE u.email = 'diego@teste.br';
UPDATE usuarios SET ativo = false WHERE email = 'diego@teste.br';
DO $$ BEGIN
  INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
  SELECT dp.id, (SELECT id FROM usuarios WHERE email = 'ana@teste.br'), dp.mentor_id,
         (SELECT id FROM disciplinas WHERE codigo = 'APS'), dp.inicio_em, dp.duracao_minutos
    FROM disponibilidades dp JOIN ref r ON dp.inicio_em = r.h + interval '6 hours';
  RAISE EXCEPTION 'FALHOU: T37 mentor inativo recebeu solicitação';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '[OK] T37 mentor desativado não recebe novas solicitações';
END $$;


-- ---------------------------------------------------------------------
-- VISÕES GERENCIAIS (LGPD: sem dados do estudante)
-- ---------------------------------------------------------------------
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_name IN ('vw_mentorias_coordenacao', 'vw_relatorio_avaliacoes')
                AND column_name LIKE 'estudante%') THEN
    RAISE EXCEPTION 'FALHOU: T35 visão gerencial expõe o estudante';
  END IF;
  IF (SELECT media_nota FROM vw_relatorio_avaliacoes WHERE disciplina_nome = 'Análise e Projeto de Sistemas'
       AND mentor_nome = 'Carla Mentora') <> 5 THEN
    RAISE EXCEPTION 'FALHOU: T35 média do relatório incorreta';
  END IF;
  RAISE NOTICE '[OK] T35 visões da coordenação funcionam e não identificam o estudante';
END $$;

SELECT * FROM vw_mentorias_coordenacao ORDER BY inicio_em, agendamento_id;

-- ---------------------------------------------------------------------
-- REGRAS DE INTEGRAÇÃO FINAL — RN11, RN12 e RN13
-- ---------------------------------------------------------------------
-- T40: com pedido ativo, não se pode inativar a disponibilidade.
-- Usa novo horário isolado da massa principal para não depender de T07–T39.
INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
SELECT u.id, r.h + interval '8 hours', 30
  FROM usuarios u, ref r WHERE u.email = 'carla@teste.br';
INSERT INTO agendamentos
       (disponibilidade_id, estudante_id, mentor_id, disciplina_id, inicio_em, duracao_minutos)
SELECT dp.id, e.id, dp.mentor_id, d.id, dp.inicio_em, dp.duracao_minutos
  FROM disponibilidades dp
  JOIN usuarios m ON m.id = dp.mentor_id AND m.email = 'carla@teste.br'
  JOIN ref r ON dp.inicio_em = r.h + interval '8 hours'
  CROSS JOIN (SELECT id FROM usuarios WHERE email = 'bruno@teste.br') e
  CROSS JOIN (SELECT id FROM disciplinas WHERE codigo = 'BD1') d;
DO $$ BEGIN
  UPDATE disponibilidades SET ativa = false WHERE id = (
    SELECT dp.id FROM disponibilidades dp JOIN usuarios m ON m.id=dp.mentor_id
     JOIN ref r ON dp.inicio_em=r.h+interval '8 hours' WHERE m.email='carla@teste.br'
  );
  RAISE EXCEPTION 'FALHOU: T40 disponibilidade com reserva ativa foi inativada';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE '[OK] T40 reserva ativa impede inativar disponibilidade';
END $$;

-- T41: mesmo mentor sem reservas, há horário futuro ativo e a troca de perfil
-- deve exigir inativação prévia do horário.
INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em)
VALUES ('Hilda Mentora', 'hilda@teste.br', '$2b$12$' || repeat('J', 53), 'MENTOR', now());
INSERT INTO disponibilidades (mentor_id, inicio_em, duracao_minutos)
SELECT u.id, r.h + interval '10 hours', 45
  FROM usuarios u, ref r WHERE u.email = 'hilda@teste.br';
DO $$ BEGIN
  UPDATE usuarios SET perfil = 'COORDENADOR' WHERE email = 'hilda@teste.br';
  RAISE EXCEPTION 'FALHOU: T41 mentor com horário ativo mudou perfil';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE '[OK] T41 troca de perfil exige inativar horários futuros';
END $$;
UPDATE disponibilidades SET ativa = false WHERE mentor_id=(SELECT id FROM usuarios WHERE email='hilda@teste.br');
UPDATE usuarios SET perfil = 'COORDENADOR' WHERE email='hilda@teste.br';
DO $$ BEGIN
  IF (SELECT perfil FROM usuarios WHERE email='hilda@teste.br') <> 'COORDENADOR' THEN
    RAISE EXCEPTION 'FALHOU: T41 troca não foi liberada após encerramento';
  END IF;
  RAISE NOTICE '[OK] T41b troca de perfil liberada depois de inativar horários';
END $$;

-- T42: estudante com reserva futura ativa não pode perder o perfil ESTUDANTE.
DO $$ BEGIN
  UPDATE usuarios SET perfil='COORDENADOR' WHERE email='bruno@teste.br';
  RAISE EXCEPTION 'FALHOU: T42 estudante com reserva ativa mudou perfil';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE '[OK] T42 estudante com reserva futura ativa não pode mudar perfil';
END $$;

-- T43: cadastro institucional exige referência de aceite do próprio titular.
DO $$ BEGIN
  INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em,
                       aceite_privacidade_fonte)
  VALUES ('Mentor Sem Evidência', 'sem-evidencia@teste.br',
          '$2b$12$' || repeat('H',53), 'MENTOR', now(), 'INSTITUCIONAL');
  RAISE EXCEPTION 'FALHOU: T43 aceite institucional sem referência foi aceito';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE '[OK] T43 cadastro institucional exige referência do aceite';
END $$;
INSERT INTO usuarios (nome, email, senha_hash, perfil, aceite_privacidade_em,
                     aceite_privacidade_fonte, aceite_privacidade_referencia)
VALUES ('Mentor Com Evidência', 'com-evidencia@teste.br',
        '$2b$12$' || repeat('H',53), 'MENTOR', now(), 'INSTITUCIONAL', 'TERMO-INST-2026-001');
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuarios WHERE email='com-evidencia@teste.br'
       AND aceite_privacidade_fonte='INSTITUCIONAL'
       AND aceite_privacidade_referencia='TERMO-INST-2026-001') THEN
    RAISE EXCEPTION 'FALHOU: T43 cadastro com aceite comprovado não registrado';
  END IF;
  RAISE NOTICE '[OK] T43b origem e referência de aceite institucional registradas';
END $$;

ROLLBACK;  -- desfaz tudo: o banco volta a ficar vazio
