class AddColsToTweet < ActiveRecord::Migration
  def change
    add_column :tweets, :from_id, :integer
    add_column :tweets, :to_id, :integer
  end
end
