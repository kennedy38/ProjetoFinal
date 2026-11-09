# MentorIA Acadêmica — Bloco 2: Requisitos

**Responsável:** Hadson — Pessoa 1, Analista de Requisitos / Product Owner · **Versão:** 1.2 · **Data:** 06/11/2026

Documentos relacionados: [Bloco 1 — Concepção e Escopo](01-concepcao.md) (inclui as premissas P1 a P6) · [Bloco 9 — Qualidade e Processo](09-qualidade.md) · Diagramas: [`diagrama-casos-de-uso.drawio`](../diagramas/editaveis/diagrama-casos-de-uso.drawio), [`diagrama-atividades-agendamento.drawio`](../diagramas/editaveis/diagrama-atividades-agendamento.drawio), [`diagrama-atividades-administrativo.drawio`](../diagramas/editaveis/diagrama-atividades-administrativo.drawio)

## 

## Requisitos Funcionais (RF001 a RF021)

**Legenda MoSCoW:** **M** = Must (indispensável ao MVP), **S** = Should (importante, mas o produto funciona sem), **C** = Could (desejável se sobrar tempo), **W** = Won’t nesta versão.

|ID|Requisito (descrição)|MoSCoW|Justificativa|
|-|-|-|-|
|RF001|O sistema deve permitir que um estudante se cadastre informando nome, e-mail institucional e senha. Mentores e coordenadores são criados pelo administrador (RF004).|M|Porta de entrada do produto. Limitar o autocadastro ao estudante evita que alguém se atribua perfil privilegiado.|
|RF002|O sistema deve autenticar o usuário por e-mail e senha, emitir um JWT e permitir logout.|M|Autenticação é base de toda a segurança e do RBAC.|
|RF003|O sistema deve permitir recuperar a senha por link enviado ao e-mail, válido por 30 minutos e de uso único.|S|Reduz chamados de suporte, mas depende de envio de e-mail; o produto opera sem isso se o administrador redefinir senhas.|
|RF004|O administrador deve criar, editar, desativar e reativar usuários **após aceite comprovado pelo próprio titular nos cadastros administrativos** (RN12). A desativação é lógica (preserva o histórico), não pode atingir o próprio administrador nem o último administrador ativo, e cancela os agendamentos ativos futuros do usuário desativado, liberando os horários (RN07, RN08).|M|Único meio de criar mentores e coordenadores; exclusão lógica mantém a integridade de relatórios; o cancelamento em cascata evita agendamentos “órfãos” com alguém que não acessa mais o sistema.|
|RF005|O administrador deve atribuir e alterar o perfil (Estudante, Mentor, Coordenador, Administrador) de cada usuário, **desde que os compromissos futuros do perfil anterior estejam encerrados e as disponibilidades futuras inativadas (RN11)**, sem poder remover o perfil do último administrador ativo; cada rota da API verifica o perfil, e a mudança vale já na próxima requisição (RN10).|M|O RBAC é requisito explícito do projeto e protege os dados; sem a validade imediata, um perfil revogado continuaria funcionando até o token expirar.|
|RF006|O mentor deve manter um perfil com foto opcional, biografia, formação e formas de contato para a sessão (local ou link).|S|Ajuda o estudante a escolher; o fluxo central funciona só com nome e disciplinas.|
|RF007|O mentor deve cadastrar e remover as disciplinas que está apto a mentorar, a partir de um catálogo de disciplinas.|M|Sem disciplinas não existe busca útil. Catálogo evita grafias diferentes da mesma disciplina.|
|RF008|O mentor deve criar horários de disponibilidade informando data, hora de início e duração (30, 45 ou 60 min), sem sobrepor outro horário seu.|M|Matéria-prima do agendamento; durações fixas simplificam a regra de conflito.|
|RF009|O mentor deve editar ou inativar um horário apenas enquanto não houver agendamento ativo nele. **Se já existir histórico, a data/hora/duração não podem mudar: o mentor inativa o horário e cria outro (RN13).**|S|Dá flexibilidade; a proteção evita quebrar compromissos já assumidos.|
|RF010|O estudante deve buscar mentores por disciplina e nome, com paginação.|M|Resolve a dor principal: descobrir quem pode ajudar.|
|RF011|O estudante deve consultar a lista de horários livres de um mentor, excluindo horários passados e já reservados.|M|Elimina a negociação por mensagem.|
|RF012|O estudante deve solicitar agendamento de um horário livre, informando disciplina e uma observação opcional. O status inicial é PENDENTE.|M|Início do fluxo principal.|
|RF013|O sistema deve impedir mais de um agendamento ativo (PENDENTE ou CONFIRMADO) para o mesmo horário e impedir que o mesmo estudante tenha dois agendamentos ativos sobrepostos.|M|Regra de negócio central citada no enunciado.|
|RF014|O mentor deve confirmar ou recusar solicitações pendentes; a recusa exige uma justificativa. Solicitações sem resposta em 48 h passam a EXPIRADO e liberam o horário.|M|Fecha o fluxo; a expiração evita horários presos para sempre.|
|RF015|O estudante deve cancelar um agendamento PENDENTE ou CONFIRMADO até 2 horas antes do início; o mentor também pode cancelar com justificativa.|S|Reduz faltas silenciosas e libera horários; a regra de 2 h é uma decisão de produto.|
|RF016|Após o horário da sessão, o mentor deve registrar a conclusão (compareceu ou não, duração real e observações). Só então o status passa a CONCLUIDO.|M|Gatilho para avaliação e base dos relatórios.|
|RF017|O estudante deve avaliar uma sessão CONCLUIDA com nota de 1 a 5 e comentário opcional, uma única vez por sessão.|M|Fecha o fluxo principal e mede a qualidade (objetivo O5).|
|RF018|O sistema deve notificar o usuário dentro da plataforma a cada mudança de status do agendamento; envio por e-mail é opcional.|C|Melhora a experiência, mas o usuário consegue consultar o status manualmente.|
|RF019|O coordenador deve consultar mentorias com filtros por período, disciplina, mentor e status.|M|Atende ao ator Coordenador e ao objetivo O4.|
|RF020|O coordenador deve visualizar relatórios agregados (sessões por período e disciplina, média das avaliações, taxas de recusa e cancelamento, tempo médio de resposta) e exportar em CSV.|S|Valor alto para a gestão, mas depende dos dados do MVP já existirem.|
|RF021|O administrador deve manter o catálogo de disciplinas: criar, editar, inativar e reativar. Disciplina inativa não aparece para novas associações nem nas buscas, mas preserva o histórico; não pode ser excluída fisicamente se houver mentor ou agendamento ligado a ela (RN09).|M|**Lacuna encontrada na modelagem dos casos de uso:** o RF007 exige um catálogo, mas nenhum requisito dizia quem o mantém. Sem isso, o mentor não consegue cadastrar disciplinas e a busca (RF010) fica vazia.|

