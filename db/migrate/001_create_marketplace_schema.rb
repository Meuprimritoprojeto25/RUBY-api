# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:categories) do
      primary_key :id
      String :name, null: false, size: 80
      String :slug, null: false, size: 100, unique: true
      Integer :position, null: false, default: 0
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:products) do
      primary_key :id
      foreign_key :category_id, :categories, null: false, on_delete: :restrict
      String :title, null: false, size: 180
      String :slug, null: false, size: 200, unique: true
      String :description, text: true, null: false
      String :image_url, null: false, size: 500
      Integer :price_cents, null: false
      Integer :original_price_cents
      Integer :discount_percent, null: false, default: 0
      Integer :stock, null: false, default: 0
      TrueClass :featured, null: false, default: false
      TrueClass :active, null: false, default: true
      Integer :position, null: false, default: 0
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      constraint(:products_price_positive) { price_cents > 0 }
      constraint(:products_stock_non_negative) { stock >= 0 }
      constraint(:products_discount_valid) { (discount_percent >= 0) & (discount_percent <= 100) }
    end
    add_index :products, :category_id
    add_index :products, :active

    create_table(:orders) do
      primary_key :id
      String :order_number, null: false, size: 40, unique: true
      String :customer_name, null: false, size: 140
      String :customer_email, null: false, size: 180
      String :shipping_address, text: true, null: false
      String :status, null: false, size: 30, default: "approved"
      Integer :total_cents, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      constraint(:orders_total_positive) { total_cents > 0 }
    end

    create_table(:order_items) do
      primary_key :id
      foreign_key :order_id, :orders, null: false, on_delete: :cascade
      foreign_key :product_id, :products, null: false, on_delete: :restrict
      String :product_title, null: false, size: 180
      Integer :unit_price_cents, null: false
      Integer :quantity, null: false
      Integer :total_cents, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      constraint(:order_items_quantity_positive) { quantity > 0 }
      constraint(:order_items_price_positive) { unit_price_cents > 0 }
      constraint(:order_items_total_positive) { total_cents > 0 }
    end
    add_index :order_items, :order_id

    %w[categories products orders order_items].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_set_updated_at
        AFTER UPDATE ON #{table}
        FOR EACH ROW
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
          UPDATE #{table} SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;
      SQL
    end
  end

  down do
    drop_table(:order_items, :orders, :products, :categories)
  end
end