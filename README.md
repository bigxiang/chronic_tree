# Chronic Tree

[![GitHub version](https://badge.fury.io/gh/bigxiang%2Fchronic_tree.svg)](http://badge.fury.io/gh/bigxiang%2Fchronic_tree)
[![Build Status](https://travis-ci.org/bigxiang/chronic_tree.svg?branch=master)](https://travis-ci.org/bigxiang/chronic_tree)
[![Code Climate](https://codeclimate.com/github/bigxiang/chronic_tree.png)](https://codeclimate.com/github/bigxiang/chronic_tree)
[![Coverage Status](https://coveralls.io/repos/bigxiang/chronic_tree/badge.png)](https://coveralls.io/r/bigxiang/chronic_tree)

Build a tree with historical versions and multiple scopes by one model class.

There are some gems for tree structures, for example: [acts_as_tree](https://github.com/amerine/acts_as_tree). They are simple and easy to use.

But in some applications, we are facing more complicated cases. We probably need to build multiple trees using one model and track their histories. For example, organization tree in an ERP or CRM application. Multiple organization trees in these apps usually are created and tracked. So we can’t solve this problem only by using a ‘parent_id’. It’s why this gem has been created.

This gem is compatible with Ruby 2.0+ and Rails 4.0+.

## Installation

Add this line to your application's Gemfile:

    gem 'chronic_tree'

And then execute:

    $ bundle

Execute the installation script:

    $ rails g chronic_tree:install

Execute the rake command:

    $ rake db:migrate

## Quick Start

Add a tree to your model:

```ruby
class Org < ActiveRecord::Base
  chronic_tree
end
```

Before travelling in the tree, using `as_tree` to initialize the tree arguments is highly recommended however the methods below would call `as_tree` implicitly if the arguments aren't set. It's somewhat dup, I am trying to simplify it, but it's the safest way to get the correct version of the tree now.

```ruby
# init a tree with current timestamp and default scope
@org.as_tree

# init a tree with the timestamp at 10 minutes ago and default scope
@org.as_tree(10.minutes.ago)

# init a tree with the timestamp at 10 minutes ago and special scope
@org.as_tree(10.minutes.ago, 'special')
```

####Add root

This method creates a root node for an empty tree.
```ruby
@org.add_as_root
```

####Add children

This method adds a child object under itself.

Create this structure:
```ruby
# root
#   -- child_org
#     -- another_child_org
@org.add_child(@child_org)
@child_org.add_child(@another_child_org)

@org.as_tree.descendants # => [[@child_org], [@another_child_org]]
```

####Change parent

You can change the parent node with another node existing in the tree.
```ruby
@org.as_tree.parent # => @parent
@org.change_parent(@another_parent)
@org.as_tree.parent # => @another_parent
```

####Remove descendants

It destroys all descendant nodes.
```ruby
@org.remove_descendants
```

####Remove self

It destroys self node and its descendant nodes.
```ruby
@org.remove_self
```

####Replace self by another object

It’s replaced by another object. This behavior doesn't affect other tree nodes.
```ruby
# before replacing
# org
#   -- child

@child.as_tree.parent # => @org
@org.replace_by(@another_org)
@child.as_tree.parent # => @another_org

# after replacing
# another_org
#   -- child
```

####Get children

Get all direct child objects of itself.
```ruby
@org.as_tree.children.each do |child_org|
  # actions...
  # each child org has called as_tree automatically
  # so you can use tree traversal directly

  ...
  child_org.children
  child_org.parent
  child_org.root
  ...
end
```

####Get parent

Get parent object, return nil if the parent doesn't exist.
```ruby
@org.as_tree.parent  # => @parent_org
@org.as_tree.parent  # => nil if parent doesn't exist
@org.as_tree.parent? # => alias of parent method
```

####Get root

Get root object, return nil if the parent doesn't exist.
```ruby
@org.as_tree.root  # => @root_org
@org.as_tree.root  # => nil if the tree is empty
```

####Get ancestors

It returns a list of all parent objects of itself and order by distance to it.
```ruby
@org.as_tree.ancestors # => [<parent_org>, <root_org>]
```

####Get descendants

It returns a list of levels. Each level is an array too and contains all objects of this level.
```ruby
@org.as_tree.descendants # => [[<first_level_children>], [<second_level_children>], ...]
```

It returns all descendants as a flat array at once.
```ruby
@org.as_tree.flat_descendants # => [<all_descendants>]
```

####Utils

```ruby
@org.tree_empty?     # => Return true if the tree is empty.
@org.tree_empty?(10.minutes.ago, 'special')
@org.existed_in_tree?   # => Return true if @org exists in the tree.
@org.existed_in_tree?(10.minutes.ago, 'special')
```
These two methods wouldn't call `as_tree`.

## Advanced

The most important part of this gem is playing with historical versions and multiple scopes in one tree.

####Play with history

If you had a tree 1 day ago:

```
root
  -- child1
    -- child1.1
  -- child2
    -- child2.1
```

And change to this version now:

```
root
  -- child1
  -- child2
    -- child2.1
      -- child2.1.1
```

You can easily get the correct version of the tree at any time.

```ruby
root.as_tree.children # => [child1, child2]
child1.as_tree.children # => []
child2.as_tree.flat_descendants # =? [child2.1, child2.1.1]

root.as_tree(1.days.ago).children # => [child1, child2]
child1.as_tree(1.days.ago).children # => [child1.1]
child2.as_tree(1.days.ago).flat_descendants # =? [child2.1]
```

####Play with multiple scopes

If you have two scopes in one tree at the same time:

```
default scope:
root
  -- child1
  -- child2
    -- child2.1

special scope:
another_root
  -- child2
    -- child2.1
    -- child2.2
  -- child3
```

You can switch between two scopes:

```ruby
child2.as_tree.parent # => root
child2.as_tree.children # => [child2.1]

child2.as_tree('special').parent # => another_root
child2.as_tree('special').children # => [child2.1, child2.2]
```


####Using low-level relations

They usually don't need to be used. All tree traversal methods are based on these relations, they just return ActiveRecord::Relation for chronic_tree_elements table, so you can chain the method as you want.

You must pass timestamp and scope name explicitly in these relations.

```ruby
# Return children elements
root.children_relation(Time.now, 'default')

# Return parent elements
root.parent_relation(Time.now, 'default')

# Return descendant elements
root.descendants_relation(Time.now, 'default')

# Return ancestor elements
root.ancestors_relation(Time.now, 'default')
```

## Contributing

Any feedback or improvement is appreciated!

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
