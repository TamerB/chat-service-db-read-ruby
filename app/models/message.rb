class Message < ApplicationRecord
  searchkick callbacks: false, searchable: [:body], filterable: [:token, :chat_number]
  belongs_to :chat, :foreign_key => [:token, :chat_number]
  paginates_per 10

  def search_data
    {
      body: body,
      token: token,
      chat_number: chat_number,
      id: id
    }
  end
end
