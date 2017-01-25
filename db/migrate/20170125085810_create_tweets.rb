class CreateTweets < ActiveRecord::Migration
  def change
    create_table :tweets do |t|
      t.text :content
      t.integer :score
      t.text :from
      t.text :to

      t.timestamps null: false
    end
  end
end
