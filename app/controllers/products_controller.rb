# frozen_string_literal: true

class ProductsController < ApplicationController
  def index
    @categories = Category.order(:name)
    @query = params[:q].to_s.strip
    @products = Product.active.includes(:category, :seller).order(featured: :desc, created_at: :desc)
    @products = @products.where("products.title LIKE :query OR products.description LIKE :query", query: "%#{@query}%") if @query.present?
    @products = @products.where(category_id: params[:category]) if params[:category].present?
    @products = @products.where.not(original_price: nil) if params[:offer] == "true"
  end

  def show
    @product = Product.active.includes(:seller, :category).find(params[:id])
    @related_products = Product.active.where(category: @product.category).where.not(id: @product.id).limit(4)
  end
end
