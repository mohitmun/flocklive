class AddFlockTokenToUser < ActiveRecord::Migration
  def change
    add_column :users, :flock_token, :text
  end
end
