# frozen_string_literal: true

require "digest"
require "erb"
require "json"

class MarketplaceApp
  # This value is passed by config.ru to Rack::Session::Cookie. SHA-512
  # produces 128 hexadecimal bytes even when the host provides a short or
  # absent SESSION_SECRET.
  SESSION_COOKIE_SECRET = Digest::SHA512.hexdigest(
    ENV.fetch("SESSION_SECRET", "local-development-session-secret-change-me-please")
  ).freeze

  def call(env)
    RequestContext.new(env).call
  end

  class RequestContext
    def initialize(env)
      @request = Rack::Request.new(env)
      @session = env.fetch("rack.session")
      @flash = @session.delete("flash")
      @query = ""
    end

    def call
      dispatch
    rescue ActiveRecord::RecordNotFound
      render(:not_found, status: 404)
    end

    private

    def current_user
      @current_user ||= User.find_by(id: @session["user_id"]) if @session["user_id"]
    end

    def signed_in?
      !current_user.nil?
    end

    def require_user!
      return if signed_in?

      @session["return_to"] = @request.path
      flash(:warning, "Entre na sua conta para continuar.")
      redirect("/entrar")
    end

    def flash(type = nil, message = nil)
      if type && message
        @session["flash"] = { type: type, message: message }
      else
        @session.delete("flash")
      end
    end

    def cart
      @session["cart"] ||= {}
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

    def dispatch
      method = @request.request_method
      path = @request.path_info

      return home if method == "GET" && path == "/"
      return cart_page if method == "GET" && path == "/carrinho"
      return checkout if method == "POST" && path == "/checkout"
      return login_page if method == "GET" && path == "/entrar"
      return login if method == "POST" && path == "/entrar"
      return logout if method == "POST" && path == "/sair"
      return signup_page if method == "GET" && path == "/criar-conta"
      return signup if method == "POST" && path == "/criar-conta"
      return sell_page if method == "GET" && path == "/vender"
      return sell if method == "POST" && path == "/vender"
      return orders_page if method == "GET" && path == "/minhas-compras"
      return listings_api if method == "GET" && path == "/api/listings"

      if (match = path.match(%r{\A/categoria/([^/]+)\z})) && method == "GET"
        return category_page(match[1])
      end
      if (match = path.match(%r{\A/anuncios/(\d+)\z})) && method == "GET"
        return listing_page(match[1])
      end
      if (match = path.match(%r{\A/carrinho/(\d+)\z})) && method == "POST"
        return add_to_cart(match[1])
      end
      if (match = path.match(%r{\A/carrinho/(\d+)/remover\z})) && method == "POST"
        return remove_from_cart(match[1])
      end

      render(:not_found, status: 404)
    end

    def home
      @query = params["q"].to_s.strip
      @categories = Category.order(:name)
      @listings = Listing.includes(:category, :seller).available.featured_first
      unless @query.empty?
        pattern = "%#{@query.downcase}%"
        @listings = @listings.where("LOWER(listings.title) LIKE ? OR LOWER(listings.description) LIKE ?", pattern, pattern)
      end
      @listings = @listings.limit(12)
      render(:home)
    end

    def category_page(slug)
      @category = Category.find_by!(slug: slug)
      @categories = Category.order(:name)
      @listings = @category.listings.includes(:seller).available.featured_first
      render(:category)
    end

    def listing_page(id)
      @listing = Listing.includes(:seller, :category).find(id)
      render(:listing)
    end

    def add_to_cart(id)
      listing = Listing.find(id)
      return response(422, "Produto indisponível") unless listing.available?

      requested = [params.fetch("quantity", "1").to_i, 1].max
      cart[listing.id.to_s] = [cart.fetch(listing.id.to_s, 0).to_i + requested, listing.stock].min
      flash(:success, "#{listing.title} foi adicionado ao carrinho.")
      redirect("/carrinho")
    end

    def cart_page
      @cart_lines = cart.filter_map do |id, quantity|
        listing = Listing.find_by(id: id)
        { listing: listing, quantity: quantity.to_i } if listing
      end
      @total_cents = @cart_lines.sum { |line| line[:listing].price_cents * line[:quantity] }
      render(:cart)
    end

    def remove_from_cart(id)
      cart.delete(id)
      flash(:success, "Item removido do carrinho.")
      redirect("/carrinho")
    end

    def checkout
      return require_user! unless signed_in?

      lines = cart.filter_map do |id, quantity|
        listing = Listing.find_by(id: id)
        { listing: listing, quantity: quantity.to_i } if listing && quantity.to_i.positive?
      end
      if lines.empty?
        flash(:warning, "Seu carrinho está vazio.")
        return redirect("/carrinho")
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
      @session["cart"] = {}
      flash(:success, "Pedido ##{order.id} criado! Você receberá os próximos passos em breve.")
      redirect("/minhas-compras")
    rescue ActiveRecord::RecordInvalid
      flash(:warning, "Um dos itens ficou sem estoque. Revise o carrinho e tente novamente.")
      redirect("/carrinho")
    end

    def login_page
      render(:login)
    end

    def login
      user = User.find_by(email: params["email"].to_s.strip.downcase)
      if user&.authenticate(params["password"].to_s)
        @session["user_id"] = user.id
        flash(:success, "Boas-vindas, #{user.username}!")
        return redirect(@session.delete("return_to") || "/")
      end

      @error = "E-mail ou senha inválidos."
      render(:login, status: 422)
    end

    def logout
      @session.clear
      flash(:success, "Você saiu da sua conta.")
      redirect("/")
    end

    def signup_page
      @user = User.new
      render(:signup)
    end

    def signup
      @user = User.new(
        username: params["username"],
        email: params["email"],
        password: params["password"],
        password_confirmation: params["password_confirmation"]
      )
      if @user.save
        @session["user_id"] = @user.id
        flash(:success, "Conta criada. Agora você já pode comprar e vender.")
        return redirect("/")
      end

      render(:signup, status: 422)
    end

    def sell_page
      return require_user! unless signed_in?

      @listing = Listing.new(condition: "new", stock: 1)
      render(:new_listing)
    end

    def sell
      return require_user! unless signed_in?

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
        return redirect("/anuncios/#{@listing.id}")
      end

      render(:new_listing, status: 422)
    end

    def orders_page
      return require_user! unless signed_in?

      @orders = current_user.orders.includes(order_items: :listing).order(created_at: :desc)
      render(:orders)
    end

    def listings_api
      payload = Listing.includes(:category, :seller).available.featured_first.limit(50).map do |listing|
        {
          id: listing.id, title: listing.title, description: listing.description,
          price_cents: listing.price_cents, condition: listing.condition, stock: listing.stock,
          category: listing.category.name, seller: listing.seller.username, location: listing.location
        }
      end
      response(200, JSON.generate(payload), "application/json; charset=utf-8")
    end

    def params
      @request.params
    end

    def render(name, status: 200)
      @view_content = template(name)
      response(status, template(:layout), "text/html; charset=utf-8")
    end

    def template(name)
      ERB.new(File.read(File.join(APP_ROOT, "app", "views", "#{name}.erb"))).result(binding)
    end

    def redirect(location)
      [302, { "location" => location, "content-type" => "text/html; charset=utf-8" }, []]
    end

    def response(status, body, content_type = "text/plain; charset=utf-8")
      [status, { "content-type" => content_type, "content-length" => body.bytesize.to_s }, [body]]
    end
  end
end