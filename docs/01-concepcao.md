# MentorIA Acadêmica — Bloco 1: Concepção e Escopo

**Responsável:** Hadson — Pessoa 1, Analista de Requisitos / Product Owner · **Versão:** 1.2 · **Data:** 06/11/2026

Documentos relacionados: [Bloco 2 — Requisitos](02-requisitos.md) · [Bloco 9 — Qualidade e Processo](09-qualidade.md)

## 0. Como ler este documento

Cada decisão relevante aparece no formato **Decisão → Justificativa → Alternativa descartada**, como numa equipe técnica real. Onde faltou informação no enunciado, adotei uma **premissa** explícita (tabela abaixo) para que os números sejam mensuráveis e a equipe possa contestá-los. As premissas valem para os três blocos.

| ID | Premissa assumida | Por quê |
|---|---|---|
| P1 | Piloto em um campus: ~1.500 estudantes, ~120 mentores, ~10 coordenadores, 2 administradores. Meta futura de dimensionamento: 10.000 usuários cadastrados. | Dá base numérica para desempenho, escalabilidade e custo. Ajustável. |
| P2 | Pico inicial planejado: 150 sessões de usuários simultâneas (início de semestre e semana de provas), distinto de 10.000 cadastros totais. | ~10% da base ativa ao mesmo tempo é uma estimativa conservadora para sistemas acadêmicos. |
| P3 | Mentores são estudantes veteranos, pós-graduandos ou professores, em geral voluntários ou com carga horária reconhecida. | Define a motivação do mentor (ver persona Rafael) e o risco de adesão. |
| P4 | Sessões são presenciais ou em ferramenta externa (Meet, Teams etc.); o mentor informa local ou link no agendamento. | O enunciado exclui videochamada própria. |
| P5 | Equipe hipotética futura de desenvolvimento com 4 profissionais, usando sprints de 2 semanas. O grupo acadêmico que documenta o projeto tem 3 integrantes. | Base para Scrum e para o tamanho das histórias. |
| P6 | Câmbio de referência para custos: R$ 5,7429 por US$ 1 (referência histórica de 05/11/2026 usada no Bloco 7; não é cotação atual). | AWS cobra em dólar; precisamos de uma conversão fixa para o estudo. |

---

## 1.1 Documento de Visão

### Nome e slogan

- **Nome:** MentorIA Acadêmica
- **Slogan:** *Quem já chegou lá ajuda você a chegar.*

> **Alerta de decisão — o nome contém “IA”, mas o sistema não usa inteligência artificial.** O enunciado exclui IA explicitamente. Decisão: manter o nome como marca (já definido pela equipe), mas **registrar na Visão e na tela inicial** que “IA” aqui remete à marca, não a um recurso. Justificativa: evitar expectativa falsa em usuários e avaliadores. Alternativa descartada: renomear o produto, por já estar definido no enunciado.

### Problema que o MentorIA resolve

Hoje, a mentoria acadêmica acontece por grupos de mensagens, planilhas e indicação de colegas. Isso gera quatro dores concretas:

1. **O estudante não sabe quem pode ajudar** em determinada disciplina nem quando essa pessoa está livre.
2. **Conflitos de horário:** o mesmo horário é prometido a duas pessoas, gerando faltas e frustração.
3. **O mentor perde tempo** negociando horários por mensagem e não tem registro do que já fez.
4. **A coordenação não enxerga** quantas mentorias acontecem, em quais disciplinas e com que qualidade; os dados vivem em planilhas manuais.

### Público-alvo

| Segmento | Quem é | Necessidade principal |
|---|---|---|
| Primário | Estudantes de graduação com dificuldade em disciplinas | Achar mentor e horário com poucos cliques |
| Primário | Mentores (veteranos, pós-graduandos, docentes) | Organizar disponibilidade e decidir pedidos |
| Secundário | Coordenadores de curso ou de programa de monitoria | Acompanhar e provar resultados |
| Operacional | Administradores de TI da instituição | Gerenciar usuários e permissões |

### Objetivos (mensuráveis)

