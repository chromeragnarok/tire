module Tire
  module Model

    # Contains logic for definition of index settings and mappings.
    #
    module Indexing

      module ClassMethods

        # Define [_settings_](http://www.elasticsearch.org/guide/reference/api/admin-indices-create-index.html)
        # for the corresponding index, such as number of shards and replicas, custom analyzers, etc.
        #
        # Usage:
        #
        #     class Article
        #       # ...
        #       settings :number_of_shards => 1 do
        #         mapping do
        #           # ...
        #         end
        #       end
        #     end
        #
        def settings(*args)
          @settings ||= {}
          args.empty?  ? (return @settings) : @settings = args.pop
          yield if block_given?
        end

        # Define the [_mapping_](http://www.elasticsearch.org/guide/reference/mapping/index.html)
        # for the corresponding index, telling _ElasticSearch_ how to understand your documents:
        # what type is which property, whether it is analyzed or no, which analyzer to use, etc.
        #
        # You may pass the top level mapping properties (such as `_source` or `_all`) as a Hash.
        #
        # Usage:
        #
        #     class Article
        #       # ...
        #       mapping :_source => { :compress => true } do
        #         indexes :id,    :index    => :not_analyzed
        #         indexes :title, :analyzer => 'snowball', :boost => 100
        #         indexes :words, :as       => 'content.split(/\W/).length'
        #         # ...
        #       end
        #     end
        #
        def mapping(*args)
          @root_class = Kernel.const_get(document_type.camelize) rescue nil
          @mapping ||= {}
          if block_given?
            @mapping_options = args.pop
            yield
            create_elasticsearch_index
          else
            @mapping
          end
        end

        # Define mapping for the property passed as the first argument (`name`)
        # using definition from the second argument (`options`).
        #
        # `:type` is optional and defaults to `'string'`.
        #
        # Usage:
        #
        # * Index property but do not analyze it: `indexes :id, :index    => :not_analyzed`
        #
        # * Use different analyzer for indexing a property: `indexes :title, :analyzer => 'snowball'`
        #
        # * Use the `:as` option to dynamically define the serialized property value, eg:
        #
        #       :as => 'content.split(/\W/).length'
        #
        # Please refer to the
        # [_mapping_ documentation](http://www.elasticsearch.org/guide/reference/mapping/index.html)
        # for more information.
        #
        def indexes(name, options = {}, &block)
          if block_given?
            @association_class = options[:class] if options[:class]
            options.delete(:class)
            mapping[name] ||= { :type => 'object', :properties => {} }.update(options)
            @_nested_mapping = name
            nested = yield
            @_nested_mapping = nil
            self
          else
            options[:type] ||= 'string'
            if @_nested_mapping
              mapping[@_nested_mapping][:properties][name] = options
              if @association_class
                attribute_name = @_nested_mapping
                root_class = @root_class
                @association_class.set_callback :save, :after do
                  unless self.respond_to? "refresh_#{@root_class.to_s.underscore}_indexes".to_sym
                    self.class.send(:define_method, "refresh_#{root_class.to_s.underscore}_indexes".to_sym) do
                      documents = root_class.where("#{attribute_name}_id".to_sym => self.id)
                      #binding.pry
                      root_class.index.bulk_store documents if documents.any?
                    end
                  end
                  self.send("refresh_#{root_class.to_s.underscore}_indexes".to_sym)
                end

              end
            else
              mapping[name] = options
            end
            self
          end
        end

        # Creates the corresponding index with desired settings and mappings, when it does not exists yet.
        #
        def create_elasticsearch_index
          unless index.exists?
            index.create :mappings => mapping_to_hash, :settings => settings
          end
        rescue Errno::ECONNREFUSED => e
          STDERR.puts "Skipping index creation, cannot connect to ElasticSearch",
                      "(The original exception was: #{e.inspect})"
        end

        def mapping_options
          @mapping_options || {}
        end

        def mapping_to_hash
          { document_type.to_sym => mapping_options.merge({ :properties => mapping }) }
        end

      end

    end

  end
end
