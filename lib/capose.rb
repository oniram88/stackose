require 'json'
namespace :deploy do
  after :updated, 'capose:deploy'
  after :cleanup, 'capose:cleanup'
end

namespace :capose do
  def _project
    return "" if fetch(:capose_project).nil?
    "-p #{fetch(:capose_project)}_tmp"
  end

  def _files
    cmd = []

    Array(fetch(:capose_file)).each {|file| cmd << ["-f #{file}"]}

    cmd.join(" ")
  end

  def _command(command)
    [_project, _files, command].join(" ")
  end

  task :command do
    _cmd = ENV["CAPOSE_COMMAND"]
    if _cmd.nil?
      puts "Usage: CAPOSE_COMMAND='command' bundle exec cap #{fetch(:stage)} capose:command"
      exit 1
    end

    on roles(fetch(:capose_role)) do
      within current_path do
        execute :"docker-compose", _command(ENV["CAPOSE_COMMAND"])
      end
    end
  end

  task :stop do
    on roles(fetch(:capose_role)) do
      within current_path do
        execute :"docker-compose", _command("stop")
      end
    end
  end

  task :deploy do
    on roles(fetch(:capose_role)) do
      within release_path do
        fetch(:capose_copy).each do |file|
          execute :cp, " -aR #{shared_path}/#{file} #{release_path}/#{file}"
        end
      end
    end

    base_image_name = "#{fetch(:capose_project)}:#{fetch(:capose_image_tag)}"
    compose_override = "docker-compose-image-override.yml"

    ## costruiamo l'immagine
    on roles(fetch(:capose_role)) do
      within release_path do
        with fetch(:capose_env) do

          user_id = capture :id, '-u'
          group_id = capture :id, '-g'

          execute :docker, :build, ". -t #{base_image_name}"

          compose_production = {
            version: '3',
            services: {
              fetch(:capose_service_to_build, 'app').to_sym => {
                image: base_image_name,
                user: "#{user_id}:#{group_id}"
              }
            }
          }

          contents = StringIO.new(JSON[compose_production.to_json].to_yaml)
          upload! contents, "#{release_path}/#{compose_override}"

          set :capose_file, fetch(:capose_file) + [compose_override]


        end
      end
    end


    on roles(fetch(:capose_role)) do
      within release_path do
        with fetch(:capose_env) do
          fetch(:capose_commands).each do |command|
            execute :"docker-compose", _command(command)
          end

          execute :docker, :stack, :deploy, "-c #{compose_override} #{fetch(:capose_project)}"

        end
      end
    end
  end


  task :cleanup do
    on roles(fetch(:capose_role)) do
      within release_path do
        with fetch(:capose_env) do
          tags_list = capture :docker, :images, fetch(:capose_project).to_sym, '--format "{{.Tag}}"'

          list = tags_list.split
          list.delete('latest')

          releases = capture(:ls, "-x", releases_path).split

          (list - releases).each do |r|
            #delete image without release path
            execute :docker, :image, :rm, "#{fetch(:capose_project)}:#{r}"
          end

        end
      end
    end
  end
end

namespace :load do
  task :defaults do
    set :capose_role, -> {:web}
    set :capose_copy, -> {[]}
    set :capose_project, -> {fetch(:application)}
    set :capose_file, -> {["docker-compose.yml", "docker-compose-#{fetch(:stage)}.yml"]}
    set :capose_env, -> {{}}
    set :capose_image_tag, -> {fetch(:release_timestamp)}
    set :capose_service_to_build, -> {'app'}

    set :capose_commands, -> {[]}
  end
end
