# Nosso Plano — Fabio & Bárbara

**Situação em 17/11/2026:** o projeto Supabase Nosso Plano já foi criado e as duas migrações foram aplicadas. Não execute novamente o SQL inicial nesse projeto. Leia SETUP_STATUS.md para continuar a publicação.


Site financeiro para iPhone e computador, com contas individuais e um espaço financeiro compartilhado. Código React + TypeScript + Vite, pronto para GitHub e Vercel. Supabase fornece autenticação, PostgreSQL, Realtime e armazenamento privado.

## O que está implementado

- Login por e-mail/senha, confirmação de e-mail e recuperação de senha.
- Criação do espaço por uma pessoa e convite privado para o e-mail da outra. Limite de duas pessoas por espaço; convite de uso único, válido por 7 dias. Criar novo convite invalida os anteriores.
- Identificação de responsabilidade (Fabio, Bárbara ou Conjunto) separada de quem pagou/recebeu.
- Receitas, despesas, transferências, vencimentos, confirmação e filtros mensais.
- Orçamento por categoria e responsabilidade, metas e referência de reserva ajustável, dívidas e orientações calculadas sobre os dados cadastrados.
- Envio de PDFs/JPGs/PNGs de até 10 MB, arquivos privados e identificação de arquivos repetidos por SHA-256. Download autenticado dos originais.
- Importação CSV com conferência e identificação indicativa de duplicados; exportação CSV e JSON dos registros.
- Sincronização por Supabase Realtime, indicador de conexão e atualização ao voltar ao app. Sem conexão, os dados já carregados podem continuar visíveis, mas novos registros não são salvos.
- Proteção de edição por versão: se outro aparelho modificar o registro, a edição antiga é recusada, evitando sobrescrita silenciosa.
- Validação no banco, permissões RLS, isolamento entre famílias e remoção lógica dos registros.
- Adição do site à Tela de Início do iPhone. O site precisa de conexão; não há modo de gravação offline.

**A separação Fabio/Bárbara/Casa é uma visão do orçamento: todos os membros do espaço têm acesso aos registros individuais e conjuntos. Não representa finanças privadas entre o casal.**

## Publicação com GitHub + Vercel + Supabase

### 1. Supabase

1. Crie um projeto dedicado.
2. No SQL Editor, execute uma vez o arquivo `supabase/migrations/202611170001_household_finance.sql`. Ele cria as tabelas, funções, permissões, bucket privado `receipts` e habilita a publicação Realtime das tabelas usadas pelo app.
3. Em Authentication, habilite o provedor Email com confirmação de e-mail. Para uso contínuo, configure o SMTP do projeto conforme a documentação Supabase; a entrega de e-mails precisa ser validada no seu projeto.
4. Copie a URL do projeto e a chave **publishable** (ou a chave anon legada). Essas são as únicas duas configurações usadas no front-end.
5. Depois de ter a URL Vercel, configure a Site URL e as URLs de redirecionamento permitidas no Supabase Auth. Use a origem HTTPS exata do site. Adicione também `http://localhost:5173` apenas se for testar localmente.

Não use chave secret/service_role no navegador, no repositório ou em variáveis VITE_. As permissões são aplicadas pelo banco sobre a identidade de cada sessão.

### 2. GitHub

1. Crie um repositório privado para o projeto.
2. Envie os arquivos deste pacote, incluindo package-lock.json, supabase e testes. Não envie node_modules, dist ou arquivos .env.
3. O fluxo de CI em `.github/workflows/ci.yml` verifica o código e as políticas do banco.

### 3. Vercel

1. Importe o repositório GitHub e selecione Vite. O arquivo `vercel.json` já define o build e a pasta de saída.
2. Configure `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` antes do build.
3. Publique. Quando mudar essas variáveis, faça novo deploy: o Vite incorpora valores no build.
4. Atualize as URLs no Supabase Auth conforme o passo 1.
5. Cada alteração enviada à branch de produção no GitHub poderá disparar o deploy configurado na Vercel.

### 4. Primeiro acesso de vocês

