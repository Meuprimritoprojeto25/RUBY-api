# frozen_string_literal: true

require "sinatra/base"
require "active_record"
require "bcrypt"
require "fileutils"
require "securerandom"
require "uri"

APP_ROOT = File.expand_path(__dir__) unless defined?(APP_ROOT)

module Database
  module_function

  def connect!
    return if ActiveRecord::Base.connected?

    database_url = ENV["DATABASE_URL"]
    if database_url && !database_url.empty?
      ActiveRecord::Base.establish_connection(database_url)
    else
      FileUtils.mkdir_p(File.join(APP_ROOT, "db"))
      environment = ENV.fetch("RACK_ENV", "development")
      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: ENV.fetch("DATABASE_PATH", File.join(APP_ROOT, "db", "#{environment}.sqlite3"))
      )
    end

    ActiveRecord::Migration.verbose = ENV["MIGRATION_VERBOSE"] == "true"
    migration_context = ActiveRecord::MigrationContext.new(File.join(APP_ROOT, "db", "migrate"))
    migration_context.migrate
  end
end

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end

class User < ApplicationRecord
  has_secure_password

  has_many :products, foreign_key: :seller_id, dependent: :restrict_with_error
  has_many :favorites, dependent: :destroy
  has_many :favorite_products, through: :favorites, source: :product
  has_many :orders, dependent: :restrict_with_error

  enum :role, { buyer: "buyer", seller: "seller", admin: "admin" }, validate: true

  before_validation :normalize_identity

  validates :username, presence: true, length: { in: 3..30 },
                      format: { with: /\A[a-zA-Z0-9_.-]+\z/ }, uniqueness: { case_sensitive: false }
  validates :email, presence: true, length: { maximum: 120 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :role, presence: true

  private

  def normalize_identity
    self.username = username.to_s.strip
    self.email = email.to_s.strip.downcase
  end
end

class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  before_validation :generate_slug

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, format: { with: /\A[a-z0-9-]+\z/ }, uniqueness: true

  private

  def generate_slug
    self.slug = name.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-+\z/, "") if slug.to_s.empty?
  end
end

class Product < ApplicationRecord
  belongs_to :seller, class_name: "User"
  belongs_to :category
  has_many :favorites, dependent: :destroy
  has_many :order_items, dependent: :restrict_with_error

  enum :status, { active: "active", paused: "paused", sold_out: "sold_out" }, validate: true

  before_validation :generate_slug

  validates :title, presence: true, length: { in: 5..100 }
  validates :description, presence: true, length: { in: 20..2000 }
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :slug, presence: true, uniqueness: true
  validates :image_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }

  scope :available, -> { where(status: "active").where("stock > 0") }
  scope :recent, -> { order(created_at: :desc) }

  private

  def generate_slug
    return if title.to_s.empty?

    base = title.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-+\z/, "")
    self.slug = "#{base}-#{SecureRandom.hex(3)}" if slug.to_s.empty?
  end
end

class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :user_id, uniqueness: { scope: :product_id }
end

class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :restrict_with_error

  enum :status, { created: "created", paid: "paid", cancelled: "cancelled" }, validate: true

  validates :total_cents, numericality: { only_integer: true, greater_than: 0 }
end

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than: 0 }
end

