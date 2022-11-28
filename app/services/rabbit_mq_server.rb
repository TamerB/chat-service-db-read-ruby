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
                application = Application.where(token: value['params']).includes(:chats).first
                return {data: {application: application, chats: application.chats}, status: 200}
            when 'chat.show'
                chat = Chat.where(token: value['params']['application_token'], number: value['params']['number']).includes(:messages).first
                return {data: 'chat not found', status: 404} if chat.nil?
                return {data: {chat: chat, messages: chat.messages}, status: 200}
            when 'message.index'
                return {data: 'chat not found', status: 404} if Chat.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).nil?
                messages = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).order('created_at')
                return {data: {messages: messages, total: messages.length}, status: 200}
            when 'message.show'
                message = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number'], number: value['params']['number']).first
                return {data: 'message not found', status: 404} if message.nil?
                return {data: message, status: 200}
            when 'message.search'
                result = Message.search(value['params']['phrase'], fields: [:body], misspellings: {below: 5, edit_distance: 2}, where: {
                    token: value['params']['application_token'],
                    chat_number: value['params']['chat_number']
                })
                responseHash = JSON.parse(result.to_json)
                return {data: responseHash['query'], status: 200}
            else
                return {data: 'unrecognized operation', status: 400}
            end
        rescue Exception => e
            puts e
            return {data: 'something went wrong 12358', status: 500}
        end
    end
end