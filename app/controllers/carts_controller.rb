# frozen_string_literal: true

class CartsController < ApplicationController
  before_action :require_user, only: :checkout

  def show
    load_cart_items
  end

  def add
    product = Product.active.find(params[:product_id])
    quantity = [params.fetch(:quantity, 1).to_i, 1].max
    cart[product.id.to_s] = [cart.fetch(product.id.to_s, 0).to_i + quantity, product.stock].min
    redirect_back fallback_location: product_path(product), notice: "#{product.title} foi adicionado ao carrinho."
  end

  def update
    product = Product.active.find(params[:product_id])
    quantity = params.fetch(:quantity, 1).to_i
    if quantity <= 0
      cart.delete(product.id.to_s)
    else
      cart[product.id.to_s] = [quantity, product.stock].min
    end
    redirect_to cart_path, notice: "Carrinho atualizado."
  end

  def remove
    cart.delete(params[:product_id].to_s)
    redirect_to cart_path, notice: "Produto removido do carrinho."
  end

  def checkout
    load_cart_items
    if @cart_items.empty?
      redirect_to cart_path, alert: "Seu carrinho está vazio." and return
    end

    order = nil
    Order.transaction do
      @cart_items.each do |item|
        item[:product].lock!
        raise ActiveRecord::Rollback, "#{item[:product].title} não possui estoque suficiente." if item[:quantity] > item[:product].stock
      end

      subtotal = @cart_items.sum { |item| item[:product].price * item[:quantity] }
      order = current_user.orders.create!(
        number: "ML-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}",
        status: "paid", subtotal: subtotal, total: subtotal
      )
      @cart_items.each do |item|
        product = item[:product]
        order.order_items.create!(product: product, title: product.title, quantity: item[:quantity], unit_price: product.price)
        product.update!(stock: product.stock - item[:quantity], status: product.stock - item[:quantity] <= 0 ? "sold_out" : "active")
      end
    end

    if order&.persisted?
      session[:cart] = {}
      redirect_to root_path, notice: "Compra aprovada! Pedido #{order.number} confirmado."
    else
      redirect_to cart_path, alert: "Não foi possível concluir a compra. Revise o estoque."
    end
  end

  private

  def load_cart_items
    quantities = cart.transform_values(&:to_i).select { |_id, quantity| quantity.positive? }
    products = Product.active.where(id: quantities.keys).index_by { |product| product.id.to_s }
    @cart_items = quantities.filter_map do |id, quantity|
      product = products[id]
      { product: product, quantity: quantity } if product
    end
  end
end
