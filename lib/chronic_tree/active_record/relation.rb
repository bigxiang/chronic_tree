module ChronicTree
  module ActiveRecord
    module Relation
      def children_relation(time_at, scope_name)
        send("elements_under_#{scope_name}_parent").
          at(time_at).
          direct.
          exclude_root.
          includes(:child)
      end

      def parent_relation(time_at, scope_name)
        existed_relation(time_at, scope_name).
          direct.
          exclude_root
      end

      def existed_relation(time_at, scope_name)
        send("elements_as_#{scope_name}_child").
          at(time_at)
      end

      def descendants_relation(time_at, scope_name)
        children_relation(time_at, scope_name).order(:distance).all_distance
      end

      def ancestors_relation(time_at, scope_name)
        existed_relation(time_at, scope_name).
          includes(:parent).
          order(:distance)
      end
    end
  end
end