**Resumo da priorização:** 15 Must (71%), 5 Should (24%), 1 Could (5%). Os 15 Must formam o MVP e cobrem o fluxo principal de ponta a ponta. A proporção é alta porque o sistema é pequeno e o fluxo é sequencial: tirar qualquer etapa o inutiliza.

> **Nota:** o professor exige **no mínimo 20 RF**. A entrega tem 21 RF, incluindo a manutenção do catálogo pela administração (RF021), sem necessidade de fundir requisitos.

**Won’t (nesta versão):** pagamentos, inteligência artificial, videochamada própria, aplicativo móvel, chat interno, mentoria em grupo.

### Regras de negócio de suporte

|ID|Regra|
|-|-|
|RN01|Status do agendamento: PENDENTE → CONFIRMADO ou RECUSADO ou CANCELADO ou EXPIRADO; CONFIRMADO → CONCLUIDO ou CANCELADO. Status finais: RECUSADO, CANCELADO, EXPIRADO, CONCLUIDO.|
|RN02|“Ativo” significa PENDENTE ou CONFIRMADO. Um horário só pode ter um agendamento ativo.|
|RN03|Uma solicitação PENDENTE já bloqueia o horário. Justificativa: sem isso, duas pessoas poderiam solicitar o mesmo horário e o mentor teria de recusar uma delas, gerando frustração.|
|RN04|Só se pode avaliar sessão CONCLUIDA com comparecimento registrado.|
|RN05|Um mentor não pode agendar sessão consigo mesmo.|
|RN06|Nenhuma ação altera dados de outro usuário fora das permissões do seu perfil (RBAC).|
|RN07|Ao desativar um usuário, todos os agendamentos ativos futuros dele (PENDENTE ou CONFIRMADO) passam a CANCELADO por decisão do sistema, os horários são liberados e as contrapartes são notificadas (se RF018 estiver habilitado). Agendamentos já concluídos permanecem intactos.|
|RN08|O administrador não pode desativar a si mesmo nem remover o perfil, ou desativar, o último administrador ativo. Justificativa: evita travar a gestão do sistema.|
|RN09|Disciplina com mentor ou agendamento vinculado só pode ser inativada, nunca excluída. Disciplina inativa não aceita novas associações, mas as existentes e o histórico continuam válidos.|
|RN10|A cada requisição autenticada, o sistema confirma no banco que o usuário está ativo e qual é o seu perfil atual. Desativações e mudanças de perfil valem imediatamente, mesmo com token ainda dentro dos 15 minutos de validade.|
|RN11|Antes de trocar o perfil de um mentor, devem ser encerradas suas reservas ativas futuras e inativadas as disponibilidades ativas futuras; para estudante, devem ser encerradas as reservas ativas futuras. Caso contrário, a troca é recusada (409). A desativação segue o fluxo de cancelamento automático da RN07.|
|RN12|No cadastro administrativo, o próprio titular deve ter aceitado a política previamente por canal institucional verificável. Exigem-se data/hora do aceite e referência da evidência, sem que o administrador marque aceite em nome de outra pessoa. Sem prova, a criação é recusada (422); a equipe poderá planejar convite/ativação posteriormente, fora do fluxo atual.|
|RN13|Disponibilidade com qualquer histórico não pode ter mentor, início ou duração alterados; o mentor inativa e cria outro horário. Uma disponibilidade com reserva PENDENTE ou CONFIRMADA não pode ser inativada enquanto a reserva permanecer ativa.|

