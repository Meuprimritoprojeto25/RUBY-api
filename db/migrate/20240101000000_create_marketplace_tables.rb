# frozen_string_literal: true

class CreateMarketplaceTables < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "buyer"
      t.timestamps null: false
    end
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"

    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :image_url
      t.timestamps null: false
    end
    add_index :categories, :slug, unique: true

    create_table :products do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false
      t.decimal :price, precision: 12, scale: 2, null: false
      t.decimal :original_price, precision: 12, scale: 2
      t.integer :stock, null: false, default: 0
      t.string :status, null: false, default: "active"
      t.string :image_url
      t.boolean :featured, null: false, default: false
      t.timestamps null: false
    end
    add_index :products, :status
    add_index :products, :featured

    create_table :orders do |t|
      t.references :buyer, null: false, foreign_key: { to_table: :users }
      t.string :number, null: false
      t.string :status, null: false, default: "pending"
      t.decimal :subtotal, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 12, scale: 2, null: false
      t.timestamps null: false
    end
    add_index :orders, :number, unique: true

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.timestamps null: false
    end
  end
end
