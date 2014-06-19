require "chronic_tree/version"
require "chronic_tree/active_record/element"
require "set"

module ChronicTree
  require 'chronic_tree/railtie' if defined?(Rails)

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    def chronic_tree(scope_name = 'default')
      self.class_eval <<-RUBY
        attr_reader :current_time_at, :current_scope_name

        @@defined_chronic_tree_scopes = Set.new

        def self.defined_chronic_tree_scopes
          @@defined_chronic_tree_scopes
        end


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
    raise "Scope name is wrong.  It should be equal to the name that has " \
     "been set up." unless self.class.defined_chronic_tree_scopes.include?(scope_name)

    raise "Time can't be later than now." if time_at > Time.now

    @current_time_at = time_at
    @current_scope_name = scope_name

    self
  end

  def children_relation(time_at, scope_name)
    self.send("elements_under_#{scope_name}_parent").
      at(time_at).
      direct.
      exclude_root.
      includes(:child)
  end

  def parent_relation(time_at, scope_name)
    self.send("elements_as_#{scope_name}_child").
      at(time_at).
      direct.
      exclude_root
  end

  def existed_relation(time_at, scope_name)
    self.send("elements_as_#{scope_name}_child").
      at(time_at)
  end

  def descendants_relation(time_at, scope_name)
    children_relation(time_at, scope_name).order(:distance).all_distance
  end

  def ancestors_relation(time_at, scope_name)
    self.send("elements_as_#{scope_name}_child").
      at(time_at).
      includes(:parent).
      order(:distance)
  end

  def tree_scoped_and_timed_relation(time_at, scope_name)
    ChronicTree::ActiveRecord::Element.
      where(scope_name: scope_name).
      at(time_at)
  end

  def children(time_at = Time.now, scope_name = 'default')
    init_tree_args_when_nil(time_at, scope_name)
    children_relation(current_time_at, current_scope_name).map do |el|
      el.child.as_tree(current_time_at, current_scope_name)
    end
  end

  def parent(time_at = Time.now, scope_name = 'default')
    init_tree_args_when_nil(time_at, scope_name)
    child_element = parent_relation(current_time_at, current_scope_name).first
    child_element.parent.as_tree(current_time_at, current_scope_name) if child_element
  end

  def root(time_at = Time.now, scope_name = 'default')
    init_tree_args_when_nil(time_at, scope_name)
    child_element = existed_relation(current_time_at, current_scope_name).first
    child_element.root.as_tree(current_time_at, current_scope_name) if child_element
  end

  def descendants(time_at = Time.now, scope_name = 'default')
    init_tree_args_when_nil(time_at, scope_name)
    descendants_relation(current_time_at, current_scope_name).inject([]) do |result, el|
      result[el.distance - 1] ||= []
      result[el.distance - 1] << el.child.as_tree(current_time_at, current_scope_name)
      result
    end
  end

  def flat_descendants(time_at = Time.now, scope_name = 'default')
    init_tree_args_when_nil(time_at, scope_name)
    descendants_relation(current_time_at, current_scope_name).map do |el|
      el.child.as_tree(current_time_at, current_scope_name)
    end
  end

  def ancestors(time_at = Time.now, scope_name = 'default')
    init_tree_args_when_nil(time_at, scope_name)
    ancestors_relation(current_time_at, current_scope_name).map do |el|
      el.parent.as_tree(current_time_at, current_scope_name)
    end
  end

  alias_method :parent?, :parent

  def empty?(time_at = Time.now, scope_name = 'default')
    tree_scoped_and_timed_relation(time_at, scope_name).empty?
  end

  alias_method :tree_empty?, :empty?

  def existed?(time_at = Time.now, scope_name = 'default')
    existed_relation(time_at, scope_name).any?
  end

  alias_method :existed_in_tree?, :existed?

  def add_as_root(scope_name = 'default')
    raise_error_if_tree_is_not_empty(scope_name) || as_tree(Time.now, scope_name)

    add_root_element

    self
  end

  def add_child(object, scope_name = 'default')
    raise_error_if_scope_set_twice(scope_name) || as_tree(Time.now, scope_name)
    raise_error_if_object_unmatched(object)
    raise_error_if_self_is_not_in_the_tree
    raise "Object must not be in the tree now." if object.existed?(current_time_at, current_scope_name)

    ::ActiveRecord::Base.transaction do
      add_child_element_to_self(object)
      add_child_element_to_each_ancestors(object) unless self == root
    end

    self
  end

  def remove_self(scope_name = 'default')
    raise_error_if_scope_set_twice(scope_name) || as_tree(Time.now, scope_name)
    raise_error_if_self_is_not_in_the_tree

    ::ActiveRecord::Base.transaction do
      remove_self_elements
      remove_descendants_elements
    end

    self
  end

  def remove_descendants(scope_name = 'default')
    raise_error_if_scope_set_twice(scope_name) || as_tree(Time.now, scope_name)
    raise_error_if_self_is_not_in_the_tree

    ::ActiveRecord::Base.transaction { remove_descendants_elements }

    self
  end

  def change_parent(object, scope_name = 'default')
    raise_error_if_scope_set_twice(scope_name) || as_tree(Time.now, scope_name)
    raise_error_if_object_unmatched(object)
    raise_error_if_self_is_not_in_the_tree
    raise "Object must be in the tree now." unless object.existed?(current_time_at, current_scope_name)
  end

  def replace_by(object, scope_name = 'default')
    raise_error_if_scope_set_twice(scope_name) || as_tree(Time.now, scope_name)
    raise_error_if_object_unmatched(object)
    raise_error_if_self_is_not_in_the_tree
    raise "Object must not be in the tree now." if object.existed?(current_time_at, current_scope_name)
  end

  private

    def add_root_element
      send("elements_under_#{current_scope_name}_root").create(
        child: self,
        parent: self,
        distance: 0,
        start_time: current_time_at,
        end_time: 1000.years.since(current_time_at)
      )
    end

    def add_child_element_to_self(object)
      send("elements_under_#{current_scope_name}_parent").create(
        root: root,
        child: object,
        distance: 1,
        start_time: current_time_at,
        end_time: 1000.years.since(current_time_at)
      )
    end

    def add_child_element_to_each_ancestors(object)
      ancestors.each_with_index do |parent_object, index|
        parent_object.send("elements_under_#{current_scope_name}_parent").create(
          root: root,
          child: object,
          distance: index + 2,
          start_time: current_time_at,
          end_time: 1000.years.since(current_time_at)
        )
      end
    end

    def remove_self_elements
      existed_relation(current_time_at, current_scope_name).each do |el|
        el.update_attribute(:end_time, current_time_at)
      end
    end

    def remove_descendants_elements
      flat_descendants(current_time_at, current_scope_name).each do |object|
        object.existed_relation(current_time_at, current_scope_name).each do |el|
          el.update_attribute(:end_time, current_time_at)
        end
      end
    end

    def raise_error_if_object_unmatched(object)
      raise "Object invalid. You can't add two types of objects " \
        "in a tree." if object.class.name != self.class.name

      raise "Object invalid. You must save it first." if object.new_record?
    end

    def raise_error_if_self_is_not_in_the_tree
      raise "Self must be in the tree now." unless existed?(current_time_at, current_scope_name)
    end

    def raise_error_if_tree_is_not_empty(scope_name)
      raise "Tree isn't empty, can't add root element." unless empty?(Time.now, scope_name)
    end

    def raise_error_if_scope_set_twice(scope_name)
      raise "You can't setup scope name multiple times here, use as_tree " \
      "instead." if current_scope_name.present? && scope_name != current_scope_name
    end

    def init_tree_args_when_nil(time_at, scope_name)
      as_tree(time_at, scope_name) if current_time_at.nil? || current_scope_name.nil?
    end
end
