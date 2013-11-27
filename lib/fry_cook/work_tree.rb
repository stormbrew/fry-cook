require 'chef/chef_fs/chef_fs_data_store'
require 'chef/chef_fs/config'
require 'fileutils'

module FryCook
  class WorkTree
    def initialize(options)
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
    end

    def git(*cmd)
      res = system("git", "--git-dir", @git_repo, *cmd)
      if !res
        raise("Failed git command #{cmd.join(" ")}")
      end
    end
    def git_for(verspec, *cmd)
      git("--work-tree", "#{@storage_path}/#{verspec}", *cmd)
    end


    def git_refresh
      if !File.directory? @git_repo
        res = system("git", "clone", "--bare", @git_remote, @git_repo)
      end
      git("fetch")
    end

    def build
      current_link = "#{@storage_path}/current"
      old_version = File.file?(current_link) && FileUtils.readlink(current_link)

      case @mode
      when :git
        git_refresh
        new_version = "build-" + git("rev-parse", @git_ref)
        git_for(new_version, "checkout", @git_ref)
      when :path
        new_version = "build-" + Time.now.to_i
      end
    end
  end
end
