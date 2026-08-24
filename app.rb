# frozen_string_literal: true

require "fileutils"
require "json"
require "openssl"
require "securerandom"
require "sinatra/base"
require "sqlite3"
require "time"

module Marketplace
  ROOT = File.expand_path(__dir__)

  class Database
    MIGRATIONS_PATH = File.join(ROOT, "db", "migrations")

    def self.connection(path)
      FileUtils.mkdir_p(File.dirname(path))
      SQLite3::Database.new(path).tap do |db|
        db.results_as_hash = true
        db.busy_timeout(5_000)
        db.execute("PRAGMA foreign_keys = ON")
      end
    end

    def self.migrate!(path)
      db = connection(path)
      db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS schema_migrations (
          version TEXT PRIMARY KEY,
          applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      SQL

      Dir[File.join(MIGRATIONS_PATH, "*.sql")].sort.each do |file|
        version = File.basename(file).split("_", 2).first
        next if db.get_first_value("SELECT version FROM schema_migrations WHERE version = ?", version)

        db.transaction do
          db.execute_batch(File.read(file))
          db.execute("INSERT INTO schema_migrations (version) VALUES (?)", version)
        end
      end
    ensure
      db&.close
    end

    def self.now
      Time.now.utc.iso8601
    end
  end

  class Password
    ITERATIONS = 120_000

    def self.create(value)
      salt = SecureRandom.hex(16)
      [salt, digest(value, salt)]
    end

    def self.valid?(value, salt, expected)
      return false if [value, salt, expected].any?(&:nil?)

      actual = digest(value, salt)
      OpenSSL.fixed_length_secure_compare(actual, expected)
    rescue ArgumentError
      false
    end

    def self.digest(value, salt)
      OpenSSL::KDF.pbkdf2_hmac(value.to_s, salt: salt, iterations: ITERATIONS, length: 64, hash: "sha256").unpack1("H*")
    end
    private_class_method :digest
  end

  class DemoSeed
    PRODUCTS = [
      {
        slug: "iphone-13-128gb-meia-noite",
        title: "iPhone 13 128GB — Meia-noite",
        description: "Smartphone Apple com tela Super Retina XDR, câmera dupla e bateria para o dia todo.",
        price_cents: 2_899_90,
        old_price_cents: 3_299_90,
        category: "celulares",
        condition: "Novo",
        location: "São Paulo, SP",
        shipping: "Frete grátis",
        stock: 12,
        badge: "Mais vendido",
        image_url: "https://images.unsplash.com/photo-1592286927505-2fd4b9c7a2c9?auto=format&fit=crop&w=900&q=85"
      },
      {
        slug: "notebook-lenovo-ideapad-3i",
        title: "Notebook Lenovo IdeaPad 3i Intel Core i5",
        description: "Performance para estudo e trabalho com SSD de 512GB, 8GB de RAM e tela Full HD.",
        price_cents: 2_249_00,
        old_price_cents: 2_699_00,
        category: "informatica",
        condition: "Novo",
        location: "Curitiba, PR",
        shipping: "Frete grátis",
        stock: 8,
        badge: "Oferta do dia",
        image_url: "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=900&q=85"
      },
      {
        slug: "sofa-retratil-3-lugares",
        title: "Sofá Retrátil Reclinável 3 Lugares Suede",
        description: "Conforto e estilo para sua sala. Estrutura reforçada e tecido suede fácil de limpar.",
        price_cents: 1_199_90,
        old_price_cents: 1_499_90,
        category: "casa",
        condition: "Novo",
        location: "Belo Horizonte, MG",
        shipping: "Entrega combinada",
        stock: 5,
        badge: nil,
        image_url: "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=900&q=85"
      },
      {
        slug: "tenis-nike-air-max-sc",
        title: "Tênis Nike Air Max SC Masculino",
        description: "Leve seu estilo para todos os lugares com o conforto e a versatilidade Nike.",
        price_cents: 379_90,
        old_price_cents: 499_90,
        category: "moda",
        condition: "Novo",
        location: "Rio de Janeiro, RJ",
        shipping: "Frete grátis",
        stock: 20,
        badge: "Oferta",
        image_url: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=85"
      },
      {
        slug: "cafeteira-nespresso-essenza-mini",
        title: "Cafeteira Nespresso Essenza Mini",
        description: "Café espresso perfeito em poucos segundos, com design compacto para sua cozinha.",
        price_cents: 449_90,
        old_price_cents: 599_90,
        category: "casa",
        condition: "Novo",
        location: "São Paulo, SP",
        shipping: "Frete grátis",
        stock: 15,
        badge: "Mais vendido",
        image_url: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?auto=format&fit=crop&w=900&q=85"
      },
      {
        slug: "playstation-5-slim",
        title: "PlayStation 5 Slim Edição Digital",
        description: "A nova geração de jogos com carregamento ultrarrápido e gráficos impressionantes.",
        price_cents: 3_499_90,
        old_price_cents: 3_999_90,
        category: "eletronicos",
        condition: "Novo",
        location: "Campinas, SP",
        shipping: "Frete grátis",
        stock: 6,
        badge: "Últimas unidades",
        image_url: "https://images.unsplash.com/photo-1606813907291-d86efa9b94db?auto=format&fit=crop&w=900&q=85"
      },
      {
        slug: "bicicleta-mtb-aro-29",
        title: "Bicicleta MTB Aro 29 21 Marchas",
        description: "Explore novos caminhos com quadro de alumínio, suspensão dianteira e freios a disco.",
        price_cents: 899_90,
        old_price_cents: 1_099_90,
        category: "esportes",
        condition: "Novo",
        location: "Joinville, SC",
        shipping: "Entrega combinada",
        stock: 9,
        badge: nil,
        image_url: "https://images.unsplash.com/photo-1485965120184-e220f721d03e?auto=format&fit=crop&w=900&q=85"
      },
      {
        slug: "air-fryer-oven-12-litros",
        title: "Air Fryer Oven 12L Digital",
        description: "Mais praticidade para preparar suas receitas favoritas sem usar óleo.",
        price_cents: 529_90,
        old_price_cents: 699_90,
        category: "casa",
        condition: "Novo",
        location: "Porto Alegre, RS",
        shipping: "Frete grátis",
        stock: 11,
        badge: "Oferta",
        image_url: "https://images.unsplash.com/photo-1585515320310-259814833e62?auto=format&fit=crop&w=900&q=85"
      }
    ].freeze

    CATEGORIES = {
      "celulares" => "Celulares e Telefones",
      "informatica" => "Informática",
      "eletronicos" => "Eletrônicos",
      "casa" => "Casa e Decoração",
      "moda" => "Moda",
      "esportes" => "Esportes e Fitness"
    }.freeze

    def self.run(path, project_root: ROOT)
      username = env_or("DASHBOARDIA_DEMO_USERNAME", "admin")
      email = env_or("DASHBOARDIA_DEMO_EMAIL", "admin@vendah.local")
      password = env_or("DASHBOARDIA_DEMO_PASSWORD", "admin123")
      db = Database.connection(path)

      db.transaction do
        salt, digest = Password.create(password)
        db.execute(<<~SQL, username, email, digest, salt)
          INSERT INTO users (username, email, password_digest, password_salt, role)
          VALUES (?, ?, ?, ?, 'admin')
          ON CONFLICT(username) DO UPDATE SET
            email = excluded.email,
            password_digest = excluded.password_digest,
            password_salt = excluded.password_salt,
            role = 'admin',
            updated_at = CURRENT_TIMESTAMP
        SQL

        CATEGORIES.each do |slug, name|
          db.execute("INSERT INTO categories (slug, name) VALUES (?, ?) ON CONFLICT(slug) DO UPDATE SET name = excluded.name", slug, name)
        end

        PRODUCTS.each do |product|
          category_id = db.get_first_value("SELECT id FROM categories WHERE slug = ?", product[:category])
          db.execute(<<~SQL, product.values_at(:slug, :title, :description, :price_cents, :old_price_cents,
                                                 :condition, :location, :shipping, :stock, :badge, :image_url, category_id))
            INSERT INTO products
              (slug, title, description, price_cents, old_price_cents, condition, location, shipping,
               stock, badge, image_url, category_id, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')
            ON CONFLICT(slug) DO UPDATE SET
              title = excluded.title, description = excluded.description, price_cents = excluded.price_cents,
              old_price_cents = excluded.old_price_cents, condition = excluded.condition,
              location = excluded.location, shipping = excluded.shipping, stock = excluded.stock,
              badge = excluded.badge, image_url = excluded.image_url, category_id = excluded.category_id,
              status = 'active', updated_at = CURRENT_TIMESTAMP
          SQL
        end
      end

      FileUtils.mkdir_p(File.join(project_root, ".dashboardia"))
      File.write(
        File.join(project_root, ".dashboardia", "demo-access.json"),
        JSON.pretty_generate(version: 1, username: username, email: email) + "\n"
      )
    ensure
      db&.close
    end

    def self.enabled?
      ENV["DASHBOARDIA_DEMO_MODE"].to_s.downcase == "true"
    end

    def self.env_or(key, fallback)
      value = ENV[key].to_s.strip
      value.empty? ? fallback : value
    end
  end

  class Boot
    def self.run!
      path = MarketplaceApp.settings.database_path
      Database.migrate!(path)
      DemoSeed.run(path) if DemoSeed.enabled?
    end
  end
end

class MarketplaceApp < Sinatra::Base
  configure do
    set :root, Marketplace::ROOT
    set :public_folder, File.join(Marketplace::ROOT, "public")
    set :database_path, File.expand_path(ENV.fetch("DB_PATH", "db/development.sqlite3"), Marketplace::ROOT)
    set :session_secret, ENV.fetch("SESSION_SECRET", "vendah-local-session-change-me")
    enable :sessions
    set :sessions, {
      key: "vendah.session",
      secret: settings.session_secret,
      expire_after: 86_400,
      httponly: true,
      same_site: :lax
    }
  end

  helpers do
    def db
      @db ||= Marketplace::Database.connection(settings.database_path)
    end

    def json_body
      raw = request.body.read
      raw.empty? ? {} : JSON.parse(raw)
    rescue JSON::ParserError
      json_error("O corpo da requisição precisa ser um JSON válido.", 400)
    end

    def json_response(payload, status = 200)
      content_type :json
      halt status, JSON.generate(payload)
    end

    def json_error(message, status = 422)
      json_response({ error: message }, status)
    end

    def current_user
      return unless session[:user_id]

      @current_user ||= db.get_first_row(
        "SELECT id, username, email, role FROM users WHERE id = ?", session[:user_id]
      )
    end

    def require_user!
      json_error("Faça login para continuar.", 401) unless current_user
    end

    def require_admin!
      require_user!
      json_error("Acesso restrito ao administrador.", 403) unless current_user["role"] == "admin"
    end

    def product_json(row)
      {
        id: row["id"], slug: row["slug"], title: row["title"], description: row["description"],
        price: row["price_cents"].to_i / 100.0, price_cents: row["price_cents"],
        old_price: row["old_price_cents"] && row["old_price_cents"].to_i / 100.0,
        category: row["category_name"], category_slug: row["category_slug"],
        condition: row["condition"], location: row["location"], shipping: row["shipping"],
        stock: row["stock"], badge: row["badge"], image_url: row["image_url"],
        seller: { name: "Loja verificada", reputation: "MercadoLíder" },
        updated_at: row["updated_at"]
      }
    end
  end

  after do
    @db&.close
  end

  get "/" do
    send_file File.join(settings.public_folder, "index.html")
  end

  get "/api/health" do
    json_response(status: "ok", service: "vendah", database: "connected")
  end

  get "/api/categories" do
    categories = db.execute(<<~SQL)
      SELECT c.slug, c.name, COUNT(p.id) AS product_count
      FROM categories c LEFT JOIN products p ON p.category_id = c.id AND p.status = 'active'
      GROUP BY c.id ORDER BY c.name
    SQL
    json_response(categories.map { |row| { slug: row["slug"], name: row["name"], product_count: row["product_count"].to_i } })
  end

  get "/api/products" do
    page = [[params.fetch("page", "1").to_i, 1].max, 100].min
    per_page = [[params.fetch("per_page", "12").to_i, 1].max, 24].min
    clauses = ["p.status = 'active'"]
    values = []

    if params["q"] && !params["q"].strip.empty?
      clauses << "(p.title LIKE ? OR p.description LIKE ?)"
      query = "%#{params["q"].strip}%"
      values.concat([query, query])
    end
    if params["category"] && !params["category"].strip.empty?
      clauses << "c.slug = ?"
      values << params["category"].strip
    end
    if params["min_price"] && params["min_price"].to_f.positive?
      clauses << "p.price_cents >= ?"
      values << (params["min_price"].to_f * 100).round
    end
    if params["max_price"] && params["max_price"].to_f.positive?
      clauses << "p.price_cents <= ?"
      values << (params["max_price"].to_f * 100).round
    end

    order = case params["sort"]
            when "price_asc" then "p.price_cents ASC"
            when "price_desc" then "p.price_cents DESC"
            else "p.featured DESC, p.created_at DESC"
            end
    where = clauses.join(" AND ")
    total = db.get_first_value("SELECT COUNT(*) FROM products p JOIN categories c ON c.id = p.category_id WHERE #{where}", values).to_i
    rows = db.execute(<<~SQL, values + [per_page, (page - 1) * per_page])
      SELECT p.*, c.name AS category_name, c.slug AS category_slug
      FROM products p JOIN categories c ON c.id = p.category_id
      WHERE #{where}
      ORDER BY #{order}
      LIMIT ? OFFSET ?
    SQL
    json_response(products: rows.map { |row| product_json(row) }, pagination: {
      page: page, per_page: per_page, total: total, pages: (total.to_f / per_page).ceil
    })
  end

  get "/api/products/:id" do
    row = db.get_first_row(<<~SQL, params["id"], params["id"])
      SELECT p.*, c.name AS category_name, c.slug AS category_slug
      FROM products p JOIN categories c ON c.id = p.category_id
      WHERE (p.id = ? OR p.slug = ?) AND p.status = 'active'
    SQL
    json_error("Produto não encontrado.", 404) unless row
    json_response(product: product_json(row))
  end

  post "/api/auth/login" do
    input = json_body
    login = input["login"].to_s.strip
    password = input["password"].to_s
    user = db.get_first_row("SELECT * FROM users WHERE username = ? OR email = ? LIMIT 1", login, login)
    unless user && Marketplace::Password.valid?(password, user["password_salt"], user["password_digest"])
      json_error("Usuário ou senha inválidos.", 401)
    end
    session[:user_id] = user["id"]
    json_response(user: { id: user["id"], username: user["username"], email: user["email"], role: user["role"] })
  end

  get "/api/auth/me" do
    json_error("Não autenticado.", 401) unless current_user
    json_response(user: current_user)
  end

  post "/api/auth/logout" do
    session.clear
    json_response(message: "Sessão encerrada.")
  end

  post "/api/orders" do
    require_user!
    input = json_body
    items = input["items"]
    json_error("Adicione pelo menos um produto ao pedido.") unless items.is_a?(Array) && !items.empty?
    clean_items = items.map do |item|
      { id: item["product_id"].to_i, quantity: [[item["quantity"].to_i, 1].max, 20].min }
    end
    clean_items.uniq! { |item| item[:id] }
    now = Marketplace::Database.now
    total = 0
    order_id = nil

    db.transaction do
      lines = clean_items.map do |item|
        product = db.get_first_row("SELECT id, title, price_cents, stock FROM products WHERE id = ? AND status = 'active'", item[:id])
        json_error("Um dos produtos não está mais disponível.", 422) unless product
        json_error("Estoque insuficiente para #{product["title"]}.", 422) if product["stock"].to_i < item[:quantity]
        line_total = product["price_cents"].to_i * item[:quantity]
        total += line_total
        [product, item[:quantity], line_total]
      end
      db.execute("INSERT INTO orders (user_id, total_cents, status, created_at, updated_at) VALUES (?, ?, 'pending', ?, ?)",
                 current_user["id"], total, now, now)
      order_id = db.last_insert_row_id
      lines.each do |product, quantity, line_total|
        db.execute("INSERT INTO order_items (order_id, product_id, quantity, unit_price_cents, created_at) VALUES (?, ?, ?, ?, ?)",
                   order_id, product["id"], quantity, product["price_cents"], now)
        db.execute("UPDATE products SET stock = stock - ?, updated_at = ? WHERE id = ?", quantity, now, product["id"])
      end
    end
    json_response(order: { id: order_id, total: total / 100.0, status: "pending" }, message: "Pedido recebido!", 201)
  end

  post "/api/products" do
    require_admin!
    input = json_body
    required = %w[title description price category]
    json_error("Informe: #{required.join(", ")}.") unless required.all? { |key| input[key].to_s.strip != "" }
    category = db.get_first_row("SELECT id FROM categories WHERE slug = ?", input["category"].to_s)
    json_error("Categoria inválida.", 422) unless category
    slug = input["title"].to_s.downcase.gsub(/[^a-z0-9]+/i, "-").gsub(/\A-|-+\z/, "")
    cents = (input["price"].to_f * 100).round
    json_error("O preço deve ser maior que zero.", 422) unless cents.positive?
    now = Marketplace::Database.now
    db.execute(<<~SQL, slug, input["title"], input["description"], cents, category["id"], now, now)
      INSERT INTO products (slug, title, description, price_cents, category_id, condition, location, shipping,
                            stock, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, 'Novo', 'A definir', 'A combinar', 1, 'active', ?, ?)
    SQL
    json_response(id: db.last_insert_row_id, message: "Produto publicado.", 201)
  rescue SQLite3::ConstraintException
    json_error("Já existe um produto com esse título.", 409)
  end
end

Marketplace::Boot.run! if $PROGRAM_NAME == __FILE__
MarketplaceApp.run! if $PROGRAM_NAME == __FILE__