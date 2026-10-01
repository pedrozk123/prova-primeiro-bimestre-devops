# Relatório do Processo — Prova do Primeiro Bimestre (DevOps)

**Aluno:** Pedro Otávio Ferreira Alves
**RA:** 6325073
**Ferramenta de IA utilizada:** Claude (Anthropic), via chat

## Questão 1 — A Jornada Completa


Comecei pelo Git, porque todo o resto dependia de um histórico organizado desde o início. Criei o repositório `prova-primeiro-bimestre-devops`, o `README.md` e o `.gitignore` (com `.env`, `.terraform/`, `*.tfstate` e `*.pem`) antes de escrever o código. O desenvolvimento foi feito na branch `feature/api-reservas`, que depois integrei na `main` com merge, e usei Conventional Commits (`feat:`, `chore:`, `docs:`, `fix:`) para registrar cada passo. Isso corresponde à Aula 01.

Depois construí a API de Reservas em Node.js e Express, com o CRUD completo gravando no PostgreSQL por consultas parametrizadas, e containerizei com um Dockerfile multi-stage, executando como usuário não-root, mais um `.dockerignore`. Fiz isso antes do Compose e da nuvem porque cada camada depende da anterior: não faz sentido orquestrar ou provisionar algo que ainda não roda sozinho (Aula 01).

Depois usei o Docker Compose para subir a API e o PostgreSQL com um único comando. Configurei volume nomeado para persistir os dados, uma rede bridge própria, healthcheck no banco e `depends_on` com condição, para a API só iniciar depois que o banco estiver saudável (Aula 02). As senhas ficaram fora do Git: o `.env` está no `.gitignore` e o `.env.example` documenta as variáveis necessárias. Testei o CRUD com curl e a persistência derrubando e subindo os containers, e os dados continuaram no volume.

Só então passei para a AWS, com Terraform (Aulas 03 a 06). Escrevi módulos separados para VPC, Security Groups, EC2 e RDS, compostos no `main.tf` da raiz, onde a saída de um módulo alimenta a entrada do outro: o `vpc_id` vai para o módulo de Security Groups, os IDs dos SGs vão para o RDS e a EC2, e o endpoint do RDS vai para a EC2. Configurei também o remote state, com um bucket S3 versionado e criptografado e uma tabela DynamoDB para o lock, criados antes do projeto principal porque o backend precisa existir antes de ser usado.

Deixei a nuvem por último porque é a etapa mais lenta e mais cara de errar. Com a aplicação já validada localmente, os problemas que apareceram na AWS eram de infraestrutura e de permissões do Learner Lab, e não de código da API. Validei a infraestrutura com `terraform validate` e `terraform plan`, sem rodar o `apply` do ambiente completo.

A Aula 07 atravessou todo o processo: usei a IA como copiloto em todas as etapas, mas revisei o que ela gerou, e os pontos em que precisei corrigir ou entender melhor o que foi sugerido estão detalhados nas questões seguintes.

## Questão 2 — O Processo com IA como Copiloto

Usei o Claude (Anthropic), em conversa de chat, como copiloto durante todo o projeto. Não usei o Kiro nem o fluxo de Spec-Driven. Meu fluxo foi mais conversacional: colei o enunciado completo, pedi que a IA atuasse como copiloto e fomos etapa por etapa, na ordem Git, API, Docker, Compose e Terraform. Também pedi que ela me avisasse a cada momento de fazer commit, o que ajudou a manter um histórico limpo, com mensagens no padrão Conventional Commits. 

A IA foi boa em quatro coisas: dividir o enunciado em etapas e prazos, gerar o código inicial (API, Dockerfile, docker-compose e módulos Terraform), explicar cada conceito de forma didática (por exemplo, para que serve o `.env.example`, o volume nomeado e o remote state) e sugerir comandos para validar cada passo. Isso economizou bastante tempo, principalmente na escrita dos módulos Terraform.

Por outro lado, precisei corrigir e entender vários erros que vieram do código ou das instruções geradas:

