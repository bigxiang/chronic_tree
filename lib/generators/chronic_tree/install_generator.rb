module ChronicTree
  class InstallGenerator < Rails::Generators::Base

    desc "This generator creates the db schema for chronic_tree gem."

    source_root File.expand_path("../templates", __FILE__)

    def create_migration_file
      if Dir["#{destination_root}/db/migrate/*_create_chronic_tree_elements.rb"].empty?
        template "create_chronic_tree_elements.rb",
          "db/migrate/#{Time.now.strftime('%Y%m%d%H%M%S')}_create_chronic_tree_elements.rb"
      end
    end
  end
end
