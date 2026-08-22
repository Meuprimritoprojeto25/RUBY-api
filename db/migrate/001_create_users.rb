# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "buyer"
      t.timestamps null: false
    end

    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
  end
end