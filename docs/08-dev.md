# Bloco 8 — Documentação do Desenvolvedor

**Projeto:** MentorIA Acadêmica · **Responsável:** Guilherme · **Equipe:** Hadson, Kennedy e Guilherme
**Versão:** 1.0 · **Data:** 08/11/2026

> A aplicação **ainda não foi implementada**. Este guia define como ela será construída, para que qualquer desenvolvedor da equipe futura comece a Sprint 1 com padrões claros e coerentes com a arquitetura (Kennedy), os requisitos (Hadson) e o banco (Bloco 5).

**Artefatos deste bloco:** [`README.md`](../README.md) · [`.env.example`](../.env.example) · [`api/openapi.yaml`](../api/openapi.yaml)

---

## 1. Visão geral do código

- **Monólito modular:** um processo Node.js 24 + Express 5 serve `public/` (frontend) e `/api` (REST).
- **Seis módulos** em `src/modulos/`: `autenticacao`, `usuarios`, `mentorias`, `agendamentos`, `avaliacoes` e `administracao`. Eles estão mapeados para os 5 módulos do C4 de Kennedy no [diagrama de componentes](../diagramas/imagens/uml-componentes.png).
- **Um módulo não acessa as tabelas de outro.** Ele chama a interface interna do outro (por exemplo, `usuariosService.buscarAtivo(id)`). As tabelas de cada módulo estão listadas no diagrama de componentes.
- **Núcleo compartilhado** (`src/core/`): pool do `pg` e `transacao()`, configuração (`dotenv`), erros e middlewares.

```text
src/
├── app.js  · server.js
├── core/
│   ├── config/env.js          # lê e valida o .env (dotenv)
│   ├── db/pool.js             # Pool do pg + transacao(fn)
│   ├── erros/AppError.js      # NaoEncontrado, Conflito, SemPermissao, DadosInvalidos…
│   ├── erros/traduzirErroPg.js
│   └── middlewares/           # autenticar.js, autorizar.js, validar.js, tratarErros.js
└── modulos/agendamentos/
    ├── agendamentos.routes.js
    ├── agendamento.controller.js
    ├── agendamento.service.js
    ├── agendamento.repository.js
    └── expiracao.job.js       # rotina de 48 h
```

---

## 2. Padrões de projeto

### 2.1 Repository: só SQL, sempre parametrizado
O Repository é a **única** camada que fala com o PostgreSQL. Ele não contém regra de negócio.
```js
// src/modulos/agendamentos/agendamento.repository.js
export async function inserir(client, a) {
  const { rows } = await client.query(
    `INSERT INTO agendamentos (disponibilidade_id, estudante_id, mentor_id, disciplina_id,
                               inicio_em, duracao_minutos, observacao)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [a.disponibilidadeId, a.estudanteId, a.mentorId, a.disciplinaId, a.inicioEm, a.duracaoMinutos, a.observacao ?? null]
  );
  return paraCamelCase(rows[0]);
}
```
- **Proibido** montar SQL com *template string* contendo dados do usuário (`WHERE email = '${email}'`), porque isso abre caminho para SQL injection. Valores entram sempre como `$1, $2…`.
- Nomes de colunas dinâmicos (como a ordenação) só podem vir de uma *lista branca* (`{ data: 'inicio_em', status: 'status' }`).
- O Repository recebe o `client` da transação quando a operação faz parte de uma.

### 2.2 Service Layer: regras de negócio e transações
```js
// src/modulos/agendamentos/agendamento.service.js
export async function solicitar(usuario, dados) {
  return transacao(async (client) => {
    const disp = await disponibilidadeRepo.bloquearPorId(client, dados.disponibilidadeId); // SELECT … FOR UPDATE
    if (!disp) throw new NaoEncontrado('Disponibilidade inexistente');
    await agendamentoRepo.expirarPendentesVencidos(client, disp.id);                    // expiração preguiçosa
    return agendamentoRepo.inserir(client, { ...dados, estudanteId: usuario.id,
      mentorId: disp.mentorId, inicioEm: disp.inicioEm, duracaoMinutos: disp.duracaoMinutos });
  });
}
```
- Valida **titularidade** (só o mentor do agendamento confirma; só o estudante do agendamento avalia).
- Abre a transação quando há mais de uma escrita (ex.: concluir = atualizar o status + criar a sessão).
- Nunca conhece `req` nem `res`.

### 2.3 Controller: fino
```js
// src/modulos/agendamentos/agendamento.controller.js
export async function criar(req, res) {
  const agendamento = await agendamentoService.solicitar(req.usuario, req.body);
  res.status(201).location(`/api/agendamentos/${agendamento.id}`).json(agendamento);
}
```
O Controller traduz HTTP ↔ Service e define o status de sucesso. No Express 5, erros de funções `async` chegam automaticamente ao middleware de erro, sem precisar de `try/catch` em cada rota.

### 2.4 Pipeline de cada rota protegida
```js
router.patch('/:id/status',
  autenticar,                                  // valida o JWT (15 min) e recarrega ativo/perfil no banco
  autorizar('ESTUDANTE', 'MENTOR'),            // RBAC (x-perfis-permitidos do OpenAPI)
  validar(esquemaAlteracaoStatus),             // corpo e parâmetros → 422
  agendamentoController.alterarStatus);        // titularidade é verificada no Service → 403