\---

## 2.2 Requisitos Não Funcionais

Todos os requisitos têm um **critério numérico** e uma **forma de verificação**, para que possam virar teste. Os números partem das premissas P1 e P2 (Bloco 1).

### Desempenho

|ID|Requisito|Critério mensurável|Verificação|
|-|-|-|-|
|RNF001|Tempo de resposta da API|95% das requisições principais da API respondem em até 300 ms com 150 usuários simultâneos e carga de teste documentada, após aquecimento|Teste de carga com k6 ou autocannon|
|RNF002|Busca de mentores e horários|Resposta em até 300 ms (percentil 95), com 10.000 usuários cadastrados, 120 mentores ativos, 10.000 horários e 150 usuários simultâneos no teste|Teste de carga com massa de dados|
|RNF003|Carregamento das páginas|Primeira página útil em até 3 s em conexão 4G; pontuação Lighthouse de desempenho ≥ 80|Lighthouse manual a cada sprint|

### Disponibilidade

|ID|Requisito|Critério mensurável|Verificação|
|-|-|-|-|
|RNF004|Disponibilidade mensal|≥ 99,5% (no máximo ≈ 3 h 40 min de indisponibilidade por mês). **Decisão:** não prometer 99,9%, pois há uma única VM (risco R2).|Monitor externo de saúde a cada 5 min|
|RNF005|Backup e recuperação|Backup diário; perda máxima de dados (RPO) de 24 h; tempo máximo de recuperação (RTO) de 4 h; restauração testada ao menos 1 vez por semestre|Relatório do teste de restauração|

### Segurança

