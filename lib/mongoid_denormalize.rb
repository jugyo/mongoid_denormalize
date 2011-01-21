require File.dirname(__FILE__) + '/railties/railtie' if defined?(Rails::Railtie)

# = Mongoid::Denormalize
#
# Helper module for denormalizing association attributes in Mongoid models.
module Mongoid::Denormalize
  extend ActiveSupport::Concern
  
  included do
    cattr_accessor :denormalize_definitions
    
    before_save :denormalize_from
    before_save :store_changes_for_denormalize
    after_save :denormalize_to
  end

  module ClassMethods
    # Set a field or a number of fields to denormalize. Specify the associated object using the :from or :to options.
    #
    #   def Post
    #     include Mongoid::Document
    #     include Mongoid::Denormalize
    #
    #     referenced_in :user
    #     references_many :comments
    #
    #     denormalize :name, :avatar, :from => :user
    #     denormalize :created_at, :to => :comments
    #   end
    def denormalize(*fields)
      options = fields.pop
      
      (self.denormalize_definitions ||= []) << { :fields => fields, :options => options }

      # Define schema
      unless options[:to]
        fields.each { |name| field "#{options[:from]}_#{name}", :type => options[:type] }
      end
    end
  end

  def denormalized_valid?
    denormalize_from
    !self.changed?
  end

  def repair_denormalized!
    self.save! unless denormalized_valid?
  end

  private
    def store_changes_for_denormalize
      @changes_for_denormalize = changes.dup
    end

    def denormalize_from
      self.denormalize_definitions.each do |definition|
        next if definition[:options][:to]
        
        definition[:fields].each { |name| self.send("#{definition[:options][:from]}_#{name}=", self.send(definition[:options][:from]).try(name)) }
      end
    end
    
    def denormalize_to
      self.denormalize_definitions.each do |definition|
        next unless definition[:options][:to]
        
        next unless definition[:fields].any? { |f| @changes_for_denormalize.keys.include?(f.to_s) }

        assigns = Hash[*definition[:fields].collect { |name| ["#{self.class.name.underscore}_#{name}", self.send(name)] }.flatten]
        
        [definition[:options][:to]].flatten.each do |association|
          if [:embedded_in, :embeds_one, :referenced_in, :references_one].include? self.class.reflect_on_association(association)
            self.send(association).update_attributes(assigns) unless self.send(association).blank?
          else
            self.send(association).to_a.each { |a| a.update_attributes(assigns) }
          end
        end
      end
    end
end