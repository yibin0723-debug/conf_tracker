class AddTrackingFieldsToConferences < ActiveRecord::Migration[8.1]
  def change
    add_column :conferences, :submission_deadline, :date
    add_column :conferences, :rating, :string

    add_index :conferences, :submission_deadline
  end
end
