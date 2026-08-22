# frozen_string_literal: true

require "json"
require "fileutils"

module DemoData
  module_function

  CATEGORIES = [
    ["Tecnologia", "tecnologia"],
    ["Casa e decoração", "casa-e-decoracao"],
    ["Moda", "moda"],
    ["Esportes", "esportes"],
    ["Veículos", "veiculos"]
  ].freeze

  LISTINGS = [
    { category: "tecnologia", title: "Notebook Ultra 14” 16GB", price_cents: 349_900, condition: "new", stock: 8, location: "São Paulo, SP", featured: true, image_url: "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=900&q=80", description: "Notebook leve com tela Full HD, SSD de 512GB e bateria para o dia todo." },
    { category: "tecnologia", title: "Fone Bluetooth com cancelamento", price_cents: 18_990, condition: "new", stock: 19, location: "Curitiba, PR", featured: true, image_url: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=900&q=80", description: "Som imersivo, microfone para chamadas e estojo de carregamento incluso." },
    { category: "casa-e-decoracao", title: "Cafeteira Espresso Compacta", price_cents: 42_990, condition: "new", stock: 5, location: "Belo Horizonte, MG", featured: true, image_url: "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=80", description: "Prepare cafés cremosos em casa com reservatório removível e vaporizador." },
    { category: "moda", title: "Mochila urbana impermeável", price_cents: 12_990, condition: "new", stock: 14, location: "Rio de Janeiro, RJ", featured: false, image_url: "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=900&q=80", description: "Mochila resistente para rotina, trabalho e viagens curtas." },
    { category: "esportes", title: "Bicicleta Mountain Bike aro 29", price_cents: 189_900, condition: "used", stock: 2, location: "Florianópolis, SC", featured: false, image_url: "https://images.unsplash.com/photo-1485965120184-e220f721d03e?auto=format&fit=crop&w=900&q=80", description: "Bicicleta revisada, pronta para pedalar. Quadro em alumínio e 21 marchas." },
    { category: "veiculos", title: "Capacete fechado para motociclista", price_cents: 25_900, condition: "new", stock: 7, location: "Campinas, SP", featured: false, image_url: "https://images.unsplash.com/photo-1558981806-ec527fa84c39?auto=format&fit=crop&w=900&q=80", description: "Capacete certificado com viseira cristal e ventilação frontal." }
  ].freeze

  def seed!
    admin = User.find_or_initialize_by(email: ENV.fetch("DASHBOARDIA_DEMO_EMAIL", "admin@vitrine.local").downcase)
    admin.assign_attributes(
      username: ENV.fetch("DASHBOARDIA_DEMO_USERNAME", "admin").downcase,
      password: ENV.fetch("DASHBOARDIA_DEMO_PASSWORD", "admin12345"),
      password_confirmation: ENV.fetch("DASHBOARDIA_DEMO_PASSWORD", "admin12345"),
      admin: true
    )
    admin.save!

    seller = User.find_or_create_by!(email: "loja@vitrine.local") do |user|
      user.username = "lojavitrine"
      user.password = "vitrine123"
      user.password_confirmation = "vitrine123"
    end

    CATEGORIES.each { |name, slug| Category.find_or_create_by!(slug: slug) { |category| category.name = name } }
    LISTINGS.each do |attributes|
      category = Category.find_by!(slug: attributes[:category])
      listing = Listing.find_or_initialize_by(seller: seller, title: attributes[:title])
      listing_attributes = attributes.reject { |key, _value| key == :category }
      listing.assign_attributes(listing_attributes.merge(category: category))
      listing.save!
    end

    write_access_marker
  end

  def write_access_marker
    directory = File.join(APP_ROOT, ".dashboardia")
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "demo-access.json"), JSON.generate(version: 1))
  end
end