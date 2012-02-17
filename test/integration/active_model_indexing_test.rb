require 'test_helper'

module Tire

  class ActiveModelSearchableIntegrationTest < Test::Unit::TestCase
    include Test::Integration

    class ::ActiveModelArticleWithCustomAsSerialization < ActiveModelArticleWithCallbacks
      mapping do
        indexes :title
        indexes :content
        indexes :characters,  :as => 'content.length'
        indexes :readability, :as => proc {
                                       content.split(/\W/).reject { |t| t.blank? }.size /
                                       content.split(/\./).size
                                     }
      end
    end

    class ::AssociatedModel < ActiveModelArticleWithCallbacks
      mapping do
        indexes :first_name
        indexes :last_name
      end

      def first_name=(first_name)
        @attributes[:first_name] = first_name
      end
    end

    class ::ActiveModelArticleWithAssociation < ActiveModelArticleWithCallbacks
      mapping do
        indexes :title
        indexes :content
        indexes :author, :class => AssociatedModel do
          indexes :first_name
        end
      end

      def to_indexed_json
        {
          :title   => title,
          :content => content,
          :author  => {
            :first_name => author.first_name,
          }
        }.to_json
      end
    end

    def setup
      super
      ActiveModelArticleWithCustomAsSerialization.index.delete
    end

    def teardown
      super
      ActiveModelArticleWithCustomAsSerialization.index.delete
    end

    context "ActiveModel serialization" do

      setup do
        @model = ActiveModelArticleWithCustomAsSerialization.new \
                   :id      => 1, 
                   :title   => 'Test article',
                   :content => 'Lorem Ipsum. Dolor Sit Amet.'
        @model.update_index
        @model.index.refresh
      end

      should "serialize the content length" do
        m = ActiveModelArticleWithCustomAsSerialization.search('*').first
        assert_equal 28, m.characters
        assert_equal 2,  m.readability
      end

    end

    context "ActiveModel serialization with association" do

      setup do
        #AssociatedModel.any_instance.stubs(:where).returns([@model])
        @associated_model = AssociatedModel.new :id => 1, :first_name => 'Jack', :last_name => 'Doe'
        @model = ActiveModelArticleWithAssociation.new \
          :title => 'Sample Title',
          :content => 'Test article',
          :author => @associated_model
        @model.id = "1"
        @associated_model.id = "1"
        @associated_model.class.expects(:where).returns([@model]).at_least_once
        @associated_model.save
        @model.save
      end

      should "do something" do
        @associated_model.first_name = 'Jim'
        @associated_model.save
        sleep(2)
        m = ActiveModelArticleWithAssociation.search('*').first
        assert_equal @associated_model.first_name, m.author.first_name
      end

    end

  end
end