1. **Provider Terraform.** O backend foi gerado com `version = "~> 5.0"`, e o `apply` falhou com `AccessDenied` na leitura da configuração de Object Lock do bucket. A primeira correção sugerida (travar o provider em 5.31.0) não resolveu, porque o bloqueio vinha de uma Service Control Policy do Learner Lab que proíbe essa leitura em qualquer versão. A solução real foi criar o bucket por AWS CLI, dentro de um `terraform_data` com `local-exec`, mantendo o Terraform apenas para a tabela DynamoDB. Aprendi que a IA não conhece as restrições do ambiente do Lab e que uma sugestão pode parecer plausível e estar errada.
2. **Passo a passo incompleto.** A IA descreveu o `apply` do backend como se eu já tivesse criado os arquivos, mas eles nunca tinham sido criados. Percebi isso ao ver que a pasta `infra/backend` não existia.
3. **Formato de instruções.** Colei no arquivo `.tf` os comandos `cat > main.tf << 'EOF'` que eram para o terminal, e o Terraform apontou erro de sintaxe. Entendi a diferença entre comando de terminal e conteúdo de arquivo.
4. **Git.** O `git push` foi rejeitado porque o GitHub tinha um merge de um Pull Request que não existia localmente, e o `git status` mostrou que o `Dockerfile` não tinha sido commitado, porque o nome do arquivo estava em letras minúsculas na hora do `git add`. A IA ajudou a diagnosticar, mas foi a leitura do `git status` que revelou o problema.


## Questão 3 — Infraestrutura, Segurança e o Learner Lab



A arquitetura que defini no Terraform tem uma VPC (10.0.0.0/16) com quatro subnets em duas zonas de disponibilidade: duas públicas e duas privadas. As públicas têm uma rota 0.0.0.0/0 para um Internet Gateway, e as privadas ficam numa tabela de rotas sem nenhuma saída para a internet. A EC2 t2.micro, que roda a API na porta 3000, fica numa subnet pública, e o RDS PostgreSQL (db.t3.micro) fica nas subnets privadas, por meio de um DB subnet group. [Se quiser, inclua aqui um diagrama simples ou um print do `terraform plan`.]

A EC2 fica na subnet pública porque precisa receber requisições vindas da internet (a API) e, no primeiro boot, baixar o Docker e clonar o repositório. O RDS fica na privada porque ninguém de fora precisa falar diretamente com o banco: ele só deve ser acessado pela aplicação. Por isso, além de estar numa subnet sem rota para fora, ele tem `publicly_accessible = false` e `storage_encrypted = true`. Reduzir a superfície de ataque é o motivo central dessa separação, e é por isso que o banco não deve ter IP público.

A segurança em camadas aparece nos Security Groups. O SG da EC2 libera a porta 22 (SSH) e a 3000 (API). O SG do RDS libera a porta 5432 somente a partir do SG da EC2, usando `security_groups` em vez de um intervalo de IPs, e não por `cidr_blocks`. Assim, mesmo que alguém descubra o endpoint do banco, só a instância da API consegue conectar. Reconheço uma limitação: deixei o SSH aberto para 0.0.0.0/0 por praticidade, e o ideal seria restringir ao meu IP com `/32` (a variável `ssh_allowed_cidr` já permite isso). Outra limitação é que a senha do banco é passada à instância pelo `user_data`, o que a deixa visível nos metadados da instância e no state; em um ambiente real eu usaria o Secrets Manager ou o SSM Parameter Store.

Quanto ao IAM, o Learner Lab não permite criar users, groups ou roles, então não criei nenhum recurso de IAM. No módulo da EC2 anexei o instance profile `LabInstanceProfile`, que já existe no Lab, e a role `LabRole` é a que as credenciais do Lab assumem. Isso difere do que é ensinado em um ambiente real, onde criaríamos uma role com permissões mínimas para cada função.

O Learner Lab exigiu vários ajustes em relação ao que foi ensinado:

1. **Credenciais temporárias.** Elas incluem um Session Token e expiram, então precisei copiá-las de novo de "AWS Details → AWS CLI" várias vezes, colando no `~/.aws/credentials`, fora do repositório. O erro `ExpiredToken` foi frequente.
2. **Restrição de política (SCP).** O recurso `aws_s3_bucket` do Terraform falhou com `AccessDenied` ao ler a configuração de Object Lock, porque uma Service Control Policy da organização bloqueia essa leitura. Travar o provider na versão 5.31.0 não resolveu. Contornei criando o bucket do remote state pela AWS CLI, dentro de um `terraform_data` com `local-exec`, e configurando por CLI o versionamento, a criptografia AES256 e o bloqueio de acesso público. A tabela DynamoDB de lock continuou sendo criada normalmente pelo Terraform.
3. **Região e versão.** Usei sempre `us-east-1` e fixei o provider AWS em 5.31.0 em todo o projeto.
4. **Custo.** Não criei NAT Gateway, porque o RDS não precisa de saída para a internet e o NAT consome muito do crédito do Lab.


