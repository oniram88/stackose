# Stackose - A capistrano addon to use with docker stack [WIP]

This gem is a refactoring to use the [capose](https://github.com/netguru/capose) gem, but with docker stack implementation.
**The Documentation is owned from capose, and not so far complete for the docker stack, must be rewritten and cleared**

This gem is a lighter version of docker-compose strategy found in [capistrano-docker](https://github.com/netguru/capistrano-docker) gem. 
The idea is to be much simplier and more custom to use.


### Installation

  1. Ensure you already have `capistrano` gem in your project, with version at least `3.7`
  2. Add the following line to your `Gemfile`: `gem 'stackose', require: false`
  3. Add the following file to `Capfile`: `require 'stackose'`

This gem will automatically hook up to the capistrano after `deploy:updated` hook to perform the deployment via `stackose:deploy` hook

### Changelog


### Defaults

This gem uses couple variables which can be modified inside your deploy scripts, these are:

    set :stackose_role - capistrano role for stackose, defaults to :web
    set :stackose_copy - list of files/dirs to be copied from shared_path before first command (replaces :link_dirs/files), defaults to []
    set :stackose_project - docker-compose project name, defaults to fetch(:application)
    set :stackose_file - list of files for the docker-compose -f parameter (defauls to ["docker-compose.yml", "docker-compose-#{fetch(:stage)}.yml"]) and finaly the generated docker-compose-override
    set :stackose_commands - list of commands to be run with docker-compose, defaults to []
    set :stackose_docker_mount_point - mount point inside the application container, defaults to "/usr/share/www/"
    set :stackose_linked_folders     - list of folders to link inside de image 
    set :stackose_service_to_build   - name of the services with the application to run (default: ['app']) and should use the deploy user and group id
    set :stackose_skip_image_build   - true|[false] to skip the generation of the image, the compose file should have already the image defined(register) the only think is the building of compose_file with user and group id  
    set :stackose_compose_version    - string with compose version(default: '3')

### Folders to be linked
If you need to link shared folders to the root of your application path, like capistrano standard linked_folders do,
you can setup this like:

       set :capose_linked_folders, [ 'public/system',
                                     'public/pictures',
                                     'public/attachments',
                                     'public/pages',
                                     'public/assets',
                                     'uploads']
       
For custom linking you can provide inside the array a hash with key->value of source->destination

        set :capose_linked_folders, [
           'tmp/pids',
           'tmp/cache',
            ....,
           'uploads',
            "/custom_path/#{fetch(:application)}/":"#{fetch(:capose_docker_mount_point)}/log",
           ]
           
if you need the shared_path url in the key you can set `__shared_path__` as placeholder     
or all the other fetch variables can be used inside with `__variable_name__`      
        


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

    docker-compose -p [application] -f docker-compose-[stage].yml -f docker-compose-image-override.yml build
    docker-compose -p [application] -f docker-compose-[stage].yml -f docker-compose-image-override.yml run --rm web rake db:migrate
    docker-compose -p [application] -f docker-compose-[stage].yml -f docker-compose-image-override.yml run --rm web rake assets:precompile
    docker-compose -p [application] -f docker-compose-[stage].yml -f docker-compose-image-override.yml up -d

### Custom docker-compose file paths

If you want to add more compose files or change the name, then modify `capose_file` variable, ex:

    set :stackose_file, ["docker-compose.yml", "docker-compose-override.yml"]

This will tell capistrano to run commands as:

    docker-compose -p [application] -f docker-compose.yml -f docker-compose-override.yml -f docker-compose-image-override.yml [command]

### Docker-compose image override
  
This file is generated on deploy, it will create on the "app" service configurations to make it work more correctly:
It append the image builded for the release (docker stack don't build images) and the user configuration, so the files generated
from inside of the container will have the user oth the host system.