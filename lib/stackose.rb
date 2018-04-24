require 'json'
namespace :deploy do
  after :updated, 'stackose:deploy'
  after :cleanup, 'stackose:cleanup'
  before :check, 'stackose:create_linked_dirs'
end

namespace :stackose do
  def _project
    return "" if fetch(:stackose_project).nil?
    "-p #{fetch(:stackose_project)}_tmp"
  end

  def _files
    cmd = []

    Array(fetch(:stackose_file)).each {|file| cmd << ["-f #{file}"]}

    cmd.join(" ")
  end

  def _command(command)
    [_project, _files, command].join(" ")
  end

  def normalized_stackose_linked_folders
    files = []
    fetch(:stackose_linked_folders).each do |f|

      if f.is_a? Hash
        f.each {|k, v| files << ["#{k.to_s.gsub('__shared_path__', shared_path.to_s)}", v]}
      elsif f.is_a? String
        files << ["#{shared_path}/#{f}", "#{fetch(:stackose_docker_mount_point)}/#{f}"]
      end

    end
    files.to_h
  end

  # task :command do
  #   _cmd = ENV["STACKOSE_COMMAND"]
  #   if _cmd.nil?
  #     puts "Usage: STACKOSE_COMMAND='command' bundle exec cap #{fetch(:stage)} stackose:command"
  #     exit 1
  #   end
  #
  #   on roles(fetch(:stackose_role)) do
  #     within current_path do
  #       execute :"docker-compose", _command(ENV["STACKOSE_COMMAND"])
  #     end
  #   end
  # end
  #
  # task :stop do
  #   on roles(fetch(:stackose_role)) do
  #     within current_path do
  #       execute :"docker-compose", _command("stop")
  #     end
  #   end
  # end
  #

  desc "check linked dirs, and create this if there are not present"
  task :create_linked_dirs do
    on roles(fetch(:stackose_role)) do
      execute :mkdir,'-p',normalized_stackose_linked_folders.keys.join(' ')
    end
  end

  task :deploy do
    on roles(fetch(:stackose_role)) do
      within release_path do
        fetch(:stackose_copy).each do |file|
          execute :cp, " -aR #{shared_path}/#{file} #{release_path}/#{file}"
        end
      end
    end

    base_image_name = "#{fetch(:stackose_project)}:#{fetch(:stackose_image_tag)}"
    compose_override = "docker-compose-image-override.yml"

    ## costruiamo l'immagine
    on roles(fetch(:stackose_role)) do
      within release_path do
        with fetch(:stackose_env) do

          user_id = capture :id, '-u'
          group_id = capture :id, '-g'

          execute :docker, :build, ". -t #{base_image_name}"

          compose_production = {
            version: '3',
            services: {
              fetch(:stackose_service_to_build, 'app').to_sym => {
                image: base_image_name,
                user: "#{user_id}:#{group_id}"
              }
            }
          }

          contents = StringIO.new(JSON[compose_production.to_json].to_yaml)
          upload! contents, "#{release_path}/#{compose_override}"

          set :stackose_file, fetch(:stackose_file) + [compose_override]


        end
      end
    end


    on roles(fetch(:stackose_role)) do
      within release_path do
        with fetch(:stackose_env) do
          fetch(:stackose_commands).each do |command|
            execute :"docker-compose", _command(command)
          end

          execute :docker, :stack, :deploy, "-c #{fetch(:stackose_file).join(' -c ')} #{fetch(:stackose_project)}"

        end
      end
    end
  end


  task :cleanup do
    on roles(fetch(:stackose_role)) do
      within release_path do
        with fetch(:stackose_env) do
          tags_list = capture :docker, :images, fetch(:stackose_project).to_sym, '--format "{{.Tag}}"'

          list = tags_list.split
          list.delete('latest')

          releases = capture(:ls, "-x", releases_path).split

          (list - releases).each do |r|
            #delete image without release path
            execute :docker, :image, :rm, "#{fetch(:stackose_project)}:#{r}"
          end

        end
      end
    end
  end

  desc "Create online docker-compose file, use the linked_folders parameter to generate the hash form the compose file"
  task :create_online_docker_compose_file do

    ask(:exposed_port, 30000)
    ask(:server_name, 'example.tld')

    ask(:need_redis_service, true)


    compose_production = {
      version: '3',
      services: {
        app: {
          restart: 'unless-stopped',
          environment: {:RAILS_ENV => fetch(:rails_env).to_s,
                        :RAILS_SERVE_STATIC_FILES => 'true',
                        :RAILS_MAX_THREADS => 5,
                        :WEB_CONCURRENCY => 1},
          deploy: {
            replicas: 1,
            resources: {
              limits: {
                cpus: '0.50',
                memory: '250M'
              }
            }
          },
          volumes:
            normalized_stackose_linked_folders.collect do |k|
              k.join(':')
            end,
          ports: ["#{fetch(:exposed_port)}:3000"]
        }
      }
    }

    if fetch(:need_redis_service)
      compose_production[:services][:redis] = {
        restart: 'unless-stopped',
        image: 'redis',
        volumes: ["./config/redis.conf:/usr/local/etc/redis/redis.conf"],
        deploy: {
          resources: {
            limits: {
              memory: '50M'
            }
          }
        }
      }

      File.open("config/redis.conf", 'w') {|file| file.write("maxmemory 50mb\nmaxmemory-policy allkeys-lfu")}
    end

    nginx_config = "server {
      listen       80;
      server_name  #{fetch(:server_name)};
      location / {
          proxy_pass         http://0.0.0.0:#{fetch(:exposed_port)}/;
          proxy_redirect     off;

          proxy_set_header   Host             $host;
          proxy_set_header   X-Real-IP        $remote_addr;
          proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;

          client_max_body_size       10m;
          client_body_buffer_size    128k;

          proxy_connect_timeout      90;
          proxy_send_timeout         90;
          proxy_read_timeout         90;

          proxy_buffer_size          4k;
          proxy_buffers              4 32k;
          proxy_busy_buffers_size    64k;
          proxy_temp_file_write_size 64k;
       }
     }"

    puts "Configurazione NGINX:"
    puts nginx_config
    puts "Ricorda di cambiare anche la configurazione del database.yml per l'env specificato"
    puts "
    production:
      <<: *default
      pool: <%= ENV.fetch(\"RAILS_MAX_THREADS\") {5} %>
      database: /usr/share/application_storage/production.sqlite3
    "

    File.open("docker-compose-production.yml", 'w') {|file| file.write(JSON[compose_production.to_json].to_yaml)}
  end

end

namespace :load do
  task :defaults do
    set :stackose_role, -> {:web}
    set :stackose_copy, -> {[]}
    set :stackose_project, -> {fetch(:application)}
    set :stackose_file, -> {["docker-compose.yml", "docker-compose-#{fetch(:stage)}.yml"]}
    set :stackose_env, -> {{}}
    set :stackose_image_tag, -> {fetch(:release_timestamp)}
    set :stackose_service_to_build, -> {'app'}

    set :stackose_commands, -> {[]}

    set :stackose_linked_folders, -> {[]}
    set :stackose_docker_mount_point, -> {'/usr/share/www'}
  end
end