## Questão 4 — Validação e Responsabilidade


Antes de rodar qualquer `terraform apply` em código gerado por IA, apliquei um checklist. Primeiro, li o código e tentei explicar o que cada bloco faz, especialmente os pontos de segurança: quem acessa o banco, quais portas estão abertas e onde ficam as senhas. Segundo, rodei `terraform validate` para checar a sintaxe e `terraform plan` para ver exatamente quais recursos seriam criados, e conferi se o número e o tipo de recursos faziam sentido. Terceiro, usei `git status` antes de cada commit para garantir que nada sensível entrasse no repositório, que é público: `.env`, `.terraform/`, arquivos `tfstate` e credenciais da AWS. As credenciais ficam em `~/.aws/credentials`, fora da pasta do projeto. Por fim, fixei a versão do provider AWS, para o resultado não mudar conforme a versão mais recente.

Essa validação pegou problemas reais. O `git status` mostrou que o `app/Dockerfile` nunca tinha sido commitado, o que quebraria o build de quem clonasse o projeto e também o `user_data` da EC2, que faz `git clone` e constrói a imagem. O `apply` do backend falhou por causa da política da organização do Learner Lab, e só entendi o motivo lendo a mensagem de erro completa, que citava a Service Control Policy. 

Para verificar se a infraestrutura estava correta e segura, conferi no código os requisitos do enunciado: RDS com `publicly_accessible = false`, `storage_encrypted = true`, subnets privadas, e Security Group aceitando a porta 5432 apenas a partir do SG da EC2, além de tags em todos os recursos e uso do `LabInstanceProfile` sem criar IAM.  Apliquei o `apply` apenas no backend (S3 e DynamoDB), e conferi os outputs depois.

Se eu tivesse aceitado o código da IA sem revisar, vários problemas teriam passado despercebidos. O backend teria falhado sem eu entender o porquê. O Dockerfile ficaria fora do repositório. E, o mais grave, haveria riscos de segurança: o SSH aberto para o mundo inteiro (0.0.0.0/0) e a senha do banco passada pelo `user_data`, que fica visível nos metadados da instância e no state. Também havia o risco de credenciais da AWS serem commitadas num repositório público, onde robôs as encontram em minutos. Em uma conta real, isso poderia significar vazamento de dados e custo inesperado, e é por isso que cada decisão precisa ser entendida e não apenas copiada.

A evolução Git → Docker → Terraform → Módulos me preparou para usar IA com responsabilidade porque cada etapa criou uma rede de segurança para a seguinte. O Git me deixou desfazer erros e ver exatamente o que mudou em cada commit. O Docker e o Compose me deram um jeito de testar a aplicação localmente antes da nuvem, então os erros de código ficaram separados dos de infraestrutura. O Terraform, com `plan` antes do `apply`, me deu uma pré-visualização do que a IA gerou, e os módulos me obrigaram a entender as entradas e saídas de cada peça, em vez de aceitar um bloco único e opaco. Em resumo, aprendi a tratar a IA como um colega rápido que pode errar: ela acelera, mas a validação e a responsabilidade pelo resultado continuam sendo minhas.


=====================================================

# Registro de Prompts — Uso de IA (Claude)

**Ferramenta:** Claude (Anthropic), em conversa de chat. Não usei Kiro nem Spec-Driven.
**Como usei:** colei o enunciado completo e pedi que a IA atuasse como copiloto, avançando uma etapa por vez (Git → API → Docker → Compose → Terraform → relatório). Pedi também que ela me avisasse a cada momento de fazer commit.

## 1. Planejamento

| Prompt (resumo) | O que a IA gerou | Validação / ajuste |
|---|---|---|
| Colei o enunciado inteiro e perguntei se podia mandar tudo de uma vez | Plano em 8 etapas, pesos de cada parte e alertas das regras (um único PR, aberto só no dia da prova) | Conferi o plano contra os critérios de avaliação do enunciado |
| "me avise sempre que for hora de fazer um commit" | Mensagens de commit prontas em Conventional Commits a cada etapa | Usei as mensagens e confirmei o resultado com `git log` |
| "não tenho nada disso [módulos da Aula 06], vamos ter que fazer do zero" | Decisão de montar todos os módulos do zero, com explicação de cada um | — |

