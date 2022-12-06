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
                logger.info "Application show started: #{value['params']}"
                application = Application.where(token: value['params']).first
                if application.nil?
                    logger.warn "Application show not found: #{value['params']}"
                    return {data: 'application not found', status: 404}
                end
                logger.info "Application show completed: #{value['params']}"
                return {data: {application: application, chats: application.chats.order(created_at: :desc).limit(10)}, status: 200}
            when 'chat.index'
                logger.info "Chats index started: #{value['params']}"
                if Message.where(token: value['params']['application_token']).nil?
                    logger.warn "Application not found: #{value['params']}"
                    return {data: 'application not found', status: 404}
                end
                if value['params']['page'].nil?
                    chats = Chat.where(token: value['params']['application_token']).order('created_at DESC')
                else
                    chats = Chat.where(token: value['params']['application_token']).order('created_at DESC').page value['params']['page']
                end
                total = Chat.where(token: value['params']['application_token']).count
                logger.info "Chats index completed: #{value['params']}"
                return {data: {chats: chats, total: total}, status: 200}
            when 'chat.show'
                logger.info "Chat show started: #{value['params']}"
                chat = Chat.where(token: value['params']['application_token'], number: value['params']['number']).first
                if chat.nil?
                    logger.info "Chat not found: #{value['params']}"
                    return {data: 'chat not found', status: 404}
                end
                logger.info "Chat show completed: #{value['params']}"
                return {data: {chat: chat, messages: chat.messages.order(created_at: :desc).limit(10)}, status: 200}
            when 'message.index'
                logger.info "Messages index started: #{value['params']}"
                if Chat.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).nil?
                    logger.warn "Chat not found: #{value['params']}"
                    return {data: 'chat not found', status: 404} 
                end
                if value['params']['page'].nil?
                    messages = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).order('created_at DESC')
                else
                    messages = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).order('created_at DESC').page value['params']['page']
                end
                total = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number']).count
                logger.info "Messages index complete: #{value['params']}"
                return {data: {messages: messages, total: total}, status: 200}
            when 'message.show'
                logger.info "Message show started: #{value['params']}"
                message = Message.where(token: value['params']['application_token'], chat_number: value['params']['chat_number'], number: value['params']['number']).first
                if message.nil?
                    logger.warn "Message show started: #{value['params']}"
                    return {data: 'message not found', status: 404} 
                end    
                logger.info "Message show completed: #{value['params']}"
                return {data: message, status: 200}
            when 'message.search'
                logger.info "Messages search started: #{value['params']}"
                response = {}
                if value['params']['page'].nil?
                    result = Message.search(value['params']['phrase'], fields: [:body], misspellings: {below: 5, edit_distance: 5}, where: {
                        token: value['params']['application_token'],
                        chat_number: value['params']['chat_number']
                    })
                    response[:total] = result.count
                else
                    result = Message.search(value['params']['phrase'], fields: [:body], misspellings: {below: 5, edit_distance: 5}, page: value['params']['page'], per_page: 10, where: {
                        token: value['params']['application_token'],
                        chat_number: value['params']['chat_number']
                    })
                end
                response[:messages] = JSON.parse(result.to_json)['query']
                if response[:messages].nil? or !response[:messages].is_a?(Array)
                    logger.info "Messages search completed (no results found): #{value['params']}"
                    return {data: 'no results found', status: 404}
                end
                logger.info "Messages search completed (success): #{value['params']}"
                return {data: response, status: 200}
            else
                logger.error "Bad request: Unrecognized operation"
                return {data: 'unrecognized operation', status: 400}
            end
        rescue Exception => e
            logger.error e.message
            return {data: 'no results found', status: 404} if e.class == Searchkick::MissingIndexError
            return {data: 'something went wrong', status: 500}
        end
    end
end