module DemoSeeder
  module_function

  def enabled?
    ENV["DASHBOARDIA_DEMO_MODE"] == "true"
  end

  def load!
    return unless enabled?

    demo_username = demo_value("DASHBOARDIA_DEMO_USERNAME", "admin")
    demo_email = demo_value("DASHBOARDIA_DEMO_EMAIL", "admin@mercadoviva.local")
    demo_password = demo_value("DASHBOARDIA_DEMO_PASSWORD", "mercadoviva-demo")
    admin = User.find_or_initialize_by(email: demo_email)
    admin.assign_attributes(
      username: demo_username,
      password: demo_password,
      password_confirmation: demo_password,
      role: "admin"
    )
    admin.save!

    sellers = [
      { username: "casa_norte", email: "casa.norte@mercadoviva.local", password: "Viva#2025", role: "seller" },
      { username: "tech_urbana", email: "tech.urbana@mercadoviva.local", password: "Viva#2025", role: "seller" }
    ].map { |attributes| find_or_create_user(attributes) }

    categories = [
      ["Tecnologia", "tecnologia"],
      ["Casa e decoração", "casa-decoracao"],
      ["Moda", "moda"],
      ["Esportes", "esportes"],
      ["Veículos", "veiculos"]
    ].to_h { |name, slug| [slug, Category.find_or_create_by!(slug: slug) { |category| category.name = name }] }

    products = [
      ["Fone Bluetooth com cancelamento de ruído", "Som imersivo, bateria de até 30 horas e estojo de carregamento incluso.", 18_990, 12, "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=800&q=80", "tecnologia", 1],
      ["Cafeteira italiana em aço inox", "Prepare café encorpado em minutos. Design clássico e capacidade para seis xícaras.", 8_490, 8, "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&q=80", "casa-decoracao", 0],
      ["Tênis de corrida leve unissex", "Amortecimento responsivo e tecido respirável para treinos e caminhadas.", 22_990, 20, "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=800&q=80", "esportes", 1],
      ["Mochila urbana impermeável 20L", "Compartimento acolchoado para notebook e bolsos organizadores para a rotina.", 12_900, 15, "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=800&q=80", "moda", 0],
      ["Smartwatch com monitor cardíaco", "Acompanhe treinos, sono e notificações em uma tela nítida e resistente à água.", 29_990, 6, "https://images.unsplash.com/photo-1546868871-7041f2a55e12?auto=format&fit=crop&w=800&q=80", "tecnologia", 1],
      ["Luminária de mesa articulada", "Iluminação LED quente, toque minimalista e ajuste preciso para o seu espaço.", 7_990, 10, "https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=800&q=80", "casa-decoracao", 0]
    ]

    products.each do |title, description, price, stock, image_url, category_slug, seller_index|
      Product.find_or_create_by!(title: title) do |product|
        product.description = description
        product.price_cents = price
        product.stock = stock
        product.image_url = image_url
        product.category = categories.fetch(category_slug)
        product.seller = sellers.fetch(seller_index)
        product.status = "active"
      end
    end

    FileUtils.mkdir_p(File.join(APP_ROOT, ".dashboardia"))
    File.write(File.join(APP_ROOT, ".dashboardia", "demo-access.json"), '{"version":1}')
  end

  def find_or_create_user(attributes)
    user = User.find_or_initialize_by(email: attributes.fetch(:email))
    if user.new_record?
      base_username = attributes.fetch(:username)
      username = base_username
      suffix = 2
      while User.where("lower(username) = ?", username.downcase).exists?
        username = "#{base_username}-#{suffix}"
        suffix += 1
      end
      user.assign_attributes(attributes.merge(username: username, password_confirmation: attributes.fetch(:password)))
      user.save!
    end
    user
  end

  def demo_value(name, default)
    value = ENV[name].to_s.strip
    value.empty? ? default : value
  end
  private_class_method :find_or_create_user, :demo_value
end

Database.connect!
DemoSeeder.load!

