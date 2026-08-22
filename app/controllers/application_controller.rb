# frozen_string_literal: true

class ApplicationController < ActionController::Base
  helper_method :current_user, :signed_in?, :cart_count

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in?
    current_user.present?
  end

  def require_user
    return if signed_in?

    redirect_to new_session_path, alert: "Entre na sua conta para finalizar a compra."
  end

  def cart
    session[:cart] ||= {}
  end

  def cart_count
    cart.values.sum(&:to_i)
  end
end
