# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "created"
      t.integer :total_cents, null: false
      t.timestamps null: false
    end

    add_check_constraint :orders, "total_cents > 0", name: "orders_total_positive"
  end
end