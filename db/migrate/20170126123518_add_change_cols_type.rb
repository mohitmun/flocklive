class AddChangeColsType < ActiveRecord::Migration
  def change
    change_column :tweets, :from_id, :text
    change_column :tweets, :to_id, :text
  end
end
