# Vendah (RUBY-api)

Marketplace de produtos com catálogo pesquisável, filtros, carrinho persistido no
navegador, autenticação de compradores e criação de pedidos. A interface em `/`
consome a API Ruby; portanto o preview exercita a aplicação e o banco, em vez de
ser apenas uma página estática.

## Requisitos

- Ruby 3.0 ou superior
- Bundler
- SQLite 3 (a gem `sqlite3` fornece o driver)

## Inicialização local

```bash
bundle install
cp .env.example .env # opcional
set -a; . ./.env; set +a
bundle exec rackup -p 4567
```

Acesse <http://localhost:4567/>. O processo cria o diretório do banco, executa
as migrações pendentes e responde `/api/health`. Para apenas migrar:

```bash
bundle exec ruby bin/migrate
```

`bin/start` é um atalho equivalente ao servidor usado pelo preview. Caso o
ambiente não permita executar arquivos diretamente, use `bundle exec ruby
bin/start`.

## Massa de demonstração

O bootstrap de demonstração é deliberadamente opt-in:

```bash
DASHBOARDIA_DEMO_MODE=true \
DASHBOARDIA_DEMO_USERNAME=admin \
DASHBOARDIA_DEMO_EMAIL=admin@vendah.local \
DASHBOARDIA_DEMO_PASSWORD=admin123 \
bundle exec rackup -p 4567
```

Quando ativado, o bootstrap idempotente cria o acesso administrativo e oito
produtos com categorias. O arquivo `.dashboardia/demo-access.json` é criado
localmente com `version: 1`, usuário e e-mail (a senha nunca é gravada nele).
Sem `DASHBOARDIA_DEMO_MODE=true`, nenhuma massa ou conta é criada
automaticamente.

## API principal

| Método | Rota | Uso |
| --- | --- | --- |
| GET | `/api/health` | saúde da aplicação e conexão |
| GET | `/api/categories` | categorias e quantidade de produtos |
| GET | `/api/products?q=iphone&sort=price_asc` | catálogo, busca e filtros |
| GET | `/api/products/:id` | detalhe por id ou slug |
| POST | `/api/auth/login` | login por usuário/e-mail |
| GET/POST | `/api/auth/me`, `/api/auth/logout` | sessão |
| POST | `/api/orders` | cria pedido e reserva estoque |
| POST | `/api/products` | publica produto (admin) |

## Arquitetura e dados

`config.ru` chama o boot antes de iniciar o Rack: a conexão SQLite é criada,
`db/migrations/001_initial.sql` é aplicado uma vez e, em modo demo, os seeds
idempotentes são carregados. A aplicação usa preços em centavos e transações
para pedidos. Chaves estrangeiras, checks, unicidade, timestamps obrigatórios e
triggers de `updated_at` ficam no banco para que todos os caminhos de escrita
respeitem as restrições.

Em produção, defina `DB_PATH`, `SESSION_SECRET` e uma senha forte. A sessão é
assinada pelo Rack e o banco não deve ficar em um volume efêmero.