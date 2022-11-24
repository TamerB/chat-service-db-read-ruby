class RabbitMqServer < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: -> {return {data: 'not found', status: 404}}
    def initialize
        @connection = Bunny.new
        @connection.start
        @channel = @connection.create_channel
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
        case value['action']
        when 'application.show'
            application = Application.where(token: value['params']).includes(:chats).first
            return {data: {application: application, chats: application.chats}, status: 200}
        when 'chat.show'
            chat = Chat.where(token: value['params']['application_token'], number: value['params']['number']).includes(:messages).first
            return {data: {chat: chat, messages: chat.messages}, status: 200}
        when 'message.index'
            messages = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).order('created_at')
            return {data: {messages: messages, total: messages.length}, status: 200}
        when 'message.show'
            message = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number'], number: value['params']['number']).first
            return {data: message, status: 200}
        else
            return {data: 'unrecognized operation', status: 400}
        end
    end
end