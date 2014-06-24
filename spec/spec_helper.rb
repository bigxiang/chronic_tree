require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'coveralls'
Coveralls.wear!

require 'active_record'
require 'logger'

require 'chronic_tree'

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Comment this line to view the debug information in the console.
ActiveRecord::Base.logger.level = Logger::INFO

ActiveRecord::Schema.define do
  create_table :orgs do |t|
    t.string :name
  end

  create_table :chronic_tree_elements do |t|
    t.string :tree_type, not_null: true
    t.integer :parent_id, not_null: true
    t.integer :child_id, not_null: true
    t.integer :root_id, not_null: true
    t.integer :distance, not_null: true
    t.datetime :start_time, not_null: true
    t.datetime :end_time, not_null: true
    t.string :scope_name, not_null: true
    t.integer :position

    t.index :tree_type
    t.index :parent_id
    t.index :child_id
    t.index :root_id
    t.index [:start_time, :end_time]
    t.index :scope_name
  end
end

class Org < ActiveRecord::Base
  include ChronicTree

  chronic_tree
  chronic_tree('special')
end

# Provide a tree with the hierarchy below:
#
# Now:
#   root
#     -- lv1
#       -- lv2
#         -- lv3
#           -- lv4
#             -- lv5
#       -- lv2-2
#         -- lv3-2
#           -- lv4-2
#             -- lv5-2
#     -- lv1-2
#       -- lv2-3
#       -- lv2-4
#
# 10 minutes ago:
#
#   root
#     -- lv2
#       -- lv1
def init_simple_tree
  @root_org = Org.create(name: 'root')
  @lv1_child_org = Org.create(name: 'lv1')
  @lv1_child_org2 = Org.create(name: 'lv1-2')
  @lv2_child_org = Org.create(name: 'lv2')
  @lv2_child_org2 = Org.create(name: 'lv2-2')
  @lv2_child_org3 = Org.create(name: 'lv2-3')
  @lv2_child_org4 = Org.create(name: 'lv2-4')
  @lv3_child_org = Org.create(name: 'lv3')
  @lv3_child_org2 = Org.create(name: 'lv3-2')
  @lv4_child_org = Org.create(name: 'lv4')
  @lv4_child_org2 = Org.create(name: 'lv4-2')
  @lv5_child_org = Org.create(name: 'lv5')
  @lv5_child_org2 = Org.create(name: 'lv5-2')

  current_time = Time.now

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @root_org.id,
    distance: 0,
    start_time: 10.minutes.ago(current_time),
    end_time: 1000.years.from_now,
    scope_name: 'default'
  )

  # 10 minutes ago
  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv2_child_org.id,
    distance: 1,
    start_time: 10.minutes.ago(current_time),
    end_time: current_time,
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv1_child_org.id,
    distance: 2,
    start_time: 10.minutes.ago(current_time),
    end_time: current_time,
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv2_child_org.id,
    child_id: @lv1_child_org.id,
    distance: 1,
    start_time: 10.minutes.ago(current_time),
    end_time: current_time,
    scope_name: 'default'
  )

  # now

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv1_child_org.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv1_child_org2.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv2_child_org.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org.id,
    child_id: @lv2_child_org.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv2_child_org2.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org.id,
    child_id: @lv2_child_org2.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv2_child_org3.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org2.id,
    child_id: @lv2_child_org3.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv2_child_org4.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org2.id,
    child_id: @lv2_child_org4.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv3_child_org.id,
    distance: 3,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org.id,
    child_id: @lv3_child_org.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv2_child_org.id,
    child_id: @lv3_child_org.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv4_child_org.id,
    distance: 4,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org.id,
    child_id: @lv4_child_org.id,
    distance: 3,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv2_child_org.id,
    child_id: @lv4_child_org.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv3_child_org.id,
    child_id: @lv4_child_org.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv5_child_org.id,
    distance: 5,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org.id,
    child_id: @lv5_child_org.id,
    distance: 4,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv2_child_org.id,
    child_id: @lv5_child_org.id,
    distance: 3,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv3_child_org.id,
    child_id: @lv5_child_org.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv4_child_org.id,
    child_id: @lv5_child_org.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv3_child_org2.id,
    distance: 3,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org.id,
    child_id: @lv3_child_org2.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv2_child_org2.id,
    child_id: @lv3_child_org2.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv4_child_org2.id,
    distance: 4,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org.id,
    child_id: @lv4_child_org2.id,
    distance: 3,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv2_child_org2.id,
    child_id: @lv4_child_org2.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv3_child_org2.id,
    child_id: @lv4_child_org2.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @root_org.id,
    child_id: @lv5_child_org2.id,
    distance: 5,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv1_child_org.id,
    child_id: @lv5_child_org2.id,
    distance: 4,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv2_child_org2.id,
    child_id: @lv5_child_org2.id,
    distance: 3,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv3_child_org2.id,
    child_id: @lv5_child_org2.id,
    distance: 2,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )

  @root_org.elements_under_default_root.create(
    parent_id: @lv4_child_org2.id,
    child_id: @lv5_child_org2.id,
    distance: 1,
    start_time: current_time,
    end_time: 1000.years.since(current_time),
    scope_name: 'default'
  )
end

def destroy_simple_tree
  Org.destroy_all
end
