# Fry Cook

*Not quite a chef yet, the fry cook knows only one menu.* 

Fry Cook is a chef server that is designed to be used with a
git repository (or working directory) that is to be treated as
a definitive source of truth. It is based on chef zero with
the Chef local filesystem data source, but has some modifications
on top of that.

## Standalone Usage

Fry Cook can be used as a standalone server just like a normal
chef server. All the caveats of using this as a chef server apply
as using [https://github.com/opscode/chef-zero](Chef-Zero). It
doesn't authenticate anything. This is because it uses chef-zero
to do most of the work.

However, it can be useful in ways that chef-zero is not. Namely,
it can seed your cookbooks from a git repository and even build
those cookbooks from a Berksfile. It will also convert all .rb files
to .json files as expected by the chef server. This is all a much
faster option than setting up a chef server and uploading everything
to it.

If you run fry-cook --help you will see this:

```bash
    Usage: fry-cook [ARGS]
        -H, --host HOST                  Host to bind to (default: 127.0.0.1)
        -p, --port PORT                  Port to listen on (default: 8889)
            --socket PATH                Unix socket path to listen on
        -d, --daemon                     Run as a daemon process
            --path PATH                  A working copy of the chef-repo to build from (default: .)
            --remote GIT_REMOTE          A git remote to build from
            --track GIT_REF              The branch (or other ref) to track in the git remote (default: master)
            --storage-path PATH          Where to store the files the server works from (default: {working_path}/.fry-cook
        -l, --log-level LEVEL            Set the output log level
        -h, --help                       Show this message
            --version                    Show version
```

The arguments that differ from chef-zero are the path, remote,
track, and storage-path options. Fry-cook effectively has two modes,
depending on where you want to build your working chef server from:

### From a Local Path

You can build from a local path, like a working copy of a git repository. This
is great for development or using as a vagrant plugin (below). To use this mode you
can simply pass nothing special and it will assume the current working directory
is the local path you want to work from. To explicitly specify a path, you can
pass the --path option.

You should not pass the remote or track arguments for this mode. They put it
into the git mode, described in the next section.

Examples:

```bash
    fry-cook -d # The current working directory should be a chef repo.
```

```bash
    fry-cook -d --path /var/lib/chef # Build from /var/lib/chef.
```

### From a Git Repository or Remote

If you want to build your chef server configuration from a remote git repository,
say on github or some other central repository, you can use the remote and track
arguments. Remote is a git remote, such as ```git@github.com:stormbrew/fry-cook.git```.
Track is the reference within the repository, which could be a branch or tag. It
defaults to the master branch.

Examples:

```bash
    fry-cook -d --remote git@github.com:stormbrew/mything.git # Master branch of mything on github.
```

```bash
    fry-cook -d --remote git@github.com:stormbew/mything.git --track production # Production branch of mything on github.
```

### Storage Path

The storage path is where fry-cook builds into. Every time it builds from
the source it builds into a fresh directory. It also keeps the uploaded node
json files in here in a way that persists across rebuilds.

This setup is designed to allow rebuilding from the repository on a live
server without turning it off. This feature will be added later.

Most of the time you'll want to leave this as the default, which will
put it in a .fry-cook directory in the current working directory.

## Using With Vagrant

If you install Fry Cook as a vagrant plugin you can use it in much the same
way as the vagrant-chef-zero plugin. You don't need to install a separate
plugin to do this, just ```vagrant plugin install fry-cook```. From there
you can add it to your Vagrantfile as follows:

```ruby
    Vagrant.configure("2") do |config|
        config.vm.box_url = "http://files.vagrantup.com/precise64.box"
        config.omnibus.chef_version = "11.8.0"

        ## For a local repository
        config.fry_cook.repo_path = "."

        ## For a remote repository
        # config.fry_cook.repo_git_remote = "git@github.com:stormbrew/stuff.git"
        # config.fry_cook.repo_git_ref = "master" # optional

        ## If you have multiple vms in your vagrantfile and you
        ## want them to use a different chef server, you can set
        ## them up to use different 'prefixes' and different server
        ## ports (default is 18999) to keep them separate:
        # config.fry_cook.prefix = "config1"
        # config.fry_cook.server_port = 9432

        config.vm.provision :chef_client do |chef_client|
            chef_client.add_recipe "apt"
            chef_client.add_recipe "nginx"
        end
    end
```

## Future Work

This really needs more testing infrastructure (or any at all). It also needs
a command to rebuild the repo without restarting the server, which is not
terribly difficult.
