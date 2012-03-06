module Tire

  class Configuration

    def self.url(value=nil)
      @url    = (value ? value.to_s.gsub(%r|/*$|, '') : nil) || @url || "http://localhost:9200"
    end

    def self.client(klass=nil)
      @client = klass || @client || HTTP::Client::RestClient
    end

    def self.wrapper(klass=nil)
      @wrapper = klass || @wrapper || Results::Item
    end

    def self.logger(device=nil, options={})
      return @logger = Logger.new(device, options) if device
      @logger || nil
    end

    def self.reset(*properties)
      reset_variables = properties.empty? ? instance_variables : instance_variables.map { |p| p.to_s} & \
                                                                 properties.map         { |p| "@#{p}" }
      reset_variables.each { |v| instance_variable_set(v.to_sym, nil) }
    end

    def self.nested_attributes(&block)
      yield
    end

    def self.nest(hash)
      associated_class = Kernel.const_get(hash.keys.first.to_s.camelcase)
      #unless hash.values.first.respond_to?(:size)
      #  root_classes = [hash.values.first.to_s.camelcase]
      #else
      #  root_classes = hash.values.first
      #end

      root_classes = [hash.values.first.to_s.camelcase]

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
  end

end
