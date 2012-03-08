module Tire
  module Job
    class ReindexJob
      require 'delayed_job'

      def initialize(root_class, associated_class, instance_id)
        @associated_class = associated_class
        @root_class = root_class
        @instance_id = instance_id
      end

      def perform
        documents = @root_class.where("#{@associated_class.to_s.underscore}_id".to_sym => @instance_id)
        @root_class.index.bulk_store documents if documents.any?
      end

      def self.queue(root_class, associated_class, instance_id)
        Delayed::Job.enqueue(ReindexJob.new(root_class, associated_class, instance_id))
      end
    end
  end
end