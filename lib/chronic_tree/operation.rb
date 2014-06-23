module ChronicTree
  module Operation
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
        add_child_element_to_self(object)
        add_child_element_to_orig_ancestors(object) unless self == root
      end

      self
    end

    def remove_self
      as_tree(Time.now, current_scope_name || 'default')

      raise_error_if_self_is_not_in_the_tree

      ::ActiveRecord::Base.transaction do
        remove_self_elements
        remove_descendants_elements
      end

      self
    end

    def remove_descendants
      as_tree(Time.now, current_scope_name || 'default')

      raise_error_if_self_is_not_in_the_tree

      ::ActiveRecord::Base.transaction { remove_descendants_elements }

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

      # Must get variables first before the tree changed.
      ready_to_move_elements = descendants_relation(current_time_at, current_scope_name).map do |el|
        OpenStruct.new(child_id: el.child_id, distance: el.distance + 1)
      end
      ready_to_move_elements << OpenStruct.new(child_id: self.id, distance: 1)
      root_id = root.id
      new_ancestors = object.ancestors
      new_ancestors.unshift(object) unless object == root

      ::ActiveRecord::Base.transaction do
        remove_child_elements_from_ancestors(ancestors.map(&:id), ready_to_move_elements.map(&:child_id))
        add_child_elements_to_new_ancestors(new_ancestors, ready_to_move_elements, root_id)
      end

      self
    end

    def replace_by(object)
      as_tree(Time.now, current_scope_name || 'default') && object.as_tree(current_time_at, current_scope_name)

      raise_error_if_object_unmatched(object)
      raise_error_if_self_is_not_in_the_tree
      raise_error_if_object_is_in_the_tree(object)

      # Must get variables first before the tree changed.
      ready_to_move_elements = descendants_relation(current_time_at, current_scope_name).
        select(:id, :child_id, :distance).load
      root_obj = (self == root) ? object : root
      ancestor_objects = ancestors

      ::ActiveRecord::Base.transaction do
        remove_child_elements_from_ancestors([self.id], ready_to_move_elements.map(&:child_id))
        remove_self_elements

        if self == root
          object.add_as_root(false)
          add_child_elements_to_replaced_object(object, root_obj, ready_to_move_elements)
        else
          add_replaced_object_to_orig_ancestors(object, root_obj, ancestor_objects)
          add_child_elements_to_replaced_object(object, root_obj, ready_to_move_elements)
        end
      end

      self
    end

    private

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
        flat_descendants.each do |object|
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