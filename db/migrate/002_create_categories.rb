# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps null: false
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :name, unique: true
  end
end