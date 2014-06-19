module ChronicTree
  class Railtie < Rails::Railtie
    initializer "chronic_tree.inject_into_active_record_base" do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.include(ChronicTree)
      end
    end
  end
end