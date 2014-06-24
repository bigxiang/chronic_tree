require 'chronic_tree/command'

module ChronicTree
  module Operation

    class ChangeParent
      attr_reader :source, :source_root_id, :ready_to_move_elements, :new_ancestors

      def initialize(source, new_parent_object)
        @source = source

        @ready_to_move_elements = source.
          descendants_relation(source.current_time_at,
                               source.current_scope_name).map do |el|

          OpenStruct.new(child_id: el.child_id, distance: el.distance + 1)
        end
        @ready_to_move_elements << OpenStruct.new(child_id: source.id, distance: 1)

        @source_root_id = source.root.id

        @new_ancestors = new_parent_object.ancestors
        @new_ancestors.unshift(new_parent_object) unless new_parent_object.id == @source_root_id
      end

      def act
        ::ActiveRecord::Base.transaction do
          ChronicTree::Command::RemoveChildElementsFromAncestors.new(
            source,
            source.ancestors.map(&:id),
            ready_to_move_elements.map(&:child_id)).do

          ChronicTree::Command::AddChildElementsToNewAncestors.new(
            source,
            source_root_id,
            new_ancestors,
            ready_to_move_elements).do
        end

        source
      end
    end

    class ReplaceBy
      attr_reader :source, :target, :source_root_id, :source_ancestors, :ready_to_move_elements

      def initialize(source, target)
        @source = source
        @target = target

        @ready_to_move_elements = source.descendants_relation(
          source.current_time_at,
          source.current_scope_name).map do |el|

          OpenStruct.new(id: el.id, child_id: el.child_id, distance: el.distance)
        end

        @source_root_id = (source == source.root) ? target.id : source.root.id
        @source_ancestors = source.ancestors
      end

      def act
        ::ActiveRecord::Base.transaction do
          remove_obsolete_elements
          add_new_elements
        end

        source
      end

      private

        def remove_obsolete_elements
          ChronicTree::Command::RemoveChildElementsFromAncestors.new(
            source,
            [source.id],
            ready_to_move_elements.map(&:child_id)).do

          ChronicTree::Command::RemoveSelfElement.new(source).do
        end

        def add_new_elements
          if source.id == source_root_id
            target.add_as_root(false)
          else
            ChronicTree::Command::AddReplacedObjToOrigAncestors.new(
              source, source_root_id, source_ancestors, target).do
          end

          ChronicTree::Command::AddChildElementsToReplacedObject.new(
            source, source_root_id, target, ready_to_move_elements).do
        end
    end



    def add_as_root(validate = true)
      as_tree(Time.now, current_scope_name || 'default')

      raise_error_if_tree_is_not_empty if validate

      send("elements_under_#{current_scope_name}_root").create(
        child: self,
        parent: self,
        distance: 0,
        start_time: current_time_at,
        end_time: 1000.years.since(current_time_at)
      )

      self
    end

    def add_child(object)
      as_tree(Time.now, current_scope_name || 'default') && object.as_tree(current_time_at, current_scope_name)

      raise_error_if_object_unmatched(object)
      raise_error_if_self_is_not_in_the_tree
      raise_error_if_object_is_in_the_tree(object)

      ::ActiveRecord::Base.transaction do
        ChronicTree::Command::AddChildElement.new(self, object).do
        ChronicTree::Command::AddChildElementToOrigAncestors.new(self, object).do unless self == root
      end

      self
    end

    def remove_self
      as_tree(Time.now, current_scope_name || 'default')

      raise_error_if_self_is_not_in_the_tree

      ::ActiveRecord::Base.transaction do
        ChronicTree::Command::RemoveSelfElement.new(self).do
        ChronicTree::Command::RemoveDescendantElements.new(self).do
      end

      self
    end

    def remove_descendants
      as_tree(Time.now, current_scope_name || 'default')

      raise_error_if_self_is_not_in_the_tree

      ::ActiveRecord::Base.transaction { ChronicTree::Command::RemoveDescendantElements.new(self).do }

      self
    end

    def change_parent(object)
      as_tree(Time.now, current_scope_name || 'default') && object.as_tree(current_time_at, current_scope_name)
      return self if self != root && parent == object

      raise_error_if_object_unmatched(object)
      raise_error_if_self_is_not_in_the_tree
      raise "Object must be in the tree now." unless object.existed?(current_time_at, current_scope_name)
      raise "Object can't be equal to self." if self == object
      if descendants_relation(current_time_at, current_scope_name).where(child_id: object.id).any?
        raise "Object can't be a child of self."
      end

      ChangeParent.new(self, object).act
    end

    def replace_by(object)
      as_tree(Time.now, current_scope_name || 'default') && object.as_tree(current_time_at, current_scope_name)

      raise_error_if_object_unmatched(object)
      raise_error_if_self_is_not_in_the_tree
      raise_error_if_object_is_in_the_tree(object)

      ReplaceBy.new(self, object).act
    end

    private

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
  end
end
