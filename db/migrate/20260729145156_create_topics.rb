class CreateTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :topics do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :topics,
              "LOWER(name)",
              unique: true,
              name: "index_topics_on_lower_name"
  end
end
