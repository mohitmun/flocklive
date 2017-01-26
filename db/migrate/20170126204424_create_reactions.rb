class CreateReactions < ActiveRecord::Migration
  def change
    create_table :reactions do |t|
      t.text :reaction_type
      t.integer :item_id
      t.text :item_type

      t.timestamps null: false
    end
  end
end
