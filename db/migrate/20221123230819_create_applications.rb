class CreateApplications < ActiveRecord::Migration[7.0]
  def change
    create_table :applications, id: false do |t|
      t.string :token, null: false, primary_key: true
      t.string :name, null: false
      t.integer :chats_number, default: 0, null: false

      t.timestamps
    end
  end
end
