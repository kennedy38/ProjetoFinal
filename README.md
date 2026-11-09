# MentorIA Acadêmica — Projeto Final APS

**Projeto acadêmico de Engenharia de Software** desenvolvido por Hadson (Requisitos e Produto), Kennedy (Arquitetura e UML) e Guilherme (Banco de Dados, Planejamento e Handoff).

> **Este repositório contém o projeto e a documentação técnica, não uma aplicação implementada.** Os custos, requisitos não funcionais e resultados esperados são estimativas ou metas. Os scripts SQL são artefatos propostos e ainda precisam ser executados e validados em um PostgreSQL real.

## Sobre o sistema

O **MentorIA Acadêmica** é uma proposta de plataforma web para organizar mentorias entre estudantes e mentores, com acompanhamento por coordenadores e administração de contas e disciplinas. Possui quatro perfis: `ESTUDANTE`, `MENTOR`, `COORDENADOR` e `ADMINISTRADOR`.

Fluxo principal: pesquisar mentor por disciplina, consultar disponibilidade, solicitar agendamento `PENDENTE`, obter confirmação/recusa do mentor, registrar a sessão realizada e avaliá-la. Uma disponibilidade não pode ter duas reservas ativas (`PENDENTE` ou `CONFIRMADO`). Pedidos não respondidos em 48 horas expiram.

## Tecnologias propostas

| Área | Tecnologia / padrão |
|---|---|
| Interface web | HTML5, CSS3, JavaScript e Bootstrap 5.3 |
| API REST | Node.js 24 LTS, Express 5 e JSON |
| Persistência | PostgreSQL 16 e biblioteca `pg` (sem ORM) |
| Autenticação e autorização | JWT de 15 minutos, `bcryptjs`, RBAC e revalidação de usuário ativo |
| Arquitetura | Monólito modular, Controller / Service / Repository |
| Hospedagem prevista | AWS Lightsail Linux, com Nginx e HTTPS |
| Testes previstos | `node:test`, Supertest, Playwright e SQL no PostgreSQL |

## Documentação do projeto

| Bloco | Conteúdo | Arquivo | Responsável |
|---|---|---|---|
| 1 | Concepção, visão, personas, stakeholders e viabilidade | [01 — Concepção](docs/01-concepcao.md) | Hadson |
| 2 | Requisitos, regras de negócio e histórias de usuário | [02 — Requisitos](docs/02-requisitos.md) | Hadson |
| 3 | Arquitetura, C4, tecnologias e ADRs | [03 — Arquitetura](docs/03-arquitetura.md) | Kennedy |
| 4 | Nove diagramas UML | [04 — UML](docs/04-uml.md) | Trio |
| 5 | Banco de dados, DER, modelagem e integridade | [05 — Banco](docs/05-banco.md) | Guilherme |
| 7 | Cronograma, estimativas e riscos | [07 — Planejamento](docs/07-planejamento.md) | Guilherme |
| 8 | Guia para futuro desenvolvimento | [08 — Desenvolvimento](docs/08-dev.md) | Guilherme |
| 9 | Testes, qualidade, Scrum, DoR e DoD | [09 — Qualidade](docs/09-qualidade.md) | Hadson |

O Bloco 6 foi definido como opcional; a arquitetura de implantação e a viabilidade de infraestrutura estão documentadas nos blocos obrigatórios. Consulte também [decisões compartilhadas](docs/00-decisoes-compartilhadas.md), [ADRs](docs/adrs/ADR-001.md) e o [documento consolidado](PROJETO_COMPLETO.md).

## Diagramas, SQL e API

- [Catálogo dos 15 diagramas](diagramas/README.md): 4 C4, 9 UML e 2 DER; fontes editáveis e imagens PNG.
- [DDL do PostgreSQL](sql/schema.sql), [modelo DBML](sql/modelo-banco.dbml) e [dicionário de dados](docs/dicionario-dados.md).
- [Testes SQL propostos](sql/testes-validacao.sql): cenários identificados de `T00` a `T43` (incluem verificações complementares); não há evidência aqui de execução da suíte completa.
- [Contrato OpenAPI 3.0](api/openapi.yaml): especificação da futura API, sem servidor funcional neste repositório.
- [Roteiro da apresentação](apresentacao/roteiro-10-min.md): divisão sugerida para até 10 minutos.

## Como consultar ou validar os artefatos

1. Leia os blocos na pasta `docs/` ou a versão [consolidada](PROJETO_COMPLETO.md).
2. Abra as fontes `.drawio` no [diagrams.net](https://app.diagrams.net/) e os DER `.mmd` em um editor Mermaid; os PNGs estão prontos para visualização.
3. Para validar o banco, use **um PostgreSQL 16 de testes**, vazio e isolado. Execute primeiro `sql/schema.sql` e depois `sql/testes-validacao.sql` com uma ferramenta SQL que interrompa em erro. Guarde o log da execução. A suíte usa `ROLLBACK`, não devendo ser executada em banco de produção.
4. Revise `api/openapi.yaml` no [Swagger Editor](https://editor.swagger.io/) para visualizar os endpoints previstos.
5. Para regenerar `PROJETO_COMPLETO.md` após editar os blocos, execute `python scripts/consolidar.py` (Python 3).

**Limites de validação:** os arquivos e a sintaxe de documentos podem ser inspecionados sem servidor, mas desempenho, disponibilidade, execução dos 44 cenários SQL e comportamento de API não estão demonstrados por uma implementação funcional. **Não declarar esses testes como aprovados sem executá-los.**

## Estrutura

```text
.
├── api/                    # Contrato OpenAPI 3.0
├── apresentacao/           # Roteiro de apresentação
├── diagramas/
│   ├── editaveis/          # Draw.io e fontes Mermaid
│   └── imagens/            # Exportações PNG
├── docs/
│   └── adrs/               # Decisões arquiteturais
├── scripts/                # Atualização do documento consolidado
├── sql/                    # DDL, DBML e testes de banco
├── .env.example            # Exemplo de variáveis futuras, sem segredos
├── .gitignore
├── PROJETO_COMPLETO.md
└── README.md
```
