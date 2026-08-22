# frozen_string_literal: true

class CategoriesController < ApplicationController
  def show
    @category = Category.find_by!(slug: params[:id])
    @products = @category.products.active.includes(:seller).order(featured: :desc, created_at: :desc)
  end
end
