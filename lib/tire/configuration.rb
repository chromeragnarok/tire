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

    def self.nested_attributes(*args)
      options = args.pop
      if(options && options[:delayed_job])
        @delayed_job = true
      else
        @delayed_job = false
      end
      if block_given?
        yield
      end
    end

    def self.nest(hash)
      if @delayed_job
        Tire::Job::ReindexJob.queue(hash)
      else
        Tire::Job::ReindexJob.new(hash).perform
      end
    end
  end

end
