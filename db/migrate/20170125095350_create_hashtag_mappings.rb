class CreateHashtagMappings < ActiveRecord::Migration
  def change
    create_table :hashtag_mappings do |t|
      t.integer :tweet_id
      t.integer :hashtag_id

      t.timestamps null: false
    end
  end
end