```

---

## 3. Convenções de código

| Tema | Convenção |
|---|---|
| Módulos JS | ES Modules (`"type": "module"` no `package.json`) |
| Nomes | `camelCase` para variáveis e funções, `PascalCase` para classes, `UPPER_SNAKE` para constantes; arquivos `nome.camada.js` |
| Idioma | Domínio em **português, sem acento** (`agendamento`, `disponibilidade`), igual ao banco e ao UML |
| Banco ↔ JSON | `snake_case` no SQL e `camelCase` no JSON, convertidos no Repository |
| Async | `async/await`; nada de *callbacks* |
| Datas | ISO 8601 com fuso na API; `timestamptz` no banco |
| Rotas | Substantivos no plural (`/api/agendamentos`); ação de estado via `PATCH …/status` |
| Status HTTP | 200 leitura/alteração · 201 criação (+ `Location`) · 204 sem corpo · 401 · 403 · 404 · **409 conflito** · 422 validação |
| Tamanho | Funções curtas, uma responsabilidade; Controller sem SQL; Repository sem regra |
| Comentários | Explicam o **porquê**, não o óbvio |

---

## 4. Segurança

| Ameaça | Controle |
|---|---|
| SQL injection | Consultas parametrizadas (`pg`), sem ORM e sem concatenação |
| Senhas vazadas | `bcryptjs` com custo 12; o hash nunca é devolvido pela API; o banco rejeita valor que não seja hash bcrypt |
| Token roubado | JWT de **15 min** sem *refresh*; segredo forte no `.env`; o usuário desativado perde o acesso na próxima requisição |
| Acesso indevido | RBAC por rota + titularidade no Service + visões anônimas para a coordenação |
| Força bruta no login | Nginx `limit_req` em `/api/auth/login` (429); mensagem genérica de erro |
| Tráfego interceptado | HTTPS obrigatório (Let's Encrypt); HTTP redireciona com 301 |
| Banco exposto | PostgreSQL só em `localhost`; porta 5432 fechada no firewall do Lightsail |
| XSS no frontend | Inserir dados com `textContent`, nunca `innerHTML` com dado do usuário; cabeçalho `Content-Security-Policy` no Nginx |
| Segredos no Git | `.env` no `.gitignore`; apenas `.env.example`; *secret scanning* do GitHub |
| Excesso de dados (LGPD) | Respostas trazem só os campos necessários; logs sem senha, token ou corpo de requisição |

---

## 5. Tratamento de erros

Formato único (schema `Erro` do OpenAPI):
```json
{ "codigo": "HORARIO_INDISPONIVEL", "mensagem": "Este horário acabou de ser reservado.", "regra": "ux_agendamentos_disponibilidade_ativa" }
```

**Tradução de erros do PostgreSQL** (`core/erros/traduzirErroPg.js`):

| `err.code` | Significado | HTTP | Código da API |
|---|---|---|---|
| `23505` | unique_violation | **409** | `EMAIL_JA_CADASTRADO`, `HORARIO_INDISPONIVEL`, `AVALIACAO_DUPLICADA` (pelo `err.constraint`) |
| `23P01` | exclusion_violation | **409** | `HORARIO_SOBREPOSTO`, `RESERVA_SOBREPOSTA` |
| `23514` | check_violation / regra `rn_*` | **409** (estado: transição, último administrador) ou **422** (dado: nota, horário passado) | conforme `err.constraint` |
| `23503` | foreign_key_violation | 404 ou 409 | `NAO_ENCONTRADO`, `REFERENCIA_INVALIDA` |
| outros | erro inesperado | 500 | `ERRO_INTERNO` (detalhe só no log do servidor) |

```js
// core/middlewares/tratarErros.js
export function tratarErros(err, req, res, _next) {
  const e = err instanceof AppError ? err : traduzirErroPg(err);
  if (e.status >= 500) logger.error({ err, rota: req.originalUrl }); // nunca logar req.body
  res.status(e.status).json({ codigo: e.codigo, mensagem: e.mensagem, regra: e.regra, detalhes: e.detalhes });
}
```

---

## 6. Testes

| Tipo | Ferramenta | Onde | O que cobre |
|---|---|---|---|
| Unitário | `node:test` + `node:assert` | `tests/unit` | Services com repositórios simulados (transições, titularidade) |
| Integração | `node:test` + Supertest + PostgreSQL de teste | `tests/integration` | Cada rota do OpenAPI: sucesso, 401, 403, 404, **409** e 422 |
| Concorrência | `Promise.all` com duas requisições | `tests/integration` | Duas reservas simultâneas → um 201 e um 409 |
| E2E | Playwright | `tests/e2e` | Cadastro → busca → solicitação → confirmação → conclusão → avaliação |
| Banco | `sql/testes-validacao.sql` | pgAdmin/psql | 38 regras de integridade |

```js
// tests/integration/agendamentos.test.js
test('dois estudantes no mesmo horário: um 201 e um 409', async () => {
  const [a, b] = await Promise.all([
    request(app).post('/api/agendamentos').set('Authorization', `Bearer ${tokenAna}`).send(pedido),
    request(app).post('/api/agendamentos').set('Authorization', `Bearer ${tokenBruno}`).send(pedido),
  ]);
  assert.deepEqual([a.status, b.status].sort(), [201, 409]);
});
```
Meta de cobertura: a definida por Hadson no Bloco 9. Até lá, a referência é **≥ 80% nas camadas Service**.

---

## 7. Git e GitHub

### 7.1 Branches
| Branch | Uso | Deploy |
|---|---|---|
| `main` | Código em produção; protegida | Produção (Lightsail 2 GB) |
| `develop` | Integração da sprint; protegida | Staging (Lightsail 1 GB) |
| `feature/<item>-<descricao>` | Uma história ou item do backlog (`feature/US008-solicitar-agendamento`) | — |
| `fix/<descricao>` | Correção em `develop` | — |
| `hotfix/<descricao>` | Correção urgente a partir de `main` | Produção, com *merge* de volta em `develop` |

### 7.2 Commits (Conventional Commits, em português)
```text
feat(agendamentos): retorna 409 quando o horário já está reservado
fix(auth): recusa token de usuário desativado
test(avaliacoes): cobre avaliação duplicada
docs(api): documenta PATCH /agendamentos/{id}/status
db(migrations): V002 adiciona índice de pendentes
chore: atualiza dependências
```
Commits pequenos, no imperativo, com uma mudança lógica cada.

### 7.3 Pull Requests
- Todo código entra por PR para `develop` (ou `main`, só em *hotfix*).
- **Pelo menos 1 aprovação** de outro membro; o autor não aprova o próprio PR.
- O CI do GitHub roda `npm test`, que precisa passar.
- **Checklist do PR:** história vinculada · testes novos · OpenAPI atualizado se a rota mudou · migração versionada se o banco mudou · nada de segredo no diff · `README` e docs atualizados.
- *Squash merge* com mensagem no padrão de commits.

---

## 8. Deploy (staging e produção)

```bash
# Na instância Lightsail (SSH com chave)
cd /opt/mentoria-academica
git pull origin develop            # main em produção
npm ci --omit=dev
npm run db:migrate                 # migrações compatíveis (expandir → migrar → contrair)
sudo systemctl restart mentoria    # unit systemd; o Nginx continua atendendo
```

```nginx
# /etc/nginx/sites-available/mentoria (trecho)
server { listen 80; server_name mentoria-academica.com.br; return 301 https://$host$request_uri; }
server {
  listen 443 ssl;
  server_name mentoria-academica.com.br;
  ssl_certificate     /etc/letsencrypt/live/mentoria-academica.com.br/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/mentoria-academica.com.br/privkey.pem;
  location /api/auth/login { limit_req zone=login burst=5; proxy_pass http://127.0.0.1:3000; }
  location / { proxy_pass http://127.0.0.1:3000; proxy_set_header X-Forwarded-For $remote_addr; }
}
```

---

## 9. Sprint 1 — planejamento detalhado (backlog oficial)

**Responsável pela priorização:** Hadson (PO). Fonte: `docs/02-requisitos.md` e
cronograma `docs/09-qualidade.md`. **Sprint 0** já previu criação do repositório,
configuração de banco, pipeline, migrações e estudos técnicos. Portanto essas
tarefas não recebem story points novamente.

**Período ilustrativo:** 01/02/2027 a 12/02/2027 · **Compromisso: 17 pontos**.

**Meta:** permitir autocadastro de estudantes, autenticação JWT de 15 minutos,
autorização RBAC e gestão administrativa de contas, perfis e catálogo.

| História oficial | Pontos | Tarefas principais | Responsável proposto |
|---|---:|---|---|
| **US001** Cadastro de estudante (RF001) | 3 | `POST /api/usuarios`, obrigatoriamente perfil ESTUDANTE; validação, senha bcryptjs (12 rounds), aceite de privacidade e teste de e-mail duplicado | Dev Full Stack 1 |
| **US002** Login/logout (RF002) | 3 | `POST /api/auth/login`, JWT 15 min, tela de login/logout, revogação lógica por expiração e checagem de usuário ativo por requisição, limitação de tentativas | Dev Full Stack 2 |
| **US003** Gestão de usuários e perfis (RF004–RF005) | 8 | `POST /api/administracao/usuarios`, `PATCH /api/administracao/usuarios/{id}`, proteção do último administrador, desativação com cancelamento dos agendamentos ativos futuros, auditoria, testes 401/403 | Devs + Tech Lead |
| **US016** Catálogo de disciplinas (RF021) | 3 | Administração cria, edita, inativa e reativa disciplinas; `GET /api/disciplinas`; impedir exclusão física com histórico | Dev Full Stack 1 |
| **Total** | **17** | Revisão de código, documentação OpenAPI e testes de integração incluídos no trabalho das histórias | Equipe |

### 9.1 Exemplos de critérios de aceite Given/When/Then

- **US001:** Dado um e-mail institucional válido ainda não cadastrado, quando o estudante aceita a política e envia o cadastro, então o backend cria uma conta `ESTUDANTE`, sem permitir seleção de `MENTOR`.
- **US002:** Dado um usuário ativo, quando faz login válido, então recebe JWT de 15 min; dado um usuário inativo, mesmo com token válido, quando acessa rota protegida, então recebe 401.
- **US003:** Dado um administrador com data e referência de aceite já prestado pelo titular, quando cria um mentor, então a conta tem perfil `MENTOR`, registra origem `INSTITUCIONAL` e referência no banco e audita a ação; sem evidência a API retorna 422; dado o último administrador ativo, quando tenta se desativar, então recebe erro de conflito.
- **US016:** Dado uma disciplina com histórico, quando o administrador a inativa, então novas associações são proibidas mas o histórico persiste.

### 9.2 Definition of Done (DoD)

Para o aceite vale integralmente a DoD mais completa definida por Hadson no
`docs/09-qualidade.md`, incluindo revisão de PR, 100% das rotas com testes de
integração, RBAC 401/403, OpenAPI atualizado, consultas parametrizadas,
segredos fora do Git, responsividade, mensagens em português e validação em
ambiente de teste. As metas gerais são ≥75% de linhas no backend, ≥80% nos
serviços e ≥90% nas regras críticas, sem queda de cobertura por PR.

A Sprint 1 é **plano hipotético**, não software implementado nem testes executados
na API. A validação original relatada por Guilherme diz respeito ao SQL do banco;
a revisão posterior deve executar novamente o DDL atualizado.

### Regras administrativas para implementação — RN11–RN13

- **RN11:** antes de mudar perfil de mentor/estudante, resolver reservas futuras ativas e inativar disponibilidades futuras. Banco recusa alteração incompatível; HTTP 409.
- **RN12:** criação administrativa exige aceite do titular previamente documentado; requer `aceiteTitularEm` e `referenciaAceite`, sem consentimento prestado pelo administrador. Sem evidência: HTTP 422.
- **RN13:** editar horários só sem histórico; com histórico, inativar e criar novo, desde que não exista reserva ativa.

O funcionamento é uma especificação de implementação, não endpoint em produção.
