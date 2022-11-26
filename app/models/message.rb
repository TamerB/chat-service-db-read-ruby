class Message < ApplicationRecord
  searchkick callbacks: false, searchable: [:body], filterable: [:token, :chat_number]
  belongs_to :chat, :foreign_key => [:token, :chat_number]
end
