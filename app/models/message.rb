class Message < ApplicationRecord
  self.primary_keys = :token, :chat_number, :number
  belongs_to :chat, :foreign_key => [:token, :chat_number]
end
