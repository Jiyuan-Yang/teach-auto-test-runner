class CreateAutoTestResults < ActiveRecord::Migration[5.2]
  def change
    create_table :auto_test_results do |t|
      t.integer :project_id
      t.integer :user_id
      t.integer :test_point_num
      t.integer :score

      t.timestamps
    end
  end
end
