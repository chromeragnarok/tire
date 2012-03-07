module Tire
  module Job
    class ReindexJob
      def initialize(hash)
        @classes = hash
      end

      def perform
        associated_class = Kernel.const_get(@classes.keys.first.to_s.camelcase)
        #unless hash.values.first.respond_to?(:size)
        #  root_classes = [hash.values.first.to_s.camelcase]
        #else
        #  root_classes = hash.values.first
        #end

        root_classes = [@classes.values.first.to_s.camelcase]

        root_classes.each do |root_class_sym|
          root_class = Kernel.const_get(root_class_sym.to_s.camelcase)
          unless associated_class.respond_to? "refresh_#{root_class.to_s.underscore}_indexes".to_sym
            associated_class.set_callback :save, :after do
              self.class.send(:define_method, "refresh_#{root_class.to_s.underscore}_indexes".to_sym) do
                documents = root_class.where("#{associated_class.to_s.underscore}_id".to_sym => self.id)
                root_class.index.bulk_store documents if documents.any?
              end
              self.send("refresh_#{root_class.to_s.underscore}_indexes".to_sym)
            end
          end
        end
      end

      def self.queue(hash)
        Delayed::Job.enqueue(ReindexJob.new(hash))
      end

    end
  end
end