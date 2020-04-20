class CreateAutoTestPoints < ActiveRecord::Migration[5.2]
  def change
    create_table :auto_test_points do |t|
      t.integer :project_id
      t.text :input
      t.text :expected_output

      t.timestamps
    end
  end
end
