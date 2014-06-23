module ChronicTree
  module Travesal
    def children
      init_tree_args_when_nil
      children_relation(current_time_at, current_scope_name).map do |el|
        el.child.as_tree(current_time_at, current_scope_name)
      end
    end

    def parent
      init_tree_args_when_nil
      child_element = parent_relation(current_time_at, current_scope_name).first
      child_element.parent.as_tree(current_time_at, current_scope_name) if child_element
    end

    def root
      init_tree_args_when_nil
      child_element = existed_relation(current_time_at, current_scope_name).first
      child_element.root.as_tree(current_time_at, current_scope_name) if child_element
    end

    def descendants
      init_tree_args_when_nil
      descendants_relation(current_time_at, current_scope_name).inject([]) do |result, el|
        result[el.distance - 1] ||= []
        result[el.distance - 1] << el.child.as_tree(current_time_at, current_scope_name)
        result
      end
    end

    def flat_descendants
      init_tree_args_when_nil
      descendants_relation(current_time_at, current_scope_name).map do |el|
        el.child.as_tree(current_time_at, current_scope_name)
      end
    end

    def ancestors
      init_tree_args_when_nil
      ancestors_relation(current_time_at, current_scope_name).map do |el|
        el.parent.as_tree(current_time_at, current_scope_name)
      end
    end

    alias_method :parent?, :parent

    def empty?(time_at = Time.now, scope_name = 'default')
      ChronicTree::ActiveRecord::Element.
        where(scope_name: scope_name).
        at(time_at).
        empty?
    end

    alias_method :tree_empty?, :empty?

    def existed?(time_at = Time.now, scope_name = 'default')
      existed_relation(time_at, scope_name).any?
    end

    alias_method :existed_in_tree?, :existed?

    private

      def init_tree_args_when_nil
        as_tree if current_time_at.nil? || current_scope_name.nil?
      end
  end
end