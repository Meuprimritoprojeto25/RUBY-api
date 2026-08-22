# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @categories = Category.order(:name)
    @featured_products = Product.featured.includes(:seller, :category).limit(6)
    @offer_products = Product.active.where.not(original_price: nil).includes(:seller, :category).limit(4)
  end

  def sell; end

  def help; end
end