|ID|Requisito|Critério mensurável|Verificação|
|-|-|-|-|
|RNF006|Armazenamento de senhas|Hash com `bcryptjs`, custo ≥ 12; senha mínima de 8 caracteres com letra e número; 0 senhas em texto puro no banco ou nos logs|Teste unitário e inspeção do banco|
|RNF007|Tokens JWT|Expiração de **15 minutos** do token de acesso; segredo aleatório de no mínimo **256 bits** armazenado em variável de ambiente; payload sem dados sensíveis (apenas id e perfil). A cada requisição o sistema consulta o banco para confirmar usuário ativo e perfil atual (RN10): desativação e troca de perfil valem na próxima requisição, e não só no vencimento do token.|Testes de integração: token expirado retorna 401; usuário desativado com token válido retorna 401; perfil alterado muda o acesso na requisição seguinte|
|RNF008|Transporte seguro|100% do tráfego em HTTPS (TLS 1.2 ou superior); HTTP redireciona para HTTPS; cabeçalhos de segurança básicos ativos|Teste SSL Labs com nota ≥ A|
|RNF009|Proteção contra injeção|100% das consultas SQL parametrizadas; `npm audit` com 0 vulnerabilidades altas ou críticas na entrega|Revisão de código e `npm audit`|
|RNF010|Proteção de login|Limite de 5 tentativas falhas por e-mail e IP em 15 min; depois, bloqueio de 15 min|Teste de integração|
|RNF011|Controle de acesso (RBAC)|100% das rotas protegidas verificam o perfil; cada rota tem teste que comprova resposta 403 para perfil não autorizado|Suíte de testes de integração|
|RNF024|Auditoria administrativa|100% das ações administrativas (criar, editar, desativar e reativar usuário; alterar perfil; manter o catálogo) gravam autor, ação, alvo e data/hora, sem senha ou token; retenção de 12 meses; registro só de inserção|Teste de integração e inspeção do log|

### Escalabilidade

|ID|Requisito|Critério mensurável|Verificação|
|-|-|-|-|
|RNF012|Crescimento vertical|Evoluir para o cenário de 750 usuários simultâneos sem mudar as regras de negócio, condicionado a redimensionamento da VM, índices e testes de carga; 10.000 usuários cadastrados como meta de volume de dados|Teste de carga ampliado com 750 usuários concorrentes e 10.000 cadastros; documentar dimensionamento necessário e gargalos|
|RNF013|Listagens limitadas|100% das listagens paginadas, no máximo 50 itens por página; colunas de busca e de chave estrangeira indexadas|Revisão do esquema e teste de integração|
|RNF014|Evolução da arquitetura|Cada módulo do monólito acessa os outros apenas por sua interface pública (serviço), nunca pelo banco de outro módulo; 0 dependências circulares|Verificação com ferramenta de dependências (ex.: `madge`)|

### LGPD (Lei 13.709/2018)

|ID|Requisito|Critério mensurável|Verificação|
|-|-|-|-|
|RNF015|Minimização de dados|Coletar apenas nome, e-mail institucional, perfil e dados da mentoria; 0 campos pessoais sem finalidade documentada|Inventário de dados revisado a cada sprint|
|RNF016|Consentimento e transparência|Política de privacidade exibida no autocadastro; aceite do próprio titular registrado com data e hora para 100% dos usuários. Em cadastros administrativos, origem e referência de evidência institucional, sem aceite por procuração do administrador (RN12).|Teste de integração e inspeção do registro de evidência|
|RNF017|Direitos do titular|Exportação dos dados pessoais e eliminação ou anonimização atendidas em até 15 dias, com procedimento do administrador documentado|Simulação de solicitação|
|RNF018|Privacidade das avaliações|O coordenador vê notas e comentários **sem o nome do estudante**; o mentor vê o comentário sem identificação. **Decisão:** estimula avaliação honesta e reduz exposição.|Teste de integração das respostas da API|
|RNF019|Logs e retenção|Logs técnicos sem senha, token ou texto de avaliação; retenção máxima de 90 dias. A trilha de auditoria administrativa tem retenção própria de 12 meses (RNF024), por finalidade de responsabilização, a validar com o encarregado de dados.|Inspeção de logs|

### Usabilidade

|ID|Requisito|Critério mensurável|Verificação|
|-|-|-|-|
|RNF020|Rapidez da tarefa principal|Um estudante novo solicita uma mentoria em até 3 min e em no máximo 5 cliques após o login|Teste com 5 usuários|
|RNF021|Responsividade|Layout funcional de 360 px a 1920 px de largura, sem rolagem horizontal|Playwright com três tamanhos de tela|
|RNF022|Acessibilidade|Conformidade com WCAG 2.1 nível AA nas telas principais; Lighthouse de acessibilidade ≥ 90; contraste mínimo 4,5:1|Lighthouse e navegação por teclado|
|RNF023|Satisfação|Pontuação SUS (System Usability Scale) ≥ 75 e mensagens de erro em português, sem códigos técnicos|Questionário SUS aplicado ao fim do piloto|

