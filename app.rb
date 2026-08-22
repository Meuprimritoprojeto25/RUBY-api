# frozen_string_literal: true

require "securerandom"
require "sinatra/base"
require "sequel"
require "sqlite3"

# Mercado Pulse is a small, self-contained marketplace.  It intentionally uses
# SQLite so a clean checkout can be run without a separate infrastructure
# service, while keeping relational constraints and migrations in place.
class MercadoPulseApp < Sinatra::Base
  configure do
    set :root, File.expand_path(__dir__)
    set :public_folder, File.join(root, "public")
    set :views, File.join(root, "views")
    set :server, :puma
    set :bind, ENV.fetch("BIND", "0.0.0.0")
    set :port, Integer(ENV.fetch("PORT", "4567"))
    set :environment, ENV.fetch("RACK_ENV", "development").to_sym
    set :session_secret, ENV.fetch(
      "SESSION_SECRET",
      "mercado-pulse-local-session-secret-change-this-in-production-2025"
    )
    enable :sessions
  end

  database_url = ENV.fetch("DATABASE_URL", "sqlite://#{File.join(settings.root, 'db', 'mercado_pulse.sqlite3')}")
  DB = Sequel.connect(database_url, max_connections: 4)
  DB.run("PRAGMA foreign_keys = ON") if DB.database_type == :sqlite

  Sequel::Migrator.run(DB, File.join(settings.root, "db", "migrate"))
  require_relative "db/seeds"
  DemoSeeder.load(DB)

  helpers do
    def h(value)
      Rack::Utils.escape_html(value.to_s)
    end

    def money(cents)
      format("R$ %<whole>d,%<fraction>02d", whole: cents / 100, fraction: cents % 100)
    end

    def csrf_token
      session[:csrf_token] ||= SecureRandom.hex(32)
    end

    def csrf_field
      %(<input type="hidden" name="csrf_token" value="#{h(csrf_token)}">)
    end

    def cart
      session[:cart] ||= {}
    end

    def cart_items
      ids = cart.keys.map(&:to_i)
      return [] if ids.empty?

      products = DB[:products].where(id: ids).all.each_with_object({}) do |product, indexed|
        indexed[product[:id]] = product
      end
      cart.filter_map do |id, quantity|
        product = products[id.to_i]
        next unless product

        product.merge(quantity: quantity.to_i, line_total_cents: product[:price_cents] * quantity.to_i)
      end
    end

    def cart_count
      cart.values.sum(&:to_i)
    end

    def cart_total
      cart_items.sum { |item| item[:line_total_cents] }
    end

    def current_path_with_query
      request.fullpath
    end

    def product_card(product)
      erb :_product_card, layout: false, locals: { product: product }
    end

    def category_icon(category)
      {
        "Tecnologia" => "⌁",
        "Casa e decoração" => "⌂",
        "Moda" => "♧",
        "Esportes" => "◉",
        "Mercado" => "♙",
        "Beleza" => "✦"
      }.fetch(category[:name], "◇")
    end
  end

  before do
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["X-Content-Type-Options"] = "nosniff"
  end

  before %r{^/(carrinho|checkout|pedidos)} do
    next unless request.post?
    halt 403, "Solicitação inválida." unless Rack::Utils.secure_compare(csrf_token, params["csrf_token"].to_s)
  end

  get "/" do
    @categories = DB[:categories].order(:position).all
    @featured = DB[:products].where(active: true, featured: true).order(:position).limit(5).all
    @deals = DB[:products].where(active: true).order(Sequel.desc(:discount_percent), :position).limit(4).all
    @query = params["q"].to_s.strip
    erb :home
  end

  get "/produtos" do
    @query = params["q"].to_s.strip
    @category_slug = params["categoria"].to_s
    @categories = DB[:categories].order(:position).all
    dataset = DB[:products].where(active: true)
    dataset = dataset.where(Sequel.like(:title, "%#{@query}%")) unless @query.empty?
    unless @category_slug.empty?
      category = DB[:categories].where(slug: @category_slug).first
      dataset = dataset.where(category_id: category[:id]) if category
    end
    @products = case params["ordenar"]
                when "menor-preco" then dataset.order(:price_cents, :position).all
                when "maior-preco" then dataset.order(Sequel.desc(:price_cents), :position).all
                else dataset.order(Sequel.desc(:featured), :position).all
                end
    erb :products
  end

  get "/produtos/:slug" do
    @product = DB[:products].where(slug: params[:slug], active: true).first
    halt 404, erb(:not_found) unless @product
    @category = DB[:categories].where(id: @product[:category_id]).first
    @related = DB[:products].where(category_id: @category[:id], active: true).exclude(id: @product[:id]).limit(4).all
    erb :product
  end

  get "/carrinho" do
    @items = cart_items
    erb :cart
  end

  post "/carrinho/adicionar/:id" do
    product = DB[:products].where(id: params[:id], active: true).first
    halt 404, "Produto não encontrado." unless product

    desired_quantity = [params.fetch("quantity", "1").to_i, 1].max
    existing_quantity = cart.fetch(product[:id].to_s, 0).to_i
    cart[product[:id].to_s] = [existing_quantity + desired_quantity, product[:stock]].min
    session[:flash] = "#{product[:title]} foi adicionado ao carrinho."
    redirect params["return_to"].to_s.start_with?("/") ? params["return_to"] : "/carrinho"
  end

  post "/carrinho/atualizar/:id" do
    quantity = params.fetch("quantity", "0").to_i
    product = DB[:products].where(id: params[:id], active: true).first
    if product && quantity.positive?
      cart[product[:id].to_s] = [quantity, product[:stock]].min
    else
      cart.delete(params[:id].to_s)
    end
    redirect "/carrinho"
  end

  post "/carrinho/remover/:id" do
    cart.delete(params[:id].to_s)
    session[:flash] = "Item removido do carrinho."
    redirect "/carrinho"
  end

  get "/checkout" do
    redirect "/carrinho" if cart_items.empty?
    @items = cart_items
    erb :checkout
  end

  post "/pedidos" do
    items = cart_items
    redirect "/carrinho" if items.empty?

    customer_name = params["customer_name"].to_s.strip
    customer_email = params["customer_email"].to_s.strip.downcase
    address = params["address"].to_s.strip
    halt 422, "Informe nome, e-mail e endereço para concluir a compra." if [customer_name, customer_email, address].any?(&:empty?)
    halt 422, "Informe um e-mail válido." unless customer_email.match?(/\A[^@\s]+@[^@\s]+\z/)

    order_number = "MP#{Time.now.strftime('%Y%m%d')}#{SecureRandom.random_number(90_000) + 10_000}"
    DB.transaction do
      items.each do |item|
        updated = DB[:products].where(id: item[:id]).where { stock >= item[:quantity] }
                             .update(stock: Sequel[:stock] - item[:quantity])
        halt 422, "#{item[:title]} não possui estoque suficiente." if updated.zero?
      end
      order_id = DB[:orders].insert(
        order_number: order_number,
        customer_name: customer_name,
        customer_email: customer_email,
        shipping_address: address,
        status: "approved",
        total_cents: items.sum { |item| item[:line_total_cents] }
      )
      items.each do |item|
        DB[:order_items].insert(
          order_id: order_id,
          product_id: item[:id],
          product_title: item[:title],
          unit_price_cents: item[:price_cents],
          quantity: item[:quantity],
          total_cents: item[:line_total_cents]
        )
      end
    end

    session[:cart] = {}
    @order_number = order_number
    @customer_name = customer_name
    erb :order_success
  end

  not_found do
    erb :not_found
  end

  run! if app_file == $PROGRAM_NAME
end