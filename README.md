# Mercado Viva

Marketplace completo em Ruby para compra e venda de produtos, inspirado na experiência de grandes vitrines online. A aplicação oferece catálogo navegável, pesquisa, categorias, página de produto, conta de comprador, favoritos, carrinho, criação de pedido e publicação de anúncios.

## Stack

- Ruby 3.1+
- Sinatra e Puma
- Active Record 7
- SQLite por padrão (também aceita `DATABASE_URL`)
- BCrypt para senhas

## Inicialização

1. Instale as dependências com `bundle install`.
2. Copie `.env.example` para `.env` ou exporte as variáveis necessárias.
3. Para iniciar com a vitrine pronta para avaliação, configure:

   ```sh
   export DASHBOARDIA_DEMO_MODE=true
   export DASHBOARDIA_DEMO_USERNAME=admin
   export DASHBOARDIA_DEMO_EMAIL=admin@mercadoviva.local
   export DASHBOARDIA_DEMO_PASSWORD=mercadoviva-demo
   ```

4. Execute `bundle exec puma -p 9292 config.ru`.
5. Acesse `http://localhost:9292/`.

As migrações são aplicadas automaticamente antes de o servidor aceitar requisições. Em uma base limpa, sem `DASHBOARDIA_DEMO_MODE`, a aplicação sobe normalmente com uma vitrine vazia e permite que usuários criem produtos.

## Dados demonstrativos e acesso administrativo

Quando `DASHBOARDIA_DEMO_MODE=true`, o bootstrap é idempotente e cria:

- a conta administrativa usando **exatamente** `DASHBOARDIA_DEMO_USERNAME`, `DASHBOARDIA_DEMO_EMAIL` e `DASHBOARDIA_DEMO_PASSWORD`;
- duas lojas vendedoras, cinco categorias e seis produtos de exemplo;
- `.dashboardia/demo-access.json` com `{"version":1}`.

Não há comando de seed separado: os dados são criados pela inicialização da aplicação somente no modo demonstrativo.

## Rotas principais

| Rota | Finalidade |
| --- | --- |
| `/` | Página inicial visual do marketplace |
| `/produtos` | Busca, categorias e ordenação de produtos |
| `/produtos/:slug` | Detalhe do produto, carrinho e favoritos |
| `/cadastro` e `/entrar` | Autenticação de compradores e vendedores |
| `/anunciar` | Publicação de novo anúncio autenticado |
| `/carrinho` | Carrinho e criação de pedido |
| `/minha-conta` | Pedidos, favoritos e anúncios da conta |

## Persistência

As migrações em `db/migrate` criam as tabelas de usuários, categorias, produtos, favoritos, pedidos e itens de pedido com chaves estrangeiras, índices de unicidade e verificações de preço/estoque. Os timestamps obrigatórios são gerenciados centralmente pelo Active Record em todos os modelos.

Para usar outro banco compatível com Active Record, informe uma `DATABASE_URL` e inclua o adaptador correspondente no bundle.