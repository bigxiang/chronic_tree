class CreateChronicTreeElements < ActiveRecord::Migration
  def change
    create_table :chronic_tree_elements do |t|
      t.string :tree_type, not_null: true
      t.integer :parent_id, not_null: true
      t.integer :child_id, not_null: true
      t.integer :root_id, not_null: true
      t.integer :distance, not_null: true
      t.datetime :start_time, not_null: true
      t.datetime :end_time, not_null: true
      t.string :scope_name, not_null: true
      t.integer :position

      t.index :tree_type
      t.index :parent_id
      t.index :child_id
      t.index :root_id
      t.index [:start_time, :end_time]
      t.index :scope_name
    end
  end
end
