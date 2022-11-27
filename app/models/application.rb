class Application < ApplicationRecord
    has_many :chats, foreign_key: :token
end
