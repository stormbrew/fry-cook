module FryCook
  module VagrantPlugin
    class Plugin < ::Vagrant.plugin("2")
      name "fry-cook"
      description <<-DESC
      Auto-configurator for fry cook for the chef_client provisioner.
      DESC

      config(:fry_cook) do
        require File.expand_path("../vagrant_plugin/config", __FILE__)
        Config
      end

      action_hook(:fry_cook_reconfig) do |hook|
        chain = Vagrant::Action::Builder.new.tap do |b|
          require File.expand_path("../vagrant_plugin/hooks", __FILE__)
          b.use Hooks::ConfigureServerUrl
        end
        hook.before(::Vagrant::Action::Builtin::ConfigValidate, chain)
      end
      %w{up reload provision}.each do |action|
        action_hook(:"fry_cook_#{action}", :"machine_action_#{action}") do |hook|
          chain = Vagrant::Action::Builder.new.tap do |b|
            require File.expand_path("../vagrant_plugin/hooks", __FILE__)
            b.use Hooks::StartServer
          end
          hook.before(::Vagrant::Action::Builtin::Provision, chain)
        end
      end
    end
  end
end
