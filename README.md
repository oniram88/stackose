# Capose - A capistrano addon to use with docker-compose

This gem is a lighter version of docker-compose strategy found in [capistrano-docker](https://github.com/netguru/capistrano-docker) gem. The idea is to be much simplier and more custom to use.

The idea behind this gem came when working with docker-compose deployments. I realized that most of the time the commands I am using are "build" and "up -d". Along with giving the name of the project and the docker-compose file path, the defaults in this gem should be enough for you just to require the gem and deploy should work.

### Installation

  1. Ensure you already have `capistrano` gem in your project, with version at least `3.7`
  2. Add the following line to your `Gemfile`: `gem 'capose', require: false`
  3. Add the following file to `Capfile`: `require 'capose'`

This gem will automatically hook up to the capistrano after `deploy:updated` hook to perform the deployment via `capose:deploy` hook

### Defaults

This gem uses couple variables which can be modified inside your deploy scripts, these are:

    set :capose_role - capistrano role for capose, defaults to :web
    set :capose_copy - list of files/dirs to be copied from shared_path before first command (replaces :link_dirs/files), defaults to []
    set :capose_project - docker-compose project name, defaults to fetch(:application)
    set :capose_file - list of files for the docker-compose -f parameter (defauls to ["docker-compose-#{fetch(:stage)}.yml"])
    set :capose_commands - list of commands to be run with docker-compose, defaults to ['build', 'up -d']

With above defaults, if you have: docker-compose-STAGE.yml file and the only thing you want to do is "build" and "up" your app, then the only thing you have to do is to require the capose gem in Capfile.

Capistrano will run following commands with default values:

    docker-compose -p [application] -f docker-compose-[stage].yml build
    docker-compose -p [application] -f docker-compose-[stage].yml up -d


### Additional hooks to use
This gem provides total three hooks, the default one, `capose:deploy` automatically is executed upon deployment, the remaning two are

  1. `capose:stop`
  2. `capose:command`

`capose:stop` simply runs the command `docker-compose ... stop` in the `current_path`, so you can manually stop the containers.

`capose:command` runs the custom command in `current_path` given in `CAPOSE_COMMAND` environment variable, so the usage is: `CAPOSE_COMMAND="some command" cap [stage] capose:command` - this will run a following command: `docker-compose -p [application] -f [compose-file] some command` - you can use capose command to for example restart your containers



### Additional files before first command
If you need to throw in to the "release" folder couple files (say secret files) before image is build, you can use `capose_copy` for that, ex:

    set :capose_copy, %w(config/secrets.yml certs/google.crt certs/google.key)

This command will copy the files from shared/ path before first command is executed, such as:

    cp -aR [shared_path]/config/secrets.yml [release_path]/config/secrets.yml
    cp -aR [shared_path]/config/google.crt [release_path]/config/google.crt
    cp -aR [shared_path]/config/google.key [release_path]/config/google.key
    docker-compose -p [application] -f ... build
    docker-compose ...

### Additional commands to run
If your use-case contains more commands than `build` and `up -d`, then you can modify `capose_commands` to achieve that, ex:

    set :capose_commands, ["build", "run --rm web rake db:migrate", "run --rm web rake assets:precompile", "up -d"]

This will tell capistrano to run following commands:

    docker-compose -p [application] -f docker-compose-[stage].yml build
    docker-compose -p [application] -f docker-compose-[stage].yml run --rm web rake db:migrate
    docker-compose -p [application] -f docker-compose-[stage].yml run --rm web rake assets:precompile
    docker-compose -p [application] -f docker-compose-[stage].yml up -d

### Custom docker-compose file paths

If you want to add more compose files or change the name, then modify `capose_file` variable, ex:

    set :capose_file, ["docker-compose.yml", "docker-compose-override.yml"]

This will tell capistrano to run commands as:

    docker-compose -p [application] -f docker-compose.yml -f docker-compose-override.yml [command]