**Decisões integradas:** a referência de 10 mil usuários significa **cadastrados**, e não simultâneos. As metas de p95 ≤ 300 ms com 150 acessos simultâneos dependem de ensaio e não foram medidas. O frontend deve armazenar o JWT somente em memória nesta proposta; ao expirar após 15 minutos, solicita novo login (sem refresh token no MVP).

**Observação:** estes números são metas de projeto. Metas de desempenho e disponibilidade serão revalidadas com os resultados reais do teste de carga na Sprint de estabilização.

\---

## 2.3 Histórias de Usuário (US001 a US016)

**Escala de pontos:** Fibonacci (1, 2, 3, 5, 8, 13), medindo complexidade e incerteza, não horas. Referência: US001 (cadastro simples) = 3 pontos. Critérios de aceite no formato **Dado (Given) / Quando (When) / Então (Then)**.

### US001 — Cadastro de estudante · 3 pontos · RF001

**Como** Camila (estudante), **quero** criar minha conta com e-mail institucional e senha, **para** poder solicitar mentorias.

* **Dado** que informo nome, e-mail institucional válido e senha de 8 caracteres ou mais, **quando** aceito a política de privacidade e envio o formulário, **então** minha conta é criada com perfil Estudante e sou levada ao login.
* **Dado** que o e-mail já está cadastrado, **quando** envio o formulário, **então** vejo a mensagem “E-mail já cadastrado” e nenhuma conta é criada.
* **Dado** que não aceitei a política de privacidade, **quando** tento enviar, **então** o cadastro é bloqueado.

### US002 — Login e logout · 3 pontos · RF002

**Como** Camila (estudante), **quero** entrar e sair do sistema com segurança, **para** proteger meus dados.

* **Dado** credenciais corretas, **quando** faço login, **então** recebo acesso e vejo a tela inicial do meu perfil.
* **Dado** senha incorreta, **quando** tento entrar, **então** vejo “E-mail ou senha inválidos”, sem revelar qual dos dois está errado.
* **Dado** 5 tentativas falhas em 15 minutos, **quando** tento a sexta, **então** o acesso é bloqueado por 15 minutos.

### US003 — Gestão de usuários e perfis · 8 pontos · RF004, RF005

**Como** administrador, **quero** criar usuários, definir seus perfis e desativá-los, **para** controlar quem acessa o sistema.

* **Dado** que sou administrador e o titular já aceitou a política por canal institucional comprovado, **quando** crio um usuário com perfil Mentor informando data do aceite e referência da evidência, **então** ele passa a existir, a ação é registrada na auditoria e ele pode fazer login.
* **Dado** que não existe evidência de aceite do titular, **quando** tento criar a conta administrativamente, **então** a API recusa com 422, sem criar usuário.
* **Dado** um mentor com disponibilidades futuras ativas, **quando** tento trocar seu perfil sem inativá-las e encerrar reservas futuras, **então** a API recusa com 409 (RN11).
* **Dado** um usuário com agendamentos no histórico, **quando** eu o desativo, **então** ele não consegue entrar, mas o histórico permanece nos relatórios.
* **Dado** um mentor com agendamentos ativos futuros, **quando** eu o desativo, **então** esses agendamentos passam a CANCELADO, os horários são liberados e os estudantes afetados são avisados (se habilitado).
* **Dado** que sou o único administrador ativo, **quando** tento desativar a mim mesmo ou remover meu perfil, **então** o sistema recusa.
* **Dado** um usuário desativado cujo token ainda não expirou, **quando** ele faz uma requisição, **então** recebe 401 imediatamente.
* **Dado** que alterei o perfil de um usuário logado, **quando** ele faz a próxima requisição, **então** as permissões novas já valem.
* **Dado** que sou estudante, **quando** tento acessar a gestão de usuários, **então** recebo acesso negado.

*Pontuação 8 (antes 5):* a desativação com cancelamento em cascata, a proteção do último administrador e a revalidação por requisição aumentaram a complexidade.

### US004 — Cadastro de disciplinas do mentor · 3 pontos · RF007

**Como** Rafael (mentor), **quero** indicar as disciplinas que posso mentorar, **para** aparecer nas buscas dos estudantes certos. *(Depende da US016: o catálogo precisa existir.)*

