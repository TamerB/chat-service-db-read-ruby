class RabbitMqServer < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: -> {return {data: 'not found', status: 404}}
    def initialize
        @connection = Bunny.new(host: ENV.fetch('MQ_HOST'), automatically_recover: false)
        @connection.start
        @channel = @connection.create_channel
        # Message.reindex
    end
    
    def start(queue_name)
        @channel = $channel
        @connection = $connection
        @queue = channel.queue(queue_name)
        @exchange = channel.default_exchange
        subscribe_to_queue
    end
    
    def stop
        channel.close
        connection.close
    end
    
    def loop_forever
        # This loop only exists to keep the main thread
        # alive. Many real world apps won't need this.
        loop { sleep 5 }
    end
    
    private
    
    attr_reader :channel, :exchange, :queue, :connection
    
    def subscribe_to_queue
        queue.subscribe do |_delivery_info, properties, payload|
            result = forward_action(JSON.parse(payload))
            exchange.publish(
            result.to_json,
            routing_key: properties.reply_to,
            correlation_id: properties.correlation_id
            )
        end
    end

    def forward_action(value)
        begin
            case value['action']
            when 'application.show'
                application = Application.where(token: value['params']).first
                return {data: 'application not found', status: 404} if application.nil?
                return {data: {application: application, chats: application.chats.order(created_at: :desc).limit(10)}, status: 200}
            when 'chat.index'
                return {data: 'message not found', status: 404} if Message.where(token: value['params']['application_token']).nil?
                if params['page']
                    chats = Chat.where(token: value['params']['application_token']).order('created_at DESC').page params['page']
                else
                    chats = Chat.where(token: value['params']['application_token']).order('created_at DESC')
                end
                total = Chat.where(token: value['params']['application_token']).count
                return {data: {chats: chats, total: total}, status: 200}
            when 'chat.show'
                chat = Chat.where(token: value['params']['application_token'], number: value['params']['number']).first
                return {data: 'chat not found', status: 404} if chat.nil?
                return {data: {chat: chat, messages: chat.messages.order(created_at: :desc).limit(10)}, status: 200}
            when 'message.index'
                return {data: 'chat not found', status: 404} if Chat.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).nil?
                unless value['params']['page'].nil?
                    messages = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).order('created_at DESC').page value['params']['page']
                else
                    messages = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).order('created_at DESC')
                end
                total = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).count
                return {data: {messages: messages, total: total}, status: 200}
            when 'message.show'
                message = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number'], number: value['params']['number']).first
                return {data: 'message not found', status: 404} if message.nil?
                return {data: message, status: 200}
            when 'message.search'
                response = {}
                unless value['params']['page'].nil?
                    result = Message.search(value['params']['phrase'], fields: [:body], misspellings: {below: 5, edit_distance: 5}, page: value['params']['page'], per_page: 10, where: {
                        token: value['params']['application_token'],
                        chat_number: value['params']['chat_number']
                    })
                else
                    result = Message.search(value['params']['phrase'], fields: [:body], misspellings: {below: 5, edit_distance: 5}, where: {
                        token: value['params']['application_token'],
                        chat_number: value['params']['chat_number']
                    })
                    response[:total] = result.count
                end
                response[:messages] = JSON.parse(result.to_json)['query']
                return {data: 'no results found', status: 404} if response[:messages].nil? or !response[:messages].is_a?(Array)
                return {data: response, status: 200}
            else
                return {data: 'unrecognized operation', status: 400}
            end
        rescue Exception => e
            puts e.message
            return {data: 'no results found', status: 404} if e.class == Searchkick::MissingIndexError
            return {data: 'something went wrong', status: 500}
        end
    end
end