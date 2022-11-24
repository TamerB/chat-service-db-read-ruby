class CreateChats < ActiveRecord::Migration[7.0]
  def change
    create_table :chats, primary_key: [:token, :number] do |t|
      t.string :token, references: :applications, null: false
      t.integer :number, default: 1, null: false
      t.integer :messages_number, default: 0, null: false

      t.timestamps
    end
    add_foreign_key :chats, :applications, column: :token, primary_key: :token, on_delete: :cascade
  end
end
