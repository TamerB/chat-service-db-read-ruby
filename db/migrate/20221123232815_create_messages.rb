class CreateMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :messages, primary_key: [:token, :chat_number, :number] do |t|
      t.string :token, foreign_key: true, null: false
      t.integer :chat_number, foreign_key: true, null: false, type: :integer
      t.integer :number, default: 1, null: false
      t.integer :messages_number, default: 0, null: false
      t.text :body, null: false

      t.timestamps
    end
    add_index :messages, [:token, :chat_number]
  end
end
