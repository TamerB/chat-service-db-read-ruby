class Chat < ApplicationRecord
  self.primary_keys = :token, :number
  belongs_to :application, foreign_key: :token
  has_many :messages, :foreign_key => [:token, :chat_number]
end
