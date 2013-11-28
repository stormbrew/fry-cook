require 'chef_zero/server'
require 'fry_cook/work_tree'

module FryCook
  class Server < ChefZero::Server
    def initialize(chef_options, fry_options)
      @work_tree = WorkTree.new(fry_options)
      @work_tree.build

      Chef::Config.node_path = @work_tree.node_path
      Chef::Config.cookbook_path = @work_tree.cookbook_path
      Chef::Config.role_path = @work_tree.role_path
      Chef::Config.data_bag_path = @work_tree.data_bag_path
      Chef::Config.environment_path = @work_tree.environment_path

      data_store = Chef::ChefFS::ChefFSDataStore.new(
        Chef::ChefFS::Config.new(Chef::Config).local_fs
      )
      chef_options[:data_store] = data_store

      super(chef_options)
    end
  end
end
