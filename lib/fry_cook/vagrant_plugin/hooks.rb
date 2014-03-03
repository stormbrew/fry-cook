require 'socket'
require 'openssl'
require 'tmpdir'
require 'fry_cook/server'

module FryCook::VagrantPlugin::Hooks
  class Base
    def initialize(app, env)
      @app = app
      @env = env
    end

    def config
      @env[:global_config].fry_cook
    end

    def client_config
      @env[:machine].config.vm.provisioners.select {|prov| prov.name == :chef_client }
    end

    def active?
      client_config.any? && config.repo_path || config.repo_git_remote
    end

    def host_ip_address
      # This gets the first ip address in a private range. With virtualbox,
      # at least, things seem to be routed so that the vm can connect to this
      # IP even if it has nothing to do with vagrant or virtualbox. This may not
      # be an entirely safe assumption, but vagrant doesn't provide any kind of
      # better way to obtain a canonical reachable address as far as I can tell.
      Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address
    end

    def call(env)
      @env = env
      if active?
        do_action(env)
      end
      @app.call(env)
    end
  end

  class ConfigureServerUrl < Base
    def get_fake_key_path
      fake_directory = File.join(Dir.tmpdir, "fake_key")
      fake_key_path = File.join(fake_directory, "fake.pem")

      if !File.exists?(fake_key_path)
        fake_key = OpenSSL::PKey::RSA.new(2048)
        Dir.mkdir(fake_directory) unless File.exists?(fake_directory)
        File.open(fake_key_path,"w") {|f| f.puts fake_key } 
      end

      fake_key_path
    end

    def do_action(env)
      client_config.each do |client|
        fake_key = get_fake_key_path

        if !client.config.instance_variable_get(:"@chef_server_url")
          client.config.instance_variable_set(:"@chef_server_url", "http://#{host_ip_address}:#{config.server_port}/")
        end
        if !client.config.instance_variable_get(:@validation_key_path)
          client.config.instance_variable_set(:@validation_key_path, fake_key)
        end
      end
    end
  end

  class StartServer < Base
    def do_action(env)
      # Note: This is not thread safe, but it may not entirely
      # be able to be. I don't think vagrant would run these in
      # parallel at the moment at any rate.
      if !defined? @@running
        server_options = {
          host: host_ip_address,
          port: config.server_port,
          daemon: false,
        }
        fry_options = {
          storage_path: ".vagrant/fry-cook/#{config.prefix}",
        }
        case
        when config.repo_path
          fry_options[:working_path] = config.repo_path
        when config.repo_git_remote
          fry_options[:git_repo_remote] = config.repo_git_remote
          fry_options[:git_ref] = config.repo_git_track
        end

        server = FryCook::Server.new(server_options, fry_options)
        server.start_background
        @@running = true
      end
    end
  end
end
