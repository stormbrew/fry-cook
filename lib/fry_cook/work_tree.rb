require 'chef/chef_fs/chef_fs_data_store'
require 'chef/chef_fs/config'
require 'chef/role'
require 'chef/environment'
require 'fileutils'
require 'json'
require 'berkshelf'

module FryCook
  class WorkTree
    attr_reader :storage_path

    def initialize(options)
      if options[:storage_path] && File.file?("#{options[:storage_path]}/config.json")
        existing_config = JSON.load(File.read("#{options[:storage_path]}/config.json"), nil, symbolize_names: true)
        options = existing_config.merge(options)
      end

      if options[:git_repo_remote]
        @mode = :git
        @git_remote = options[:git_repo_remote]
        @git_ref = options[:git_ref] || 'master'
        @storage_path = options[:storage_path] || raise("Must specify storage path for git mode.")
        @git_repo = "#{@storage_path}/git-repo"
      else
        @mode = :path
        @working_path = options[:working_path] || '.'
        @storage_path = options[:storage_path] || "#{@working_path}/.fry-cook"
      end

      FileUtils.mkdir_p(@storage_path)
      FileUtils.mkdir_p("#{@storage_path}/nodes")

      File.write("#{@storage_path}/config.json", JSON.dump(options))
    end

    def node_path
      "#{storage_path}/nodes"
    end
    def cookbook_path
      "#{storage_path}/current/cookbooks"
    end
    def role_path
      "#{storage_path}/current/roles"
    end
    def data_bag_path
      "#{storage_path}/current/data_bags"
    end
    def environment_path
      "#{storage_path}/current/environments"
    end

    def cmd(cmd)
      res = IO.popen(cmd, :err=>[:child, :out]) do |p|
        p.readlines.collect {|line| line.chomp }
      end
      if !$?.success?
        raise("Command #{cmd.join(' ')} failed:\n#{res.join("\n")}")
      end
      res
    end
    def git(*cmd)
      cmd(["git", "--git-dir", @git_repo, *cmd])
    end
    def git_in(work_path, *cmd)
      FileUtils.mkdir_p(work_path)
      git("--work-tree", work_path, *cmd)
    end

    def git_refresh
      if !File.directory? @git_repo
        git("clone", "--bare", @git_remote, @git_repo)
      end
      git("fetch", '-f', @git_remote, 'refs/heads/*:refs/heads/*')
    end

    def pull_source
      case @mode
      when :git
        git_refresh
        new_ref = git("rev-parse", @git_ref)
        if new_ref.length == 0
          raise("Didn't get a valid ref for #{@git_ref}")
        end
        new_version = "build-" + new_ref[0]
        source_path = "#{@storage_path}/#{new_version}/chef_repo"
        if !File.directory? source_path
          git_in(source_path, "checkout", "-f", @git_ref)
        end
      when :path
        new_version = "build-" + Time.now.to_i
        source_path = @working_path
      end
      return new_version, source_path
    end

    def install_cookbooks(new_version, source_path, install_path)
      case
      when File.file?("#{source_path}/Berksfile")
        # Note: Doesn't work properly without being in the directory of the berksfile.
        Dir.chdir(source_path) do
          berksfile = Berkshelf::Berksfile.from_file("Berksfile")
          berksfile.install(path: "#{install_path}/cookbooks")
        end
      when File.directory?("#{source_path}/cookbooks")
        FileUtils.cp_r("#{source_path}/cookbooks", "#{install_path}/cookbooks")
      else
        raise("No cookbooks found.")
      end
    end

    def install_environments(new_version, source_path, install_path)
      FileUtils.mkdir_p("#{install_path}/environments")
      environments = Dir.glob("#{source_path}/environments/*.json")
      if !environments.empty?
        FileUtils.cp(environments, "#{install_path}/environments")
      end
      Dir.glob("#{source_path}/environments/*.rb").each do |environment|
        environment_obj = Chef::Environment.new
        environment_obj.name File.basename(environment, ".rb")
        environment_obj.from_file(environment)
        File.write("#{install_path}/environments/#{File.basename(environment, ".rb")}.json", environment_obj.to_json)
      end
    end

    def install_roles(new_version, source_path, install_path)
      FileUtils.mkdir_p("#{install_path}/roles")
      roles = Dir.glob("#{source_path}/roles/*.json")
      if !roles.empty?
        FileUtils.cp(roles, "#{install_path}/roles")
      end
      Dir.glob("#{source_path}/roles/*.rb").each do |role|
        role_obj = Chef::Role.new
        role_obj.name File.basename(role, ".rb")
        role_obj.from_file(role)
        File.write("#{install_path}/roles/#{File.basename(role, ".rb")}.json", role_obj.to_json)
      end
    end

    def install_data_bags(new_version, source_path, install_path)
      FileUtils.mkdir_p("#{install_path}/data_bags")
      Dir.glob("#{source_path}/data_bags/*").each do |data_bag|
        next if !File.directory? data_bag

        data_bag_name = File.basename(data_bag)
        FileUtils.mkdir_p("#{install_path}/data_bags/#{data_bag_name}")
        items = Dir.glob("#{data_bag}/*.json")
        if !items.empty?
          FileUtils.cp(items, "#{install_path}/data_bags/#{data_bag_name}")
        end
      end
    end

    def build(force = false)
      current_link = "#{@storage_path}/current"
      old_version = File.symlink?(current_link) && File.readlink(current_link)

      new_version, source_path = pull_source()
      install_path = File.expand_path("#{@storage_path}/#{new_version}")

      if force || new_version != old_version
          
        begin
          install_cookbooks(new_version, source_path, install_path)
          install_environments(new_version, source_path, install_path)
          install_roles(new_version, source_path, install_path)
          install_data_bags(new_version, source_path, install_path)
        rescue
          # Clean up the probably broken deploy install path if it got created.
          # We don't care why it failed, so we pass the buck up.
          FileUtils.rmdir(install_path) if File.directory?(install_path)
          raise
        end

        tmplink = current_link + ".#{Process.pid}.lnk"
        FileUtils.ln_s(new_version, tmplink)
        File.rename(tmplink, current_link)

        if old_version && File.directory?("#{@storage_path}/#{old_version}")
          FileUtils.rm_rf("#{@storage_path}/#{old_version}")
        end
      end
    end
  end
end
