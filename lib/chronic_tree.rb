require "chronic_tree/version"
require "chronic_tree/active_record/element"
require "chronic_tree/travesal"
require "chronic_tree/operation"
require "chronic_tree/active_record/relation"
require "set"

module ChronicTree
  require 'chronic_tree/railtie' if defined?(Rails)

  class Error < RuntimeError; end
  class InvalidObjectError < Error; end

  include ChronicTree::ActiveRecord::Relation
  include ChronicTree::Travesal
  include ChronicTree::Operation

  def self.included(base)
    base.class_eval <<-RUBY
      attr_reader :current_time_at, :current_scope_name

      @@defined_chronic_tree_scopes = Set.new

      def self.defined_chronic_tree_scopes
        @@defined_chronic_tree_scopes
      end
    RUBY

    base.extend(ClassMethods)
  end

  module ClassMethods

    def chronic_tree(scope_name = 'default')
      self.class_eval <<-RUBY
        has_many :"elements_under_#{scope_name}_parent",
          proc { |owner| where(scope_name: scope_name, tree_type: owner.class.name) },
          class_name: 'ChronicTree::ActiveRecord::Element',
          foreign_key: 'parent_id',
          dependent: :destroy

        has_many :"elements_as_#{scope_name}_child",
          proc { |owner| where(scope_name: scope_name, tree_type: owner.class.name) },
          class_name: 'ChronicTree::ActiveRecord::Element',
          foreign_key: 'child_id',
          dependent: :destroy

        has_many :"elements_under_#{scope_name}_root",
          proc { |owner| where(scope_name: scope_name, tree_type: owner.class.name) },
          class_name: 'ChronicTree::ActiveRecord::Element',
          foreign_key: 'root_id',
          dependent: :destroy
      RUBY

      defined_chronic_tree_scopes << scope_name
    end

  end

  def as_tree(time_at = Time.now, scope_name = 'default')
    time_at, scope_name = Time.now, time_at if time_at.is_a?(String)

    raise "Scope name is wrong.  It should be equal to the name that has " \
     "been set up." unless self.class.defined_chronic_tree_scopes.include?(scope_name)

    raise "Time can't be later than now." if time_at > Time.now

    @current_time_at = time_at
    @current_scope_name = scope_name

    self
  end
end
