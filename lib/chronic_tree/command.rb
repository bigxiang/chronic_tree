module ChronicTree
  module Command

    class AddChildElement
      attr_reader :source, :child_id, :distance, :source_root_id

      def initialize(source, child_object_or_child_id, distance = 1, source_root_id = nil)
        @source = source
        @source_root_id = if source_root_id.nil?
          source.root.id
        else
          source_root_id
        end

        @distance = distance

        @child_id = if child_object_or_child_id.respond_to?(:id)
          child_object_or_child_id.send(:id)
        else
          child_object_or_child_id
        end
      end

      def do
        source.send("elements_under_#{source.current_scope_name}_parent").create(
          root_id: source_root_id,
          child_id: child_id,
          distance: distance,
          start_time: source.current_time_at,
          end_time: 1000.years.since(source.current_time_at)
        )
      end
    end

    class RemoveChildElementsFromAncestors
      attr_reader :ancestor_ids, :child_ids, :source

      def initialize(source, ancestor_ids, child_ids)
        @source = source
        @ancestor_ids = ancestor_ids
        @child_ids = child_ids
      end

      def do
        ChronicTree::ActiveRecord::Element.at(source.current_time_at).
          where(tree_type: source.class.name).
          where(scope_name: source.current_scope_name).
          where(parent_id: ancestor_ids).
          where(child_id: child_ids).
          update_all(end_time: source.current_time_at)
      end
    end

    class AddChildElementsToNewAncestors
      attr_reader :source, :source_root_id, :new_ancestors, :child_elements

      def initialize(source, source_root_id, new_ancestors, child_elements)
        @source = source
        @source_root_id = source_root_id
        @new_ancestors = new_ancestors
        @child_elements = child_elements
      end

      def do
        new_ancestors.each_with_index do |parent_object, i|
          child_elements.each do |e|
            AddChildElement.new(parent_object, e.child_id, e.distance + i, source_root_id).do
          end
        end
      end
    end

    class AddChildElementToOrigAncestors
      attr_reader :source, :child

      def initialize(source, child)
        @source = source
        @child = child
      end

      def do
        source.ancestors.each_with_index do |parent_object, index|
          AddChildElement.new(parent_object, child, index + 2, source.root.id).do
        end
      end
    end

    class AddReplacedObjToOrigAncestors
      attr_reader :source, :source_root_id, :source_ancestors, :target

      def initialize(source, source_root_id, source_ancestors, target)
        @source = source
        @source_root_id = source_root_id
        @source_ancestors = source_ancestors
        @target = target
      end

      def do
        source_ancestors.each_with_index do |parent_object, i|
          AddChildElement.new(parent_object, target.id, i + 1, source_root_id).do
        end
      end
    end

    class AddChildElementsToReplacedObject
      attr_reader :source, :source_root_id, :target, :child_elements

      def initialize(source, source_root_id, target, child_elements)
        @source = source
        @source_root_id = source_root_id
        @target = target
        @child_elements = child_elements
      end

      def do
        child_elements.each { |el| AddChildElement.new(target, el.child_id, el.distance).do }
      end
    end

    class RemoveSelfElement
      attr_reader :source

      def initialize(source)
        @source = source
      end

      def do
        source.existed_relation(source.current_time_at, source.current_scope_name).each do |el|
          el.update_attribute(:end_time, source.current_time_at)
        end
      end
    end

    class RemoveDescendantElements
      attr_reader :source

      def initialize(source)
        @source = source
      end

      def do
        source.flat_descendants.each { |object| RemoveSelfElement.new(object).do }
      end
    end

  end
end
