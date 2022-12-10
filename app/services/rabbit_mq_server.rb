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
    case value['action']
    when 'application.show'
      return show_application(value['params'])
    when 'chat.index'
      return index_chats(value['params'])
    when 'chat.show'
      return show_chat(value['params'])
    when 'message.index'
      return index_messages(value['params'])
    when 'message.show'
      return show_message(value['params'])
    when 'message.search'
      return search_messages(value['params'])
    else
      logger.error "Bad request: Unrecognized operation"
      return {data: 'unrecognized operation', status: 400}
    end
  end

  def show_application(value)
    begin
      logger.info "Application show started: #{value}"
      application = Application.where(token: value).first
      if application.nil?
        logger.warn "Application show not found: #{value}"
        return {data: 'application not found', status: 404}
      end
      logger.info "Application show completed: #{value}"
      return {data: {application: application, chats: application.chats.order(created_at: :desc).limit(10)}, status: 200}
    rescue Exception => e
      return catch_error('Application show', e.message)
    end
  end

  def index_chats(value)
    begin
      logger.info "Chats index started: #{value}"
      if Message.where(token: value['application_token']).nil?
        logger.warn "Application not found: #{value}"
        return {data: 'application not found', status: 404}
      end
      if value['page'].nil?
        chats = Chat.where(token: value['application_token']).order('created_at DESC')
      else
        chats = Chat.where(token: value['application_token']).order('created_at DESC').page value['page']
      end
      total = Chat.where(token: value['application_token']).count
      logger.info "Chats index completed: #{value}"
      return {data: {chats: chats, total: total}, status: 200}
    rescue Exception => e
      return catch_error('Chats index', e.message)
    end
  end

  def show_chat(value)
    begin
      logger.info "Chat show started: #{value}"
      chat = Chat.where(token: value['application_token'], number: value['number']).first
      if chat.nil?
        logger.info "Chat not found: #{value}"
        return {data: 'chat not found', status: 404}
      end
      logger.info "Chat show completed: #{value}"
      return {data: {chat: chat, messages: chat.messages.order(created_at: :desc).limit(10)}, status: 200}
    rescue Exception => e
      return catch_error('Chat show', e.message)
    end
  end

  def index_messages(value)
    begin
      logger.info "Messages index started: #{value}"
      if Chat.where(token: value['application_token'], chat_number: value['chat_number']).nil?
        logger.warn "Chat not found: #{value}"
        return {data: 'chat not found', status: 404} 
      end
      if value['page'].nil?
        messages = Message.where(token: value['application_token'], chat_number: value['chat_number']).order('created_at DESC')
      else
        messages = Message.where(token: value['application_token'], chat_number: value['chat_number']).order('created_at DESC').page value['page']
      end
      total = Message.where(token: value['application_token'], chat_number: value['chat_number']).count
      logger.info "Messages index complete: #{value}"
      return {data: {messages: messages, total: total}, status: 200}
    rescue Exception => e
      return catch_error('Messages index', e.message)
    end
  end

  def show_message(value)
    begin
      logger.info "Message show started: #{value}"
      message = Message.where(token: value['application_token'], chat_number: value['chat_number'], number: value['number']).first
      if message.nil?
        logger.warn "Message show started: #{value}"
        return {data: 'message not found', status: 404} 
      end    
      logger.info "Message show completed: #{value}"
      return {data: message, status: 200}
    rescue Exception => e
      return catch_error('Message show', e.message)
    end
  end

  def search_messages(value)
    begin
      logger.info "Messages search started: #{value}"
      response = {}
      if value['page'].nil?
        result = Message.search(value['phrase'], fields: [:body], misspellings: {below: 5, edit_distance: 5}, where: {
          token: value['application_token'],
          chat_number: value['chat_number']
        })
        response[:total] = result.count
      else
        result = Message.search(value['phrase'], fields: [:body], misspellings: {below: 5, edit_distance: 5}, page: value['page'], per_page: 10, where: {
          token: value['application_token'],
          chat_number: value['chat_number']
        })
      end
      response[:messages] = JSON.parse(result.to_json)['query']
      if response[:messages].nil? or !response[:messages].is_a?(Array)
        logger.info "Messages search completed (no results found): #{value}"
        return {data: 'no results found', status: 404}
      end
      logger.info "Messages search completed (success): #{value}"
      return {data: response, status: 200}
    rescue Exception => e
      if e.class == Searchkick::MissingIndexError
        logger.error "message search cancelled: #{e.message}"
        return {data: 'no results found', status: 404}
      end
      return catch_error('Messages search', e.message)
    end
  end

  def catch_error(prefix, err)
    logger.error "#{prefix} cancelled: #{err}"
    return {data: 'something went wrong. Please try again later', status: 500}
  end
end