## 2. Git e aplicação

| Prompt (resumo) | O que a IA gerou | Validação / ajuste |
|---|---|---|
| "me passe os comandos para criar a pasta e o repo do github" | Ordem: `git init` local, repo vazio e público no GitHub, `remote add` e `push` | Segui a ordem e o push funcionou |
| "meu terminal do git travou" | Diagnóstico das causas comuns (editor vim, paginador, login) | Era o editor de mensagem de merge |
| Colei meu `package.json` | Correção do `main` e do script `start` | Apliquei e conferi com a API |
| Colei o erro de `git push` rejeitado | Explicação: o GitHub tinha um merge de PR que eu não tinha localmente. Orientou `git pull --no-rebase` e não usar `--force` | Resolvi o merge e o push passou |
| "abriu no vscode um merge_msg" | Instrução: salvar e fechar a aba | Resolvido |
| Colei a saída do `git status` com `app/dockerfile` | Pediu para confirmar o nome do arquivo e descobriu que o Dockerfile nunca tinha sido commitado | Corrigi o nome e fiz o commit que faltava |

## 3. Docker e Compose

| Prompt (resumo) | O que a IA gerou | Validação / ajuste |
|---|---|---|
| "me explica melhor o `.env.example`" | Explicação da diferença entre `.env` (fora do Git) e `.env.example` (versionado) | Conferi no `git status` que o `.env` não aparece |
| "eu crio o `.env.example` na raiz?" | Estrutura de pastas e comando para criar | Criei na raiz |
| "como eu faço o teste de persistência?" | Passo a passo com `down` (sem `-v`) e `up` | [Escreva se executou e o resultado] |

## 4. Terraform e AWS

| Prompt (resumo) | O que a IA gerou | Validação / ajuste |
|---|---|---|
| "comando `aws` não encontrado" | Instalação via winget e reabertura do terminal | Funcionou |
| "posso deixar as credenciais no mesmo arquivo do repo?" | Resposta: não, ficam em `~/.aws/credentials`, fora do projeto | Segui a orientação |
| "eu não dei nenhum `terraform apply`" / "não tem pasta backend" | Percebi que os arquivos do backend nunca tinham sido criados e os recriei | Criei os arquivos e conferi com `ls` |
| Colei o erro do `terraform init` (linhas de `cat`/`EOF` dentro do `.tf`) | Explicação: eram comandos de terminal colados dentro do arquivo | Removi as linhas e o `validate` passou |
| Colei o erro de `AccessDenied` no Object Lock (duas vezes) | 1ª sugestão: travar o provider em 5.31.0 (**não resolveu**). 2ª: criar o bucket por AWS CLI num `terraform_data` com `local-exec` | A 2ª solução funcionou; entendi que o bloqueio vem da política da organização do Lab |
| "como eu apago o bucket?" | Comandos `aws s3 rb --force` e limpeza do state local | Executei a limpeza |
| "como eu vejo os outputs?" | `terraform output` | Confirmei o `bucket_name` e o `lock_table` |
| Pedi módulos `ec2` e `rds` e o projeto principal | Código dos módulos, `providers.tf`, `main.tf` e `outputs.tf` | Revisei os pontos de segurança; `validate` e `plan` [confirme o resultado] |
| "não vou fazer [o apply do ambiente completo]" | Ajuste do checklist para só marcar o que foi executado | Mantive o checklist fiel |

## 5. Relatório

| Prompt (resumo) | O que a IA gerou | Validação / ajuste |
|---|---|---|
| "me ajude a escrever a questão 1, 2, 3 e 4" | Rascunhos com trechos marcados para eu completar | Reescrevi com minhas palavras e removi o que não fiz |

## O que a IA errou ou deixou passar

1. Sugeriu `version = "~> 5.0"` no provider, e a correção seguinte (travar em 5.31.0) também não resolveu a restrição do Lab.
2. Descreveu o `apply` do backend como se os arquivos já existissem, quando nunca tinham sido criados.
3. Misturou comandos de terminal com conteúdo de arquivo, o que gerou o erro de sintaxe no Terraform.
4. Deixou o SSH aberto para `0.0.0.0/0` e a senha do banco no `user_data`, que são fraquezas de segurança que registrei no relatório.