* **Dado** o catálogo de disciplinas, **quando** seleciono “Cálculo II” e salvo, **então** a disciplina aparece no meu perfil.
* **Dado** que já tenho a disciplina, **quando** tento adicioná-la novamente, **então** não há duplicidade.
* **Dado** que removo uma disciplina, **quando** salvo, **então** ela deixa de aparecer em novas buscas, mas agendamentos existentes não são afetados.

### US005 — Cadastro de horários de disponibilidade · 5 pontos · RF008

**Como** Rafael (mentor), **quero** publicar meus horários livres, **para** que estudantes possam reservar sem negociação.

* **Dado** que informo data futura, hora e duração de 60 min, **quando** salvo, **então** o horário fica visível aos estudantes.
* **Dado** que já tenho um horário das 14h às 15h, **quando** tento criar outro das 14h30 às 15h30, **então** recebo erro de sobreposição.
* **Dado** uma data no passado, **quando** tento salvar, **então** o sistema recusa.

### US006 — Busca de mentores · 5 pontos · RF010

**Como** Camila (estudante), **quero** buscar mentores por disciplina e nome, **para** encontrar quem pode me ajudar em Cálculo II.

* **Dado** mentores cadastrados, **quando** busco por “Cálculo II”, **então** vejo apenas mentores ativos dessa disciplina, paginados.
* **Dado** uma busca sem resultados, **quando** a executo, **então** vejo “Nenhum mentor encontrado” com sugestão de limpar filtros.
* **Dado** até 120 mentores, **quando** busco, **então** a resposta chega em até 300 ms p95 (RNF002), nas condições de carga especificadas.

### US007 — Consulta de horários livres · 3 pontos · RF011

**Como** Camila (estudante), **quero** ver os horários livres de um mentor, **para** escolher um que caiba no meu turno.

* **Dado** um mentor com horários, **quando** abro o perfil dele, **então** vejo apenas horários futuros e sem agendamento ativo.
* **Dado** que outro estudante acabou de reservar um horário, **quando** atualizo a lista, **então** esse horário não aparece mais.

### US008 — Solicitar agendamento · 8 pontos · RF012, RF013

**Como** Camila (estudante), **quero** solicitar um horário com um mentor, **para** receber ajuda na disciplina.

* **Dado** um horário livre, **quando** envio a solicitação com disciplina e observação, **então** o agendamento é criado como PENDENTE e o horário deixa de estar livre.
* **Dado** que já tenho agendamento ativo em horário sobreposto com outro mentor, **quando** tento solicitar, **então** recebo erro de conflito.
* **Dado** que dois estudantes enviam a solicitação ao mesmo tempo, **quando** ambas chegam ao servidor, **então** apenas uma é criada e a outra recebe “Horário indisponível”.

*Pontuação 8:* envolve concorrência, transação e índice único no banco; é a história mais arriscada do MVP.

### US009 — Garantia de horário sem duplicidade · 5 pontos · RF013

**Como** Rafael (mentor), **quero** que cada horário meu tenha no máximo um agendamento ativo, **para** não receber dois alunos ao mesmo tempo.

* **Dado** um agendamento PENDENTE ou CONFIRMADO no horário, **quando** outro estudante tenta reservá-lo, **então** a API retorna conflito (409).
* **Dado** que o agendamento foi RECUSADO, CANCELADO ou EXPIRADO, **quando** outro estudante tenta reservá-lo, **então** a reserva é aceita.
* **Dado** tentativa de duplicidade direto no banco, **quando** o INSERT é executado, **então** a restrição do banco o rejeita.

### US010 — Confirmar ou recusar solicitação · 5 pontos · RF014

**Como** Rafael (mentor), **quero** confirmar ou recusar pedidos, **para** controlar minha agenda.

* **Dado** uma solicitação PENDENTE, **quando** confirmo, **então** o status vira CONFIRMADO e o estudante é avisado.
* **Dado** uma solicitação PENDENTE, **quando** recuso sem justificativa, **então** o sistema exige a justificativa antes de salvar.
* **Dado** uma solicitação sem resposta há 48 h, **quando** o prazo vence, **então** o status vira EXPIRADO e o horário volta a ficar livre.

### US011 — Cancelar agendamento · 3 pontos · RF015

**Como** Camila (estudante), **quero** cancelar um agendamento, **para** liberar o horário quando não puder comparecer.

