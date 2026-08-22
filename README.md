# Mercado Livre — marketplace em Ruby on Rails

Aplicação web completa inspirada na experiência de um marketplace: catálogo e busca
de produtos, categorias, ofertas, página de produto, carrinho, cadastro, autenticação
e finalização de compra. A interface inicial está disponível em **`/`**.

## Requisitos

- Ruby 3.1 ou superior
- Bundler

## Inicialização

```bash
bundle install
DASHBOARDIA_DEMO_MODE=true \
DASHBOARDIA_DEMO_USERNAME=admin \
DASHBOARDIA_DEMO_EMAIL=admin@example.test \
DASHBOARDIA_DEMO_PASSWORD='UmaSenhaSegura123!' \
bundle exec rails server
```

O servidor atende em `http://localhost:3000`. Também é possível executar
`ruby bin/setup`, que instala as dependências e prepara o banco, antes do servidor.

Na primeira inicialização a aplicação cria o arquivo SQLite e executa as migrações
pendentes automaticamente. Portanto, um banco limpo pode iniciar diretamente pelo
comando do servidor. O banco fica em `db/development.sqlite3` (ou no caminho
definido por `DATABASE_PATH`).

## Dados demonstrativos e acesso administrativo

Os dados são **opt-in**: só são criados com `DASHBOARDIA_DEMO_MODE=true`. Nesse
modo, a inicialização é idempotente e cria categorias, anúncios, uma conta vendedora
e o administrador usando, obrigatoriamente, os valores de:

- `DASHBOARDIA_DEMO_USERNAME`
- `DASHBOARDIA_DEMO_EMAIL`
- `DASHBOARDIA_DEMO_PASSWORD`

Os valores acima podem então ser usados na rota `/session/new`. Caso uma variável
não seja informada, há valores locais seguros para desenvolvimento. O bootstrap
também cria `.dashboardia/demo-access.json` com `{"version":1}`; esse marcador não
contém credenciais e não é versionado. Não há `seedCommand`, porque a massa é criada
automaticamente no boot quando o modo demo está ativo.

## Persistência

As migrações em `db/migrate` criam usuários, categorias, produtos, pedidos e itens
de pedido, com chaves estrangeiras, índices únicos e campos obrigatórios. Os campos
`created_at` e `updated_at` são preenchidos centralmente pelo mecanismo de
timestamps do Active Record em toda persistência, inclusive nos dados de demonstração.
Validações de modelo protegem e-mail/usuário únicos, senha, preço, estoque, status e
relacionamentos obrigatórios.

## Rotas principais

| Rota | Função |
| --- | --- |
| `/` | Vitrine principal (validação visual) |
| `/products` | Busca e catálogo |
| `/ofertas` | Produtos com desconto |
| `/products/:id` | Detalhe e adição ao carrinho |
| `/cart` | Carrinho e checkout autenticado |
| `/session/new` | Entrada de usuário |
| `/users/new` | Cadastro de comprador |