class MarketplaceApp < Sinatra::Base
  configure do
    set :root, APP_ROOT
    set :views, File.join(APP_ROOT, "views")
    set :public_folder, File.join(APP_ROOT, "public")
    set :show_exceptions, false
  end

  helpers do
    def current_user
      @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
    end

    def signed_in?
      !current_user.nil?
    end

    def money(cents)
      format("R$ %<amount>.2f", amount: cents.to_i / 100.0).tr(".", ",")
    end

    def cart
      session[:cart] ||= {}
    end

    def cart_count
      cart.values.map(&:to_i).sum
    end

    def require_user!
      return if signed_in?

      session[:return_to] = request.path
      flash(:alert, "Entre para continuar.")
      redirect "/entrar"
    end

    def flash(type, message = nil)
      session[:flash] ||= {}
      return session[:flash].delete(type) unless message

      session[:flash][type] = message
    end

    def product_image(product)
      product.image_url.to_s.empty? ? "https://placehold.co/800x600/f5f5f5/4b4b4b?text=Mercado+Viva" : product.image_url
    end
  end

  before do
    @notice = flash(:notice)
    @alert = flash(:alert)
  end

  get "/" do
    @categories = Category.order(:name)
    @featured_products = Product.available.includes(:seller, :category).recent.limit(6)
    erb :home
  end

  get "/produtos" do
    @query = params["q"].to_s.strip
    @category = Category.find_by(slug: params["categoria"])
    @categories = Category.order(:name)
    @products = Product.available.includes(:seller, :category)
    @products = @products.where(category: @category) if @category
    if !@query.empty?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      @products = @products.where("products.title LIKE ? OR products.description LIKE ?", term, term)
    end
    @products = case params["ordem"]
                when "menor-preco" then @products.order(price_cents: :asc)
                when "maior-preco" then @products.order(price_cents: :desc)
                else @products.recent
                end
    erb :products
  end

  get "/produtos/:slug" do
    @product = Product.includes(:seller, :category).find_by!(slug: params["slug"])
    @related_products = Product.available.where(category: @product.category).where.not(id: @product.id).recent.limit(3)
    erb :product
  rescue ActiveRecord::RecordNotFound
    halt 404, erb(:not_found)
  end

  get "/cadastro" do
    redirect "/" if signed_in?
    @user = User.new
    erb :signup
  end

  post "/cadastro" do
    @user = User.new(
      username: params["username"],
      email: params["email"],
      password: params["password"],
      password_confirmation: params["password_confirmation"],
      role: "buyer"
    )
    if @user.save
      session[:user_id] = @user.id
      flash(:notice, "Conta criada. Boas compras!")
      redirect "/"
    end
    erb :signup
  end

  get "/entrar" do
    redirect "/" if signed_in?
    erb :login
  end

  post "/entrar" do
    user = User.find_by(email: params["email"].to_s.strip.downcase)
    if user&.authenticate(params["password"])
      session[:user_id] = user.id
      destination = session.delete(:return_to) || "/"
      flash(:notice, "Olá, #{user.username}!")
      redirect destination
    end
    @alert = "E-mail ou senha inválidos."
    erb :login
  end

  post "/sair" do
    session.clear
    redirect "/"
  end

  get "/anunciar" do
    require_user!
    @product = Product.new
    @categories = Category.order(:name)
    erb :new_product
  end

  post "/anunciar" do
    require_user!
    @categories = Category.order(:name)
    @product = current_user.products.new(product_params)
    @product.status = "active"
    if @product.save
      flash(:notice, "Seu anúncio já está no ar!")
      redirect "/produtos/#{@product.slug}"
    end
    erb :new_product
  end

  get "/minha-conta" do
    require_user!
    @my_products = current_user.products.includes(:category).recent
    @favorites = current_user.favorite_products.includes(:seller, :category).recent
    @orders = current_user.orders.includes(order_items: :product).order(created_at: :desc)
    erb :account
  end

  post "/favoritos/:slug" do
    require_user!
    product = Product.find_by!(slug: params["slug"])
    current_user.favorites.find_or_create_by!(product: product)
    flash(:notice, "Produto salvo nos seus favoritos.")
    redirect request.referer || "/produtos/#{product.slug}"
  rescue ActiveRecord::RecordNotFound
    halt 404, erb(:not_found)
  end

  post "/carrinho/:slug" do
    product = Product.available.find_by!(slug: params["slug"])
    cart[product.id.to_s] = [cart.fetch(product.id.to_s, 0).to_i + 1, product.stock].min
    flash(:notice, "#{product.title} foi adicionado ao carrinho.")
    redirect request.referer || "/carrinho"
  rescue ActiveRecord::RecordNotFound
    halt 404, erb(:not_found)
  end

  get "/carrinho" do
    @cart_products = Product.where(id: cart.keys).index_by(&:id)
    erb :cart
  end

  post "/carrinho/:id/remover" do
    cart.delete(params["id"])
    redirect "/carrinho"
  end

  post "/checkout" do
    require_user!
    items = Product.available.where(id: cart.keys).index_by(&:id)
    line_items = cart.filter_map do |product_id, quantity|
      product = items[product_id.to_i]
      amount = [quantity.to_i, product&.stock.to_i].min
      { product: product, quantity: amount, total_cents: product.price_cents * amount } if product && amount.positive?
    end
    if line_items.empty?
      flash(:alert, "Seu carrinho está vazio.")
      redirect "/carrinho"
    end

    Order.transaction do
      total = line_items.sum { |line| line.fetch(:total_cents) }
      order = current_user.orders.create!(status: "created", total_cents: total)
      line_items.each do |line|
        product = line.fetch(:product)
        product.lock!
        raise ActiveRecord::RecordInvalid, product if product.stock < line.fetch(:quantity)

        order.order_items.create!(
          product: product,
          quantity: line.fetch(:quantity),
          unit_price_cents: product.price_cents
        )
        remaining_stock = product.stock - line.fetch(:quantity)
        product.update!(stock: remaining_stock, status: remaining_stock.zero? ? "sold_out" : "active")
      end
    end
    session[:cart] = {}
    flash(:notice, "Pedido criado com sucesso! Em breve você receberá os dados de pagamento.")
    redirect "/minha-conta"
  rescue ActiveRecord::RecordInvalid
    flash(:alert, "Não foi possível finalizar o pedido. Revise os produtos disponíveis.")
    redirect "/carrinho"
  end

  not_found do
    erb :not_found
  end

  error ActiveRecord::RecordInvalid do
    @alert = "Não foi possível concluir a operação. Verifique os dados informados."
    redirect request.referer || "/"
  end

  private

  def product_params
    {
      title: params["title"],
      description: params["description"],
      price_cents: (params["price"].to_s.tr(",", ".").to_f * 100).round,
      stock: params["stock"],
      category_id: params["category_id"],
      image_url: params["image_url"]
    }
  end
end