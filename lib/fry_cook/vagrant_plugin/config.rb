module FryCook
  module VagrantPlugin
    class Config < Vagrant.plugin("2", :config)
      def self.config_attr(name, default = nil, &block)
        @config_attrs ||= {}
        @config_attrs[name] = block || default
        attr_accessor name
      end
      def self.config_attrs
        @config_attrs || {}
      end

      config_attr :repo_path
      config_attr :repo_git_remote
      config_attr :repo_git_track, "master"
      config_attr :prefix, "default"
      config_attr :server_port, 18998

      def initialize()
        self.class.config_attrs.each do |config_attr, default|
          instance_variable_set(:"@#{config_attr}", UNSET_VALUE)
        end
      end

      def finalize!
        self.class.config_attrs.each do |config_attr, default|
          if instance_variable_get(:"@#{config_attr}") == UNSET_VALUE
            if default.respond_to? :call
              default = default.call
            end
            instance_variable_set(:"@#{config_attr}", default)
          end
        end
        {}
      end
    end
  end
end
