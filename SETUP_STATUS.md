# Continuação da publicação — 17/11/2026

## Concluído

- Supabase: projeto `Nosso Plano`, região São Paulo (`sa-east-1`).
- Referência do projeto: `efohanmmrhslvtsmtibm`.
- URL da API: `https://efohanmmrhslvtsmtibm.supabase.co`.
- Organização: a mesma do Chá de casa nova BeF, com banco e armazenamento separados.
- Migrações inicial e de permissões aplicadas; tabelas com RLS, comprovantes em bucket privado e tabelas de mudanças inscritas no Realtime.
- Verificação de segurança do Supabase sem alertas após os ajustes de permissões.

O projeto `Chadecasanovabef` não foi alterado.

## Repositório fornecido pelo usuário

https://github.com/fabinhocrossfire07/nosso-plano

O código ainda precisa ser enviado ao repositório. Este ambiente não está autenticado no GitHub; o link respondeu 404 para o acesso sem login. Isso não confirma que o repositório não existe.

No computador, extraia o ZIP e envie o conteúdo da pasta `nosso-plano` para a raiz do repositório, incluindo `src`, `public`, `supabase`, `package.json`, `package-lock.json`, `index.html`, `vite.config.ts`, `tsconfig.json` e `vercel.json`. Não envie o ZIP como único arquivo do repositório. Não envie `node_modules`, `dist` ou arquivos `.env.local`.

## Pendente

- Autorizar o acesso da conexão Vercel à equipe `fabinhocrossfire07-3555`.
- Importar o repositório GitHub na Vercel.
- Configurar na Vercel `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` (usar somente a chave pública do projeto Nosso Plano).
- Publicar, configurar a URL final em Supabase Auth e testar login, convite, upload e sincronização em dois aparelhos.

O site não foi publicado na Vercel ainda. Os dados financeiros reais não foram migrados do protótipo anterior.
