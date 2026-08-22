# frozen_string_literal: true

class CreateMarketplaceTables < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :admin, null: false, default: false
      t.timestamps null: false
    end
    add_index :users, :username, unique: true
    add_index :users, :email, unique: true

    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps null: false
    end
    add_index :categories, :name, unique: true
    add_index :categories, :slug, unique: true

    create_table :listings do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false
      t.integer :price_cents, null: false
      t.string :condition, null: false
      t.integer :stock, null: false, default: 0
      t.string :location, null: false
      t.string :image_url
      t.boolean :featured, null: false, default: false
      t.timestamps null: false
    end
    add_check_constraint :listings, "price_cents > 0", name: "listings_price_positive"
    add_check_constraint :listings, "stock >= 0", name: "listings_stock_nonnegative"
    add_check_constraint :listings, "condition IN ('new', 'used', 'refurbished')", name: "listings_condition_valid"
    add_index :listings, :created_at

    create_table :orders do |t|
      t.references :buyer, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.integer :total_cents, null: false
      t.timestamps null: false
    end
    add_check_constraint :orders, "total_cents > 0", name: "orders_total_positive"
    add_check_constraint :orders, "status IN ('pending', 'paid', 'shipped', 'cancelled')", name: "orders_status_valid"

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :listing, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :unit_price_cents, null: false
      t.timestamps null: false
    end
    add_check_constraint :order_items, "quantity > 0", name: "order_items_quantity_positive"
    add_check_constraint :order_items, "unit_price_cents > 0", name: "order_items_price_positive"
  end
end