* **Dado** um agendamento ativo que começa em mais de 2 h, **quando** cancelo, **então** o status vira CANCELADO e o horário é liberado.
* **Dado** um agendamento que começa em menos de 2 h, **quando** tento cancelar, **então** o sistema recusa e orienta a contatar o mentor.

### US012 — Registrar conclusão da sessão · 5 pontos · RF016

**Como** Rafael (mentor), **quero** registrar que a sessão aconteceu, **para** manter histórico e comprovar minhas horas.

* **Dado** um agendamento CONFIRMADO cujo horário já passou, **quando** registro comparecimento, duração e observações, **então** o status vira CONCLUIDO.
* **Dado** um agendamento cujo horário ainda não começou, **quando** tento concluir, **então** o sistema recusa.
* **Dado** que o estudante faltou, **quando** registro a ausência, **então** a sessão fica concluída sem direito à avaliação.

### US013 — Avaliar mentoria · 3 pontos · RF017

**Como** Camila (estudante), **quero** avaliar a sessão concluída, **para** dar retorno sobre a qualidade da ajuda.

* **Dado** uma sessão CONCLUIDA com comparecimento, **quando** envio nota de 1 a 5 e comentário opcional, **então** a avaliação é salva.
* **Dado** que já avaliei a sessão, **quando** tento avaliar de novo, **então** o sistema recusa.
* **Dado** uma sessão não concluída, **quando** tento avaliar, **então** a opção não está disponível.

### US014 — Acompanhar mentorias · 5 pontos · RF019

**Como** Helena (coordenadora), **quero** consultar as mentorias com filtros, **para** acompanhar o programa.

* **Dado** mentorias cadastradas, **quando** filtro por período e disciplina, **então** vejo apenas as correspondentes, paginadas.
* **Dado** que sou estudante, **quando** tento acessar essa consulta, **então** recebo acesso negado.
* **Dado** a listagem, **quando** vejo as avaliações, **então** o nome do estudante não aparece (RNF018).

### US015 — Relatórios e exportação · 8 pontos · RF020

**Como** Helena (coordenadora), **quero** ver indicadores agregados e exportar em CSV, **para** prestar contas à direção.

* **Dado** um período escolhido, **quando** gero o relatório, **então** vejo total de sessões, média das notas, taxa de recusa e cancelamento e tempo médio de resposta, em até 1 minuto.
* **Dado** o relatório na tela, **quando** clico em exportar, **então** recebo um CSV com os mesmos números.
* **Dado** um período sem dados, **quando** gero o relatório, **então** vejo “Sem dados no período”, e não valores zerados enganosos.

### US016 — Gestão do catálogo de disciplinas · 3 pontos · RF021

**Como** administrador, **quero** manter o catálogo de disciplinas, **para** que os mentores escolham nomes padronizados.

* **Dado** que informo nome e código novos, **quando** salvo, **então** a disciplina entra no catálogo e fica disponível para os mentores.
* **Dado** uma disciplina com mentor ou agendamento vinculado, **quando** tento excluí-la, **então** o sistema só permite inativá-la.
* **Dado** uma disciplina inativa, **quando** um mentor abre a lista para cadastrar disciplinas, **então** ela não aparece, mas continua visível nos agendamentos antigos.

### Resumo do backlog

|História|Pontos|RF atendidos|Prioridade|
|-|-|-|-|
|US001|3|RF001|Must|
|US002|3|RF002|Must|
|US003|8|RF004, RF005|Must|
|US004|3|RF007|Must|
|US005|5|RF008|Must|
|US006|5|RF010|Must|
|US007|3|RF011|Must|
|US008|8|RF012, RF013|Must|
|US009|5|RF013|Must|
|US010|5|RF014|Must|
|US011|3|RF015|Should|
|US012|5|RF016|Must|
|US013|3|RF017|Must|
|US014|5|RF019|Must|
|US015|8|RF020|Should|
|US016|3|RF021|Must|
|**Total**|**75**|||

**Leitura:** com velocidade estimada de 20 a 25 pontos por sprint (equipe de 4, sprint de 2 semanas, P5), os 75 pontos caberiam em 4 sprints, mas o plano da seção 9.7 usa 5, deixando a última leve para estabilização. RF003, RF006, RF009 e RF018 (Should e Could) ainda não têm história; serão refinadas após o MVP, e essa lacuna é intencional, para não inflar o backlog inicial.

