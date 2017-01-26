class AddColsToTweet2 < ActiveRecord::Migration
  def change
    add_column :tweets, :json_store, :json
  end
end
