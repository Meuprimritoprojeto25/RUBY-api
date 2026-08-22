# frozen_string_literal: true

require "sinatra/base"
require "digest"
require "json"

class MarketplaceApp < Sinatra::Base
  configure do
    set :root, APP_ROOT
    set :views, File.join(APP_ROOT, "app", "views")
    set :public_folder, File.join(APP_ROOT, "public")
    enable :sessions
    # Rack 3 requires cookie-session secrets to be at least 64 bytes. Hashing
    # the configured value provides a fixed 128-byte secret even when a local
    # or preview environment does not provide SESSION_SECRET (or provides a
    # short legacy value), preventing requests from failing during middleware
    # initialization.
    session_secret_source = ENV.fetch("SESSION_SECRET", "local-development-session-secret-change-me-please")
    set :session_secret, Digest::SHA512.hexdigest(session_secret_source)
  end

  use Rack::MethodOverride

  helpers do
    def current_user
      @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
    end

    def signed_in?
      !current_user.nil?
    end

    def require_user!
      return if signed_in?

      session[:return_to] = request.path
      flash(:warning, "Entre na sua conta para continuar.")
      redirect "/entrar"
    end

    def flash(type = nil, message = nil)
      if type && message
        session[:flash] = { type: type, message: message }
      else
        session.delete(:flash)
      end
    end

    def cart
      session[:cart] ||= {}
    end

    def cart_count
      cart.values.sum(&:to_i)
    end

    def money(cents)
      format("R$ %<whole>s,%<fraction>02d", whole: cents / 100, fraction: cents % 100).gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1.')
    end

    def h(value)
      Rack::Utils.escape_html(value.to_s)
    end

    def category_options
      Category.order(:name)
    end

    def listing_image(listing)
      return listing.image_url unless listing.image_url.to_s.empty?

      "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=900&q=80"
    end

    def condition_label(condition)
      { "new" => "Novo", "used" => "Usado", "refurbished" => "Recondicionado" }.fetch(condition, condition)
    end

    def parse_cents(value)
      normalized = value.to_s.strip.tr(",", ".")
      return nil unless normalized.match?(/\A\d+(?:\.\d{1,2})?\z/)

      (normalized.to_f * 100).round
    end
  end

  before do
    @flash = flash
  end

  get "/" do
    query = params["q"].to_s.strip
    @categories = Category.order(:name)
    @listings = Listing.includes(:category, :seller).available.featured_first
    unless query.empty?
      pattern = "%#{query.downcase}%"
      @listings = @listings.where("LOWER(listings.title) LIKE ? OR LOWER(listings.description) LIKE ?", pattern, pattern)
    end
    @listings = @listings.limit(12)
    @query = query
    erb :home
  end

  get "/categoria/:slug" do
    @category = Category.find_by!(slug: params[:slug])
    @categories = Category.order(:name)
    @listings = @category.listings.includes(:seller).available.featured_first
    erb :category
  end

  get "/anuncios/:id" do
    @listing = Listing.includes(:seller, :category).find(params[:id])
    erb :listing
  end

  post "/carrinho/:id" do
    listing = Listing.find(params[:id])
    halt 422, "Produto indisponível" unless listing.available?

    requested = [params.fetch("quantity", "1").to_i, 1].max
    cart[listing.id.to_s] = [cart.fetch(listing.id.to_s, 0).to_i + requested, listing.stock].min
    flash(:success, "#{listing.title} foi adicionado ao carrinho.")
    redirect "/carrinho"
  end

  get "/carrinho" do
    @cart_lines = cart.filter_map do |id, quantity|
      listing = Listing.find_by(id: id)
      { listing: listing, quantity: quantity.to_i } if listing
    end
    @total_cents = @cart_lines.sum { |line| line[:listing].price_cents * line[:quantity] }
    erb :cart
  end

  post "/carrinho/:id/remover" do
    cart.delete(params[:id])
    flash(:success, "Item removido do carrinho.")
    redirect "/carrinho"
  end

  post "/checkout" do
    require_user!
    lines = cart.filter_map do |id, quantity|
      listing = Listing.find_by(id: id)
      { listing: listing, quantity: quantity.to_i } if listing && quantity.to_i.positive?
    end
    if lines.empty?
      flash(:warning, "Seu carrinho está vazio.")
      redirect "/carrinho"
    end

    order = nil
    Order.transaction do
      lines.each do |line|
        line[:listing].lock!
        raise ActiveRecord::RecordInvalid.new(line[:listing]) if line[:listing].stock < line[:quantity]
      end
      total = lines.sum { |line| line[:listing].price_cents * line[:quantity] }
      order = current_user.orders.create!(status: "pending", total_cents: total)
      lines.each do |line|
        listing = line[:listing]
        order.order_items.create!(listing: listing, quantity: line[:quantity], unit_price_cents: listing.price_cents)
        listing.update!(stock: listing.stock - line[:quantity])
      end
    end
    session[:cart] = {}
    flash(:success, "Pedido ##{order.id} criado! Você receberá os próximos passos em breve.")
    redirect "/minhas-compras"
  rescue ActiveRecord::RecordInvalid
    flash(:warning, "Um dos itens ficou sem estoque. Revise o carrinho e tente novamente.")
    redirect "/carrinho"
  end

  get "/entrar" do
    erb :login
  end

  post "/entrar" do
    user = User.find_by(email: params["email"].to_s.strip.downcase)
    if user&.authenticate(params["password"].to_s)
      session[:user_id] = user.id
      flash(:success, "Boas-vindas, #{user.username}!")
      redirect(session.delete(:return_to) || "/")
    end

    @error = "E-mail ou senha inválidos."
    erb :login, status: 422
  end

  post "/sair" do
    session.clear
    flash(:success, "Você saiu da sua conta.")
    redirect "/"
  end

  get "/criar-conta" do
    @user = User.new
    erb :signup
  end

  post "/criar-conta" do
    @user = User.new(
      username: params["username"],
      email: params["email"],
      password: params["password"],
      password_confirmation: params["password_confirmation"]
    )
    if @user.save
      session[:user_id] = @user.id
      flash(:success, "Conta criada. Agora você já pode comprar e vender.")
      redirect "/"
    end

    erb :signup, status: 422
  end

  get "/vender" do
    require_user!
    @listing = Listing.new(condition: "new", stock: 1)
    erb :new_listing
  end

  post "/vender" do
    require_user!
    @listing = current_user.listings.new(
      category_id: params["category_id"],
      title: params["title"],
      description: params["description"],
      price_cents: parse_cents(params["price"]),
      condition: params["condition"],
      stock: params["stock"],
      location: params["location"],
      image_url: params["image_url"],
      featured: params["featured"] == "1"
    )
    if @listing.save
      flash(:success, "Seu anúncio está no ar!")
      redirect "/anuncios/#{@listing.id}"
    end

    erb :new_listing, status: 422
  end

  get "/minhas-compras" do
    require_user!
    @orders = current_user.orders.includes(order_items: :listing).order(created_at: :desc)
    erb :orders
  end

  get "/api/listings" do
    content_type :json
    Listing.includes(:category, :seller).available.featured_first.limit(50).map do |listing|
      {
        id: listing.id, title: listing.title, description: listing.description,
        price_cents: listing.price_cents, condition: listing.condition, stock: listing.stock,
        category: listing.category.name, seller: listing.seller.username, location: listing.location
      }
    end.to_json
  end

  not_found do
    erb :not_found, status: 404
  end
end