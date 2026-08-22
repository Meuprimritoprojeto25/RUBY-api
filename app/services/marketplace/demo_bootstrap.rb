# frozen_string_literal: true

require "json"
require "fileutils"

module Marketplace
  # Demo data is intentionally opt-in. It can safely execute on every boot:
  # natural keys and find_or_create_by make it idempotent.
  class DemoBootstrap
    CATEGORIES = [
      ["Tecnologia", "tecnologia", "https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=900&q=80"],
      ["Casa e decoração", "casa-e-decoracao", "https://images.unsplash.com/photo-1618220179428-22790b461013?auto=format&fit=crop&w=900&q=80"],
      ["Moda", "moda", "https://images.unsplash.com/photo-1445205170230-053b83016050?auto=format&fit=crop&w=900&q=80"],
      ["Esportes", "esportes", "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=900&q=80"]
    ].freeze

    PRODUCTS = [
      ["Notebook Pro 14” 16GB RAM", "Performance para trabalho, estudo e criatividade. Garantia de 12 meses.", "Tecnologia", 4299.90, 4999.90, 12, true, "https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=900&q=80"],
      ["Fone Bluetooth Noise Canceling", "Som imersivo, bateria de até 30 horas e carregamento rápido.", "Tecnologia", 289.90, 359.90, 35, true, "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=900&q=80"],
      ["Smartwatch Fit AMOLED", "Monitore seus treinos, sono e notificações em uma tela vibrante.", "Tecnologia", 399.00, 499.00, 22, true, "https://images.unsplash.com/photo-1546868871-7041f2a55e12?auto=format&fit=crop&w=900&q=80"],
      ["Poltrona Luna em Linho", "Conforto e design contemporâneo para transformar sua sala.", "Casa e decoração", 899.90, 1199.90, 8, true, "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=900&q=80"],
      ["Tênis Urban Run", "Leve, respirável e pronto para acompanhar a sua rotina.", "Esportes", 219.90, 299.90, 40, true, "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=80"],
      ["Jaqueta Essential", "Modelagem confortável e acabamento premium para todos os dias.", "Moda", 249.90, nil, 18, false, "https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&w=900&q=80"]
    ].freeze

    def self.call
      admin = User.find_or_initialize_by(email: ENV.fetch("DASHBOARDIA_DEMO_EMAIL", "admin@dashboardia.local").strip.downcase)
      admin.assign_attributes(
        username: ENV.fetch("DASHBOARDIA_DEMO_USERNAME", "admin").strip,
        role: "admin",
        password: ENV.fetch("DASHBOARDIA_DEMO_PASSWORD", "ChangeMe123!"),
        password_confirmation: ENV.fetch("DASHBOARDIA_DEMO_PASSWORD", "ChangeMe123!")
      )
      admin.save! if admin.new_record? || admin.changed?

      seller = User.find_or_create_by!(email: "loja@mercado.local") do |user|
        user.username = "Loja Oficial"
        user.role = "seller"
        user.password = "SellerDemo123!"
        user.password_confirmation = "SellerDemo123!"
      end

      categories = CATEGORIES.to_h do |name, slug, image_url|
        category = Category.find_or_create_by!(slug: slug) { |record| record.name = name; record.image_url = image_url }
        [name, category]
      end

      PRODUCTS.each do |title, description, category_name, price, original_price, stock, featured, image_url|
        product = Product.find_or_initialize_by(title: title, seller: seller)
        product.assign_attributes(
          description: description, category: categories.fetch(category_name), price: price,
          original_price: original_price, stock: stock, featured: featured, image_url: image_url, status: "active"
        )
        product.save! if product.new_record? || product.changed?
      end

      write_access_marker
    end

    def self.write_access_marker
      directory = Rails.root.join(".dashboardia")
      FileUtils.mkdir_p(directory)
      File.write(directory.join("demo-access.json"), JSON.generate(version: 1))
    end
    private_class_method :write_access_marker
  end
end
