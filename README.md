# Mercado Pulse

Marketplace demonstrativo em Ruby, inspirado em grandes plataformas de venda
online. A aplicação oferece uma vitrine responsiva, pesquisa e categorias,
página de produto, carrinho em sessão e um checkout demonstrativo que persiste
pedidos e baixa o estoque.

## Requisitos

- Ruby 3.1 ou superior
- SQLite 3 (a gem `sqlite3` inclui o adaptador)

## Inicialização

```bash
bundle install
bundle exec ruby app.rb
```

Abra [http://localhost:4567](http://localhost:4567). O servidor usa `0.0.0.0`
por padrão, portanto também está pronto para ambientes de preview. Para
executar com Rack/Puma:

```bash
bundle exec rackup -o 0.0.0.0 -p 4567
```

Variáveis opcionais:

| Variável | Padrão | Finalidade |
| --- | --- | --- |
| `PORT` | `4567` | Porta HTTP |
| `BIND` | `0.0.0.0` | Interface HTTP |
| `DATABASE_URL` | `sqlite://db/mercado_pulse.sqlite3` | Conexão Sequel (SQLite por padrão) |
| `SESSION_SECRET` | segredo local de desenvolvimento | Troque em produção |
| `RACK_ENV` | `development` | Ambiente Sinatra |

## Banco de dados e dados demonstrativos

No primeiro boot, a aplicação cria `db/mercado_pulse.sqlite3`, executa todas
as migrações e carrega um catálogo demonstrativo de categorias e produtos.
Essa carga é idempotente: iniciar novamente não duplica registros.

As tabelas têm chaves estrangeiras, `NOT NULL`, unicidade, checks de preço e
estoque e timestamps centralizados no banco. Triggers SQLite atualizam
`updated_at` em alterações; `created_at` é preenchido por default.

Comandos auxiliares:

```bash
bundle exec rake db:migrate # reaplica migrações pendentes
bundle exec rake db:seed    # atualiza catálogo de demonstração
bundle exec rake db:reset   # remove somente o SQLite local
```

Após `db:reset`, basta iniciar o servidor novamente para reconstruir tudo em
um banco limpo.

## Rotas principais

- `/` — página inicial com campanha, categorias, produtos e ofertas.
- `/produtos` — catálogo, busca, filtros de categoria e ordenação.
- `/produtos/:slug` — detalhe e adição ao carrinho.
- `/carrinho` — atualização e remoção de itens.
- `/checkout` — confirmação demonstrativa de compra.

Não há cobrança real: o checkout serve para exercitar o fluxo completo e
registra pedidos no banco de dados sem solicitar cartão.