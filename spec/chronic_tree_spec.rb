require 'spec_helper'

describe ChronicTree do

  context "Tree Traversal" do
    before(:all) do
      init_simple_tree
    end

    after(:all) do
      destroy_simple_tree
    end

    it "f: access non-existed scope" do
      expect { @root_org.as_tree(Time.now, 'non-existed') }.to raise_error
    end

    it "f: access the future" do
      expect { @root_org.as_tree(1.minute.from_now) }.to raise_error
    end

    it "s: access children" do
      expect(@root_org.children.size).to be == 2
      expect(@root_org.children.first.id).to be == @lv1_child_org.id
      expect(@lv1_child_org.children.size).to be == 2
      expect(@lv1_child_org.children.first.id).to be == @lv2_child_org.id
      expect(@lv2_child_org.children.size).to be == 1
    end

    it "s: access parent" do
      expect(@lv1_child_org.parent.id).to be == @root_org.id
      expect(@lv2_child_org.parent.id).to be == @lv1_child_org.id
      expect(@root_org.parent?).to be_falsy
    end

    it "s: access root" do
      expect(@lv1_child_org.root.id).to be == @root_org.id
      expect(@lv2_child_org.root.id).to be == @root_org.id
      expect(@root_org.root.id).to be == @root_org.id
    end

    it "s: access descendants" do
      expect(@root_org.descendants.size).to be == 5
      expect(@root_org.flat_descendants.size).to be == 12
      expect(@root_org.flat_descendants.first.id).to be == @lv1_child_org.id
      expect(@root_org.flat_descendants.second.id).to be == @lv1_child_org2.id
      expect(@lv1_child_org.descendants.size).to be == 4
      expect(@lv1_child_org.flat_descendants.size).to be == 8
      expect(@lv1_child_org.flat_descendants.first.id).to be == @lv2_child_org.id
      expect(@lv2_child_org.descendants.size).to be == 3
    end

    it "s: access ancestors" do
      expect(@root_org.ancestors.size).to be == 1
      expect(@root_org.ancestors.first.id).to be == @root_org.id
      expect(@lv1_child_org.ancestors.size).to be == 1
      expect(@lv1_child_org.ancestors.first.id).to be == @root_org.id
      expect(@lv2_child_org.ancestors.size).to be == 2
      expect(@lv2_child_org.ancestors.first.id).to be == @lv1_child_org.id
      expect(@lv2_child_org.ancestors.second.id).to be == @root_org.id
      expect(@lv5_child_org.ancestors.size).to be == 5
    end
  end

  context "Tree Operation" do
    context "Tree is empty" do
      before(:each) do
        @root_org = Org.create(name: 'root')
      end

      after(:each) do
        @root_org.destroy
      end

      it "s: add self as the root element" do
        root_org = @root_org.add_as_root
        expect(root_org.empty?).to be_falsy
        expect(root_org.children.size).to be == 0
        expect(root_org.parent?).to be_falsy
        expect(root_org.descendants.size).to be == 0
        expect(root_org.ancestors.size).to be == 1
      end
    end

    context "Tree isn't empty" do

      before(:each) do
        init_simple_tree
        @new_org = Org.create(name: 'new')
        @new_org2 = Org.create(name: 'new2')
      end

      after(:each) do
        destroy_simple_tree
      end

      context "Self is in the tree" do
        it "f: add self as the root element" do
          expect { @root_org.add_as_root }.to raise_error
        end

        it "s: add children" do
          @lv1_child_org.add_child(@new_org)
          expect(@lv1_child_org.children.size).to be == 3
          expect(@root_org.flat_descendants.size).to be == 13
          expect(@root_org.descendants.second.size).to be == 5
        end

        it "f: adding children" do
          expect { @lv1_child_org.add_child(Org.new) }.to raise_error
          expect { @lv1_child_org.add_child(Struct.new) }.to raise_error
          expect { @lv1_child_org.add_child(@lv2_child_org) }.to raise_error
        end

        it "s: remove self" do
          @lv1_child_org.remove_self
          expect(@lv1_child_org.existed?).to be_falsy
          expect(@lv2_child_org.existed?).to be_falsy
          expect(@root_org.flat_descendants.size).to be == 3
        end

        it "s: remove descendants" do
          @lv1_child_org.remove_descendants
          expect(@lv1_child_org.existed?).to be_truthy
          expect(@lv2_child_org.existed?).to be_falsy
          expect(@root_org.flat_descendants.size).to be == 4
        end

        it "s: change parent to another object" do
          @lv2_child_org.change_parent(@root_org)
          expect(@lv1_child_org.children.size).to be == 1
          expect(@lv2_child_org.parent.id).to be == @root_org.id
          expect(@lv5_child_org.ancestors.size).to be == 4
          expect(@root_org.children.size).to be == 3
        end

        it "s: replace root by another object" do
          @root_org.replace_by(@new_org)
          expect(@root_org.existed?).to be_falsy
          expect(@lv1_child_org.parent.id).to be == @new_org.id
          expect(@new_org.parent?).to be_falsy
          expect(@new_org.children.size).to be == 2
          expect(@new_org.descendants.size).to be == 5
        end

        it "s: replace non-root by another object" do
          @lv1_child_org.replace_by(@new_org)
          expect(@lv1_child_org.existed?).to be_falsy
          expect(@lv2_child_org.parent.id).to be == @new_org.id
          expect(@new_org.parent.id).to be == @root_org.id
          expect(@root_org.children.size).to be == 2
          expect(@root_org.descendants.size).to be == 5
        end

        it "f: change parent to another object" do
          expect { @lv1_child_org.change_parent(Org.new) }.to raise_error
          expect { @lv1_child_org.change_parent(Struct.new) }.to raise_error
          expect { @lv1_child_org.change_parent(@new_org) }.to raise_error
          expect { @lv1_child_org.change_parent(@lv2_child_org) }.to raise_error
          expect { @lv1_child_org.change_parent(@lv1_child_org) }.to raise_error
        end

        it "f: replace self by another object" do
          expect { @lv1_child_org.replace_by(Org.new) }.to raise_error
          expect { @lv1_child_org.replace_by(Struct.new) }.to raise_error
          expect { @lv1_child_org.replace_by(@lv2_child_org) }.to raise_error
        end

        it "s: play with multiple scopes" do
          # operate with special scope
          @root_org.as_tree('special').add_as_root.add_child(@lv1_child_org.as_tree('special'))
          @lv1_child_org.add_child(@lv2_child_org4.as_tree('special'))

          # force refreshing the timestamp
          @root_org.as_tree('special')
          expect(@root_org.descendants.size).to be == 2
          expect(@lv2_child_org4.parent.id).to be == @lv1_child_org.id

          # change the scope back to default
          @root_org.as_tree
          @lv2_child_org4.as_tree
          expect(@root_org.flat_descendants.size).to be == 12
          expect(@lv2_child_org4.parent.id).to be == @lv1_child_org2.id
        end
      end

      context "Self isn't in the tree" do
        it "f: add self as the root element" do
          expect { @new_org.add_as_root }.to raise_error
        end

        it "f: add children" do
          expect { @new_org.add_child(@new_org2) }.to raise_error
        end

        it "f: remove self" do
          expect { @new_org.remove_self }.to raise_error
        end

        it "f: remove descendants" do
          expect { @new_org.remove_descendants }.to raise_error
        end

        it "f: change parent to another object" do
          expect { @new_org.change_parent(@root_org) }.to raise_error
        end

        it "f: replace self by another object" do
          expect { @new_org.replace_by(@root_org) }.to raise_error
        end
      end
    end
  end
end