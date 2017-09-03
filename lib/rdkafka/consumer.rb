module Rdkafka
  class Consumer
    include Enumerable

    def initialize(native_kafka)
      @native_kafka = native_kafka
    end

    def close
      Rdkafka::FFI.rd_kafka_consumer_close(@native_kafka)
    end

    def subscribe(*topics)
      # Create topic partition list with topics and no partition set
      tpl = Rdkafka::FFI.rd_kafka_topic_partition_list_new(topics.length)
      topics.each do |topic|
        Rdkafka::FFI.rd_kafka_topic_partition_list_add(
          tpl,
          topic,
          -1
        )
      end
      # Subscribe to topic partition list and check this was successful
      response = Rdkafka::FFI.rd_kafka_subscribe(@native_kafka, tpl)
      if response != 0
        raise Rdkafka::RdkafkaError.new(response)
      end
    ensure
      # Clean up the topic partition list
      Rdkafka::FFI.rd_kafka_topic_partition_list_destroy(tpl)
    end

    def commit(async=false)
      response = Rdkafka::FFI.rd_kafka_commit(@native_kafka, nil, async)
      if response != 0
        raise Rdkafka::RdkafkaError.new(response)
      end
    end

    def poll(timeout_ms)
      message_ptr = Rdkafka::FFI.rd_kafka_consumer_poll(@native_kafka, timeout_ms)
      if message_ptr.null?
        nil
      else
        # Create struct wrapper
        native_message = Rdkafka::FFI::Message.new(message_ptr)
        # Raise error if needed
        if native_message[:err] != 0
          raise Rdkafka::RdkafkaError.new(native_message[:err])
        end
        # Create a message to pass out
        Rdkafka::Message.new(native_message)
      end
    ensure
      # Clean up rdkafka message if there is one
      unless message_ptr.null?
        Rdkafka::FFI.rd_kafka_message_destroy(message_ptr)
      end
    end

    def each(&block)
      loop do
        message = poll(250)
        if message
          block.call(message)
        else
          next
        end
      end
    end
  end
end
