require "chronic_tree/version"
require "chronic_tree/active_record/element"
require "set"
require "pry"

module ChronicTree
  require 'chronic_tree/railtie' if defined?(Rails)

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

  def add_as_root(scope_name = 'default', validate = true)
    init_tree_args_when_nil(Time.now, scope_name)

    raise_error_if_tree_is_not_empty if validate

    add_root_element

    self
  end

  def add_child(object, scope_name = 'default')
    init_tree_args_when_nil(Time.now, scope_name)

    add_child_or_replace_by_args_valid?(object)

    ::ActiveRecord::Base.transaction do
      add_child_element_to_self(object)
      add_child_element_to_orig_ancestors(object) unless self == root
    end

    self
  end

  def remove_self(scope_name = 'default')
    init_tree_args_when_nil(Time.now, scope_name)

    raise_error_if_self_is_not_in_the_tree

    ::ActiveRecord::Base.transaction do
      remove_self_elements
      remove_descendants_elements
    end

    self
  end

  def remove_descendants(scope_name = 'default')
    init_tree_args_when_nil(Time.now, scope_name)

    raise_error_if_self_is_not_in_the_tree

    ::ActiveRecord::Base.transaction { remove_descendants_elements }

    self
  end

  def change_parent(object, scope_name = 'default')
    init_tree_args_when_nil(Time.now, scope_name)
    return self if self != root && parent == object

    change_parent_args_valid?(object)

    # Must get variables first before the tree changed.
    ready_to_move_elements = descendants_relation(current_time_at, current_scope_name).map do |el|
      OpenStruct.new(child_id: el.child_id, distance: el.distance + 1)
    end
    ready_to_move_elements << OpenStruct.new(child_id: self.id, distance: 1)
    root_id = root.id
    new_ancestors = object.ancestors(current_time_at, current_scope_name)
    new_ancestors.unshift(object) unless object == root

    ::ActiveRecord::Base.transaction do
      remove_child_elements_from_ancestors(ancestors.map(&:id), ready_to_move_elements.map(&:child_id))
      add_child_elements_to_new_ancestors(new_ancestors, ready_to_move_elements, root_id)
    end

    self
  end

  def replace_by(object, scope_name = 'default')
    init_tree_args_when_nil(Time.now, scope_name)

    add_child_or_replace_by_args_valid?(object)

    # Must get variables first before the tree changed.
    ready_to_move_elements = descendants_relation(current_time_at, current_scope_name).
      select(:id, :child_id, :distance).load
    root_obj = (self == root) ? object : root
    ancestor_objects = ancestors

    ::ActiveRecord::Base.transaction do
      remove_child_elements_from_ancestors([self.id], ready_to_move_elements.map(&:child_id))
      remove_self_elements

      if self == root
        object.add_as_root(current_scope_name, false)
        add_child_elements_to_replaced_object(object, root_obj, ready_to_move_elements)
      else
        add_replaced_object_to_orig_ancestors(object, root_obj, ancestor_objects)
        add_child_elements_to_replaced_object(object, root_obj, ready_to_move_elements)
      end
    end

    self
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

    def add_child_element_to_orig_ancestors(object)
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

    def remove_child_elements_from_ancestors(ancestor_ids, children_ids)
      ChronicTree::ActiveRecord::Element.at(current_time_at).
        where(tree_type: self.class.name).
        where(scope_name: current_scope_name).
        where(parent_id: ancestor_ids).
        where(child_id: children_ids).
        update_all(end_time: current_time_at)
    end

    def add_child_elements_to_new_ancestors(new_ancestors, child_elements, root_id)
      new_ancestors.each_with_index do |parent_object, i|
        child_elements.each do |e|
          parent_object.send("elements_under_#{current_scope_name}_parent").create(
            start_time: current_time_at,
            end_time: 1000.years.since(current_time_at),
            child_id: e.child_id,
            root_id: root_id,
            distance: e.distance + i
          )
        end
      end
    end

    def add_replaced_object_to_orig_ancestors(object, root_obj, ancestor_objects)
      ancestor_objects.each_with_index do |parent_object, i|
        parent_object.send("elements_under_#{current_scope_name}_parent").create(
          root: root_obj,
          child: object,
          distance: i + 1,
          start_time: current_time_at,
          end_time: 1000.years.since(current_time_at)
        )
      end
    end

    def add_child_elements_to_replaced_object(object, root_obj, child_elements)
      child_elements.each do |el|
        object.send("elements_under_#{current_scope_name}_parent").create(
          root: root_obj,
          child_id: el.child_id,
          distance: el.distance,
          start_time: current_time_at,
          end_time: 1000.years.since(current_time_at)
        )
      end
    end

    def add_child_or_replace_by_args_valid?(object)
      raise_error_if_object_unmatched(object)
      raise_error_if_self_is_not_in_the_tree
      raise_error_if_object_is_in_the_tree(object)
    end

    def change_parent_args_valid?(object)
      raise_error_if_object_unmatched(object)
      raise_error_if_self_is_not_in_the_tree
      raise "Object must be in the tree now." unless object.existed?(current_time_at, current_scope_name)
      raise "Object can't be equal to self." if self == object
      if descendants_relation(current_time_at, current_scope_name).where(child_id: object.id).any?
        raise "Object can't be a child of self."
      end
    end

    def raise_error_if_object_unmatched(object)
      raise "Object invalid. You can't add two types of objects " \
        "in a tree." if object.class.name != self.class.name

      raise "Object invalid. You must save it first." if object.new_record?
    end

    def raise_error_if_object_is_in_the_tree(object)
      raise "Object must not be in the tree now." if object.existed?(current_time_at, current_scope_name)
    end

    def raise_error_if_self_is_not_in_the_tree
      raise "Self must be in the tree now." unless existed?(current_time_at, current_scope_name)
    end

    def raise_error_if_tree_is_not_empty
      raise "Tree isn't empty, can't add root element." unless empty?(current_time_at, current_scope_name)
    end

    def init_tree_args_when_nil(time_at, scope_name)
      as_tree(time_at, scope_name) if current_time_at.nil? || current_scope_name.nil?
    end
end
