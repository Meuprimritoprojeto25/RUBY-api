# frozen_string_literal: true

module ApplicationHelper
  def brl(value)
    number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".")
  end
end
