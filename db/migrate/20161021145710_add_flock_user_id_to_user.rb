class AddFlockUserIdToUser < ActiveRecord::Migration
  def change
    add_column :users, :flock_user_id, :text
  end
end