1. Fabio cria a conta e confirma o e-mail. Depois entra e cria o espaço, escolhendo seu nome.
2. Em Configurações, informa o e-mail da Bárbara, gera e copia o convite.
3. Fabio envia esse link à Bárbara pelo canal que preferirem. O app não envia mensagens ou e-mails de convite automaticamente.
4. Bárbara abre o link, cria/confirma a conta com o e-mail convidado e aceita o convite. Se a confirmação do e-mail abrir em outro navegador, basta abrir novamente o link do convite após entrar.
5. Cada um usa o próprio login no iPhone ou computador. No Safari: Compartilhar → Adicionar à Tela de Início.

## Desenvolvimento

Requer Node.js 22.13 ou superior.

```sh
npm ci
cp .env.example .env.local
npm run dev
```

Preencha `.env.local` apenas com a URL e chave pública do projeto. Sem configuração, o site mostra uma tela explicando o que falta, sem inventar dados.

```sh
npm test
npm run build
```

Os testes executam a migração em PostgreSQL embutido (PGlite), com os schemas Auth e Storage simulados, para verificar RLS, vínculo por convite, isolamento de outro usuário, validação monetária, arquivos privados e conflitos de versão. A integração efetiva de login, envio de e-mail, Storage e Realtime precisa ser conferida no projeto Supabase e em dois aparelhos depois da configuração. Não foram usados dados financeiros reais nos testes.

## Conferência após publicar

- Entre com duas contas em navegadores diferentes, aceite o convite e crie/edite um lançamento. Confira sua atualização no outro aparelho.
- Confira que um terceiro usuário não vê os registros ou comprovantes do casal.
- Edite o mesmo registro nos dois aparelhos e confirme que uma versão antiga é recusada.
- Envie e baixe um PDF/imagem; confira que o bucket continua privado.
- Saia da conta e confira que o painel financeiro não aparece sem login.
- Faça backup periódico dos dados e arquivos pelo recurso disponível no seu projeto Supabase. O JSON exportado pelo app contém metadados, não os arquivos binários dos comprovantes.

## Regras dos cálculos

Valores monetários são guardados em centavos inteiros. O saldo do mês é receitas confirmadas menos despesas pagas; a previsão subtrai também despesas pendentes. Transferências entre contas não entram em receitas/despesas. Não é uma consulta ao saldo bancário e exige lançamentos completos.

As metas são saldos informados manualmente e não movimentam dinheiro. A referência da reserva multiplica as despesas essenciais do mês filtrado pelo número de meses configurado. Mês incompleto produz referência incompleta. O cadastro de dívidas não cria parcelas nos lançamentos; a lista prioriza a taxa mensal informada, sem substituir a conferência do CET e das condições do contrato.

Lance salário líquido para controlar o dinheiro disponível. Evite descontar novamente consignados já retidos no holerite. Em cartões, registre as compras ou a fatura consolidada de forma consistente para não contar duas vezes. A identificação de duplicados em CSV é indicativa; a conferência continua necessária.

Referências educativas: [Banco Central](https://www.bcb.gov.br/cidadaniafinanceira/lidando-imprevistos) e [CVM](https://www.gov.br/investidor/pt-br/penso-logo-invisto/planejamento-e-gestao-de-reservas-financeiras).

## Próximas integrações — ainda não implementadas

- Leitura automática/OCR de holerites, extratos, fotos e PDFs. Atualmente os originais são guardados e os valores são preenchidos manualmente, ou importados por CSV no formato do modelo.
- Atalho iOS para enviar um comprovante pelo menu Compartilhar do banco. Exige um endpoint autenticado e um Atalho distribuído/configurado nos dois iPhones; o manifesto do site não adiciona essa função sozinho.
- Conexão automática a bancos, notificações push/WhatsApp e reconciliação automática de lançamentos manuais com extratos.
- Projeções recorrentes, geração automática de parcelas, limites/faturas de cartão e saldos iniciais por conta.
- Histórico visual e restauração dos registros removidos logicamente. Os dados removidos continuam no banco; arquivos de comprovantes removidos são apagados do bucket.

## Sobre a versão anterior

Este projeto é separado do site privado inicial publicado no ChatGPT. Ele não foi substituído. Nenhum dado cadastrado naquela versão foi transferido automaticamente para esta base. Se houver dados, exporte e planeje a migração antes de usar a nova versão como controle principal.