| ID | Objetivo | Meta | Como medir |
|---|---|---|---|
| O1 | Facilitar a solicitação | Solicitar mentoria em até 3 minutos após o login | Teste de usabilidade com 5 usuários |
| O2 | Eliminar conflitos | 0 agendamentos ativos duplicados para o mesmo horário | Teste de integração + restrição no banco |
| O3 | Dar agilidade ao mentor | 80% das solicitações respondidas em até 24 h | Relatório de tempo de resposta |
| O4 | Dar visibilidade à coordenação | Relatório mensal gerado em menos de 1 minuto | Cronometragem em teste |
| O5 | Medir qualidade | 70% das sessões concluídas recebem avaliação | Taxa avaliações ÷ sessões concluídas |

### Proposta de valor

- **Para o estudante:** encontrar o mentor certo, ver horários reais e agendar sem negociar por mensagem.
- **Para o mentor:** controlar a própria agenda e ter histórico das sessões, útil para certificados e relatórios de extensão.
- **Para a coordenação:** dados confiáveis sobre mentorias, no lugar de planilhas manuais.
- **Para a instituição:** processo auditável, com controle de acesso por perfil e conformidade com a LGPD.

### Escopo

| Dentro do escopo (versão 1.0) | Fora do escopo (explícito) |
|---|---|
| Cadastro e autenticação de usuários | Pagamentos de qualquer tipo |
| Quatro perfis com permissões (RBAC) | Inteligência artificial (recomendação, chatbot etc.) |
| Cadastro de disciplinas e horários pelo mentor | Videochamada própria da plataforma |
| Busca de mentores e consulta de disponibilidade | Aplicativos móveis nativos (a interface web será responsiva) |
| Solicitação, confirmação, recusa e cancelamento | Integração com sistema acadêmico oficial da instituição |
| Registro de conclusão e avaliação da sessão | Chat entre estudante e mentor |
| Consulta de mentorias e relatórios para coordenação | Mentorias em grupo |
| Gestão de usuários e permissões | Integração com Google Calendar |

**Justificativa das exclusões:** cada item retirado reduz risco e prazo. Pagamento exigiria conformidade financeira; IA exigiria dados e validação que o prazo não comporta; videochamada e app móvel já têm alternativas maduras (Meet/Teams e navegador responsivo).

---

## 1.2 Personas

### Persona 1 — Camila Souza (estudante)

| Campo | Descrição |
|---|---|
| Idade | 20 anos |
| Contexto | 4º semestre de Engenharia de Computação; trabalha meio período e estuda à noite. Reprovou uma vez em Cálculo II. |
| Necessidades | Achar mentor da disciplina específica; ver horários compatíveis com o seu turno; saber logo se o pedido foi aceito. |
| Motivações | Passar em Cálculo II sem atrasar a formatura; ter ajuda sem se sentir exposta diante da turma. |
| Frustrações | Mandar mensagem a vários colegas e não ter resposta; combinar horário e a pessoa esquecer. |
| Impacto nos requisitos | RF010, RF011, RF012, RF015, RF018 |

### Persona 2 — Rafael Lima (mentor)

| Campo | Descrição |
|---|---|
| Idade | 27 anos |
| Contexto | Mestrando em Matemática Aplicada, bolsista; dá mentoria a 6–8 alunos por semestre e precisa comprovar horas de extensão. |
| Necessidades | Publicar horários uma vez só; aceitar ou recusar pedidos rapidamente; registrar o que foi feito em cada sessão. |
| Motivações | Contribuir com a comunidade; acumular horas comprováveis para o currículo e para a bolsa. |
| Frustrações | Alunos que faltam; agenda dispersa em várias conversas; falta de prova do trabalho realizado. |
| Impacto nos requisitos | RF007, RF008, RF009, RF014, RF016 |

### Persona 3 — Helena Albuquerque (coordenadora)

| Campo | Descrição |
|---|---|
| Idade | 45 anos |
| Contexto | Coordenadora do curso; responde à direção pelo programa de apoio ao estudante, hoje controlado em planilhas. |
| Necessidades | Saber quantas mentorias ocorrem, por disciplina e período; identificar disciplinas sem mentor; ver a qualidade pelas avaliações. |
| Motivações | Reduzir evasão e reprovação; apresentar números à direção com segurança. |
| Frustrações | Dados desencontrados; demora para consolidar relatórios; falta de evidências. |
| Impacto nos requisitos | RF019, RF020 |

---

## 1.3 Mapa de stakeholders

Escala: **Alta / Média / Baixa**. A estratégia segue a matriz interesse × influência de Mendelow.

| Stakeholder | Interesse | Influência | Estratégia |
|---|---|---|---|
| Estudantes | Alto: são os usuários finais | Média | Manter informados; coletar feedback a cada sprint |
| Mentores | Alto: dependem da ferramenta para a agenda | Alta: sem mentores não há produto | Gerenciar de perto; oferecer cadastro simples |
| Coordenadores | Alto: usam relatórios para prestar contas | Alta: decidem a adoção | Gerenciar de perto; validar relatórios com eles |
| Direção da instituição | Médio: quer resultados e baixo custo | Alta: aprova o programa | Manter satisfeita; apresentar indicadores |
| Administrador / TI | Alto: opera usuários e acessos | Média | Envolver na definição de perfis |
| Professor avaliador (trabalho acadêmico) | Alto: avalia processo e documentação | Alta | Entregar artefatos completos e rastreáveis |
| Equipe de desenvolvimento (4 pessoas) | Alto | Alta | Reuniões de sprint; documentação clara |
| Encarregado de dados / jurídico (LGPD) | Médio | Média | Consultar na definição de dados pessoais e retenção |
| AWS (fornecedor de infraestrutura) | Baixo | Média: preço e disponibilidade fogem ao nosso controle | Monitorar preços e termos |

---

## 1.4 Estudo de viabilidade

### Viabilidade técnica — **Viável**

| Aspecto | Avaliação | Evidência / justificativa |
|---|---|---|
| Maturidade da pilha | Alta | Node.js 24 LTS, Express 5, PostgreSQL e Bootstrap 5.3 são tecnologias estáveis e muito documentadas. |
| Carga esperada | Baixa | A meta inicial é de 150 usuários simultâneos e base futura de 10.000 cadastros. O desempenho da VM de 2 GB **não está comprovado**: deverá ser verificado por teste de carga com dados representativos antes de implantação. |
| Complexidade de domínio | Média | Regra mais delicada: impedir agendamento ativo duplicado sob concorrência. Será resolvida no banco (índice único parcial) além da validação na aplicação. |
| Sem ORM | Risco controlável | Exige disciplina com SQL; mitigada por consultas parametrizadas e revisão de código. |
| `bcryptjs` | Aceitável | Implementação em JavaScript é mais lenta que a nativa, mas o volume de logins é baixo; custo de hash 12. |
| Habilidades da equipe | A confirmar | Premissa: a equipe domina JavaScript; PostgreSQL e Nginx exigirão aprendizado, tratado em spike na Sprint 0. |

### Viabilidade operacional — **Viável**

- **Processo atual substituído:** planilhas e mensagens, que a plataforma simplifica; baixa resistência esperada.
- **Treinamento:** interface com três telas principais por perfil; um guia de 1 página por perfil basta.
- **Suporte:** a equipe responde por e-mail na fase acadêmica; para uso real, definir responsável de TI.
- **Adoção:** depende da participação dos mentores (ver risco R1).

### Viabilidade econômica — **Viável (custo baixo)**

**Decisão:** desenvolvimento local e duas instâncias separadas no AWS Lightsail: **staging Linux 1 GB** e **produção Linux 2 GB**; em cada instância, Nginx, Node.js/Express e PostgreSQL local. **Justificativa:** separar teste de produção, mantendo implantação simples e custo publicado. **Alternativa descartada:** EC2 + RDS separados por ambiente, mais flexível para alta disponibilidade, porém mais complexo e caro para o piloto. Ambas as instâncias são pontos únicos de falha e **não oferecem garantia de SLA**.

**Fonte de preços verificada em 06/11/2026:** [AWS Lightsail — preços oficiais](https://aws.amazon.com/pt/lightsail/pricing/). Planos Linux com IPv4 público: 1 GB por US$ 7/mês e 2 GB por US$ 12/mês. [Snapshots Lightsail](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-frequently-asked-questions-faq-billing-and-account-management.html): US$ 0,05/GB-mês do espaço armazenado (variável conforme uso e retenção). Valores base, sem impor uma contratação real, dependem da região, impostos e configuração.

| Item | Mensal (US$) | Mensal (R$; premissa P6) | Premissa e observação |
|---|---:|---:|---|
| Staging — Lightsail Linux 1 GB | 7,00 | 40,20 | Homologação e testes. |
| Produção — Lightsail Linux 2 GB | 12,00 | 68,91 | Nginx, API Express e PostgreSQL na mesma VM. |
| Snapshots dos dois ambientes (estimativa de 25 GB-mês) | 1,25 | 7,18 | Armazenamento a US$ 0,05 por GB-mês; projeção não medida. |
| Bucket Lightsail Object Storage 5 GB | 1,00 | 5,74 | Cópias externas de `pg_dump`, dentro da franquia do plano. |
| **Subtotal AWS estimado** | **21,25** | **122,04** | Antes de tributos, excedentes e câmbio real. |
| Tributos brasileiros, projeção de +12,15% | — | ≈ 14,82 | Aproximação para faturamento AWS Serviços Brasil; conferir caso concreto. |
| **Total AWS estimado com tributos** | **21,25 antes de impostos** | **≈ 136,86** | Staging + produção + snapshots + bucket. |
| Domínio `.com.br`, se utilizado | — | ≈ 3,33 | Aproximação de R$ 40/ano / 12; não incluso na AWS. |
| HTTPS Let's Encrypt | 0,00 | 0,00 | Gratuito, configuração sob responsabilidade da equipe. |

**Referência anual:** US$ 255 de infraestrutura antes de tributos (≈ R$ 1.642/ano com os impostos modelados), mais cerca de R$ 40 de domínio; comparar com [Bloco 7 — Custos](07-planejamento.md). **Subtotal verificável das instâncias: US$ 19/mês**. O valor de US$ 21,25 é um cenário de consumo assumido, não cobrança observada. Na região São Paulo, a franquia de transferência é reduzida à metade; a performance de 150 simultâneos e 10 mil cadastros é meta sujeita a teste de carga.

**Operação e recuperação propostas:** snapshots automáticos diários (Lightsail preserva até 7 snapshots automáticos), RPO alvo de 24 h, RTO alvo de 4 h e restauração de teste semestral. O RTO/RPO são metas ainda não comprovadas. A disponibilidade de 99,5% é meta de monitoramento, **não SLA garantido** por uma máquina única.

---

## 1.5 Cinco riscos iniciais

Escala 1 (muito baixa) a 5 (muito alta). **Severidade = probabilidade × impacto.**

| ID | Risco | Prob. | Impacto | Sev. | Mitigação |
|---|---|---|---|---|---|
| R1 | **Baixa adesão de mentores**: sem mentores com horários, a plataforma fica vazia | 3 | 5 | 15 | Convite direto pela coordenação; cadastro de mentor em menos de 5 minutos; comprovante baseado no histórico de sessões, sujeito à aprovação da instituição; piloto com 10 mentores. |
| R2 | **Indisponibilidade da VM única** (ponto único de falha) | 2 | 4 | 8 | Snapshots diários com restauração testada; monitoramento por verificação periódica de saúde; meta de disponibilidade realista (99,5%) documentada em vez de prometer alta disponibilidade. |
| R3 | **Vazamento de dados pessoais ou falha de segurança** (SQL injection sem ORM, senhas, tokens) | 2 | 5 | 10 | Consultas parametrizadas obrigatórias; `bcryptjs` com custo 12; HTTPS; revisão de código focada em segurança; coleta mínima de dados (LGPD); testes de autorização por perfil. |
| R4 | **Estouro de escopo e prazo** com equipe pequena | 4 | 4 | 16 | Priorização MoSCoW; MVP com os Must; congelar o escopo a cada sprint; backlog de “Won’t” visível. |
| R5 | **Agendamentos duplicados por concorrência** (duas solicitações simultâneas ao mesmo horário) | 3 | 4 | 12 | Índice único parcial no PostgreSQL para status ativos; transação com tratamento de erro de violação; teste de integração com requisições paralelas. |

**Leitura do quadro:** os riscos mais severos são R4 (escopo) e R1 (adesão), ambos de gestão e não de tecnologia. Por isso o plano de mitigação prioriza processo (Scrum, MoSCoW) e engajamento, não só código.
