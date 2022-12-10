class Application < ApplicationRecord
    has_many :chats, foreign_key: :token
    paginates_per 10
end
