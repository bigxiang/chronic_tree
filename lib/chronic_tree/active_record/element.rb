module ChronicTree
  module ActiveRecord
    class Element < ::ActiveRecord::Base
      self.table_name = "chronic_tree_elements"

      belongs_to :parent, polymorphic: true, foreign_type: 'tree_type'
      belongs_to :child, polymorphic: true, foreign_type: 'tree_type'
      belongs_to :root, polymorphic: true, foreign_type: 'tree_type'

      scope :at, -> (time = Time.now) {
        start_time_col = self.arel_table[:start_time]
        end_time_col = self.arel_table[:end_time]
        where(start_time_col.lteq(time)).where(end_time_col.gt(time))
      }

      scope :exclude_root, -> {
        root_id_col = self.arel_table[:root_id]
        child_id_col = self.arel_table[:child_id]
        where(root_id_col.not_eq(child_id_col))
      }

      scope :direct, -> { where(distance: 1) }
      scope :all_distance, -> { unscope(where: :distance) }
    end
  end
end
