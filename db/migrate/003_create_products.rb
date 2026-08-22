# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.integer :price_cents, null: false
      t.integer :stock, null: false, default: 0
      t.string :status, null: false, default: "active"
      t.string :image_url
      t.timestamps null: false
    end

    add_index :products, :slug, unique: true
    add_check_constraint :products, "price_cents > 0", name: "products_price_positive"
    add_check_constraint :products, "stock >= 0", name: "products_stock_not_negative"
  end
end