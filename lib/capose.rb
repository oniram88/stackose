namespace :deploy do
  after :updated, 'capose:deploy'
end

namespace :capose do
  def _project
    return "" if fetch(:capose_project).nil?
    "-p #{fetch(:capose_project)}"
  end

  def _files
    cmd = []

    Array(fetch(:capose_file)).each { |file| cmd << ["-f #{file}"] }

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

    on roles(fetch(:capose_role)) do
      within release_path do
        with fetch(:capose_env) do
          fetch(:capose_commands).each do |command|
            execute :"docker-compose", _command(command)
          end
        end
      end
    end
  end
end

namespace :load do
  task :defaults do
    set :capose_role,    -> { :web }
    set :capose_copy,    -> { [] }
    set :capose_project, -> { fetch(:application) }
    set :capose_file,    -> { ["docker-compose-#{fetch(:stage)}.yml"] }
    set :capose_env,     -> { {} }

    set :capose_commands, -> { ["build", "up -d"] }
  end
end
