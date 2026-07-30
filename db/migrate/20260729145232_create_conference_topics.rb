class CreateConferenceTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :conference_topics do |t|
      t.references :conference, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true

      t.timestamps
    end

    add_index :conference_topics,
              %i[conference_id topic_id],
              unique: true,
              name: "index_conference_topics_on_conference_and_topic"
  end
end
