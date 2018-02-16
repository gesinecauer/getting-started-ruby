# [START pub_sub_enqueue]
require "google/cloud/pubsub"

module ActiveJob
  module QueueAdapters
    class PubSubQueueAdapter

      def self.pubsub
        project_id = Rails.application.config.x.settings["project_id"]
        Google::Cloud::Pubsub.new project_id: project_id
      end

      def self.enqueue job
        Rails.logger.info "[PubSubQueueAdapter] enqueue job #{job.inspect}"

        book  = job.arguments.first

        topic = pubsub.topic "lookup_book_details_queue"

        topic.publish book.id.to_s
      end
# [END pub_sub_enqueue]

      # TODO add queue parameter

      # [START pub_sub_worker]
      def self.run_worker!
        Rails.logger.info "Running worker to lookup book details"

        topic = pubsub.topic "lookup_book_details_queue"
        if topic.nil?
          topic = pubsub.create_topic "lookup_book_details_queue"
        end

        subscription = topic.subscription "lookup_book_details"
        if subscription.nil?
          subscription = topic.create_subscription "lookup_book_details"
        end

        subscriber = subscription.listen do |message|
          message.acknowledge!

          Rails.logger.info "Book lookup request (#{message.data})"

          book_id = message.data.to_i
          book    = Book.find_by_id book_id

          LookupBookDetailsJob.perform_now book if book
        end

        # Start background threads that will call block passed to listen.
        subscriber.start

        loop do
          sleep 10
        end
      end
      # [END pub_sub_worker]

    end
  end
end
