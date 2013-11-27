require 'chef_zero/server'
require 'fry_cook/work_tree'

module FryCook
  class Server < ChefZero::Server
    def initialize(chef_options, fry_options)
      super(chef_options)

      @work_tree = WorkTree.new(fry_options)
    end
  end
end
