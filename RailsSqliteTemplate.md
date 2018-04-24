
### Template Per Rails e Alchemy


`
set :assets_dir, %w(public/system/. uploads/. public/pages/. public/noimage/.)
set :local_assets_dir, %w(../../shared/public/system ../../shared/uploads ../../shared/public/pages ../../shared/public/noimage)

set :stackose_copy, %w(config/secrets.yml)

set :stackose_commands, ['run --rm --no-deps app rails assets:precompile', 'run --rm  --no-deps app rails db:migrate']

set :stackose_linked_folders, [  'tmp/pids',
                               'tmp/cache',
                               'tmp/sockets',
                               'public/system',
                               'public/pictures',
                               'public/attachments',
                               'public/pages',
                               'public/assets',
                               'uploads',
                               :"__shared_path__/db_volume"=>"/usr/share/application_storage"
]
`