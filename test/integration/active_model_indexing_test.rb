require 'test_helper'
require 'active_record'
require 'pry'

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

    class ::AssociatedModel < ActiveRecord::Base
      include Tire::Model::Search
      include Tire::Model::Callbacks

      has_many :articles,    :class_name => "ActiveModelArticleWithAssociation",    :foreign_key => "article_id"

      mapping do
        indexes :first_name
        indexes :last_name
      end
    end

    class ::ActiveModelArticleWithAssociation < ActiveRecord::Base
      include Tire::Model::Search
      include Tire::Model::Callbacks

      mapping do
        indexes :title
        indexes :content
        indexes :associated_model, :class => AssociatedModel do
          indexes :first_name
        end
      end

      def to_indexed_json
        {
          :title   => title,
          :content => content,
          :associated_model  => {
            :first_name => AssociatedModel.find(associated_model_id).first_name,
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
        ActiveRecord::Base.establish_connection( :adapter => 'sqlite3', :database => ":memory:" )

        ActiveRecord::Migration.verbose = false
        ActiveRecord::Schema.define(:version => 1) do
          create_table :associated_models do |t|
            t.string   :first_name
            t.string   :last_name
          end
          create_table :active_model_article_with_associations do |t|
            t.string     :title
            t.text       :content
            t.integer    :associated_model_id
          end
        end

        ActiveModelArticleWithAssociation.destroy_all
        AssociatedModel.destroy_all

        @associated_model = AssociatedModel.create :first_name => 'Jack', :last_name => 'Doe'
        @model = ActiveModelArticleWithAssociation.create \
          :title => 'Sample Title',
          :content => 'Test article',
          :associated_model_id => @associated_model.id
      end

      context 'without delayed job' do
        setup do
          Tire.configure {
            nested_attributes do
              nest :associated_model => :active_model_article_with_association
            end
          }
        end

        should "update the index if associated model is updated" do
          @associated_model.first_name = 'Jim'
          @associated_model.save
          sleep(2)
          m = ActiveModelArticleWithAssociation.search('*').first
          assert_equal @associated_model.first_name, m.associated_model.first_name
        end
      end

      context 'with delayed job' do
        setup do
          module Tire::Job::ReindexJob::Delayed
            class Job
              def self.enqueue(*args)
                args.pop.perform
              end
            end
          end

          Tire.configure {
            nested_attributes :delayed_job => true do
              nest :associated_model => :active_model_article_with_association
            end
          }
        end

        #should "call the queue method" do
        #  mock_class = mock(:class)
        #  mock_class.responds_like(Class)
        #  mock_class.expects(:queue).once
        #  Tire::Job::ReindexJob = mock_class
        #end

        should "update the index if associated model is updated" do
          @associated_model.first_name = 'Jim'
          @associated_model.save
          sleep(2)
          m = ActiveModelArticleWithAssociation.search('*').first
          assert_equal @associated_model.first_name, m.associated_model.first_name
        end
      end
    end

  end
end
