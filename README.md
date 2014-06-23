# Chronic Tree

[![Build Status](https://travis-ci.org/bigxiang/chronic_tree.svg?branch=master)](https://travis-ci.org/bigxiang/chronic_tree)

Build a tree with multiple versions and scopes by one model class.

In some applications, we need to build multiple trees using one model. Traditional solutions can't fulfill this requirement. For example, organization tree in an ERP or CRM application. We usually need multiple organizaiton trees in these apps and track the history of an organization tree.

This gem is compatible with Ruby 2.0+ and Rails 4.0+.

## Installation

Add this line to your application's Gemfile:

    gem 'chronic_tree'

And then execute:

    $ bundle

Execute installation script:

    $ rails g chronic_tree:install

Execute rake command:

    $ rake db:migrate

## Quick Start

Add a tree to your model:

    class Org < ActiveRecord::Base
      chronic_tree
    end

Before travelling in the tree, using `as_tree` to initialize the tree arguments is highly recommended however the methods below would call `as_tree` implicitly if the arguments aren't be set. It's somewhat dup, I am trying to simplify it, but it's the safest way to get the correct version of the tree now.

    # init a tree with current timestamp and default scope
    @org.as_tree

    # init a tree with the timestamp at 10 minutes ago and default scope
    @org.as_tree(10.minutes.ago)

    # init a tree with the timestamp at 10 minutes ago and special scope
    @org.as_tree(10.minutes.ago, 'special')

####Add root

This method would create a root node for an empty tree.
```ruby
@org.add_as_root
```

####Add children

This method would add a child object under itself.

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

You can change the parent node with another node existed in the tree.
```ruby
@org.as_tree.parent # => @parent
@org.change_parent(@another_parent)
@org.as_tree.parent # => @another_parent
```

####Remove descendants

It would destroy all descendant nodes.
```ruby
@org.remove_descendants
```

####Remove self

It would destroy self node and its descendant nodes.
```ruby
@org.remove_self
```

####Replace self by another object

It would be replaced by another object. This behavior doesn't effect other tree nodes.
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
@org.as_tree.children.each do |org|
  # actions.....
  # each org has called as_tree automatically
  # so you can use tree travesal directly

  org.children.size # => the size of children of the org
end
```

####Get parent

Get parent object of iteself, return nil if parent doesn't exist.
```ruby
@org.as_tree.parent  # => @parent_org
@org.as_tree.parent  # => nil if parent doesn't exist
@org.as_tree.parent? # => alias of parent method
```

####Get root

Get root object of itself, return nil if parent doesn't exist.
```ruby
@org.as_tree.root  # => @root_org
@org.as_tree.root  # => nil if the tree is empty
```

####Get ancestors

It would return a list of all parent object of itself and order by distance to it.
```ruby
@org.as_tree.ancestors # => [<parent_org>, <root_org>]
```

####Get descendants

It would return a list of each level descendants of itself and order by distance to it. Each level is an array too and contains each object of this level.
```ruby
@org.as_tree.descendants # => [[<first_level_children>], [<second_level_children>], ...]
```

It would return all descendants as a flat array at once.
```ruby
@org.as_tree.flat_descendants # => [<all_descendants>]
```

####Utils

```ruby
@org.empty?     # => Return if the tree is empty.
@org.empty?(10.minustes.ago, 'special')
@org.existed?   # => Return if current node exists in the tree.
@org.existed?(10.minustes.ago, 'special')
```
These two methods wouldn't call `as_tree`.

## Advanced

The document is being written... You can read the specs first.

####Play with history

TODO...

####Play with multiple scopes

TODO...

####Using low-level relations

TODO...


## Contributing

Any feedback or improvement is appreciated!

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
