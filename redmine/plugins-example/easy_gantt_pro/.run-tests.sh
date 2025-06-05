#!/bin/bash -l

# -v print lines as they are read
# -x print lines as they are executed
# -e abort script at first error
set -e

if [[ $# -eq 0 ]]; then
  echo "You must set database adapter"
  exit 1
fi

export ADAPTER=$1
shift

case $ADAPTER in
  mysql2)
    export DB_USERNAME=$MYSQL_USERNAME
    export DB_PASSWORD=$MYSQL_PASSWORD
    ;;
  postgresql)
    export DB_USERNAME=$PG_USERNAME
    export DB_PASSWORD=$PG_PASSWROD
    ;;
  *) echo "You must set adapter mysql2 or postgresql"
     exit 1
esac

while [[ $# -ge 1 ]]; do
  arg=$1

  case $arg in
    # Show variables for debugging
    --show-variables) SHOW_VARIABLES="true"
                      ;;
    # Add plugins which are not part of EASY_BASE_REPO
    --add-plugins) shift
                   ADDITIONAL_PLUGINS=($(echo ${1//,/ }))
                   ;;
    # Remove plugins
    --remove-plugins) shift
                      UNDESIRED_PLUGINS=($(echo ${1//,/ }))
                      ;;
    *) # Nothing to do
       ;;
  esac
  shift
done

_plugin=($(echo $CI_REPOSITORY_URL | tr '/' ' '))
CURRENT_PLUGIN=${_plugin[-1]/.git/}
BASE_ROOT=$CI_PROJECT_DIR/.redmine
PLUGINS_ROOT=$BASE_ROOT/plugins
CURRENT_PLUGIN_ROOT=$PLUGINS_ROOT/$CURRENT_PLUGIN
COMMON_BRANCHES=(bleeding-edge devel release-candidate bug-fixing master)

# Try to find common branch as fallback for additional plugins
if [[ ${#ADDITIONAL_PLUGINS[@]} -ne 0 ]]; then
  # Get all ancestors branches
  # logs=$(git log --branches --source --oneline | awk '{print $2}' | uniq)
  logs=$(git log --oneline --merges | grep into | sed 's/.* into //g' | uniq | head -n 10 | tr -d "'")

  # Iterater through all ancestor branches until get first common branch
  for branch in $logs; do
    if [[ " ${COMMON_BRANCHES[@]} " = *" $branch "* ]]; then
      CLOSEST_COMMON_BRANCH=$branch
      break
    fi
  done
fi

if [[ $SHOW_VARIABLES = "true" ]]; then
  echo "EASY_BASE_REPO:" $EASY_BASE_REPO
  echo "BASE_ROOT:" $BASE_ROOT
  echo "CURRENT_PLUGIN:" $CURRENT_PLUGIN
  echo "ADDITIONAL_PLUGINS:" ${ADDITIONAL_PLUGINS[*]}
  echo "CLOSEST_COMMON_BRANCH:" $CLOSEST_COMMON_BRANCH
  echo "UNDESIRED_PLUGINS:" ${UNDESIRED_PLUGINS[*]}
fi

# Ensure deleteing database even if test failed
function before_exit {
  return_value=$?
  bundle exec rake db:drop
  exit $return_value
}

trap before_exit SIGHUP SIGINT SIGTERM EXIT

# Setup base easy project
[[ -d $BASE_ROOT ]] && rm -rf $BASE_ROOT
git clone --depth 1 ssh://git@git.easy.cz/$EASY_BASE_REPO.git $BASE_ROOT
cd $BASE_ROOT

# Init database
ruby -ryaml -rsecurerandom -e "
  database = 'redmine_'+SecureRandom.hex(8).to_s
  config = {
    'adapter' => ENV['ADAPTER'],
    'database' => database,
    'host' => '127.0.0.1',
    'username' => ENV['DB_USERNAME'],
    'password' => ENV['DB_PASSWORD'],
    'encoding' => 'utf8'
  }
  config = {
    'test' => config.merge({'database' => 'test_'+database}),
    'development' => config,
    'production' => config
  }.to_yaml
  File.write('config/database.yml', config)
"

# Init current plugin
[[ -d $CURRENT_PLUGIN_ROOT ]] && rm -rf $CURRENT_PLUGIN_ROOT
ln -s $CI_PROJECT_DIR $CURRENT_PLUGIN_ROOT

# Init other plugins
pushd $PLUGINS_ROOT
  for plugin in ${ADDITIONAL_PLUGINS[*]}; do
    echo "--> Init plugin: $plugin"

    [[ -d $plugin ]] && rm -rf $plugin
    git clone ssh://git@git.easy.cz/devel/$plugin.git $plugin

    pushd $plugin
      # Checkout to the same branch if exist
      if [[ $(git branch --remotes --list origin/$CI_COMMIT_REF_NAME) ]]; then
        echo "---> Checking out $CI_COMMIT_REF_NAME"
        git checkout $CI_COMMIT_REF_NAME
        git pull

      # If not try to use closest common branch
      elif [[ -n $CLOSEST_COMMON_BRANCH && -n $(git branch --remotes --list origin/$CLOSEST_COMMON_BRANCH) ]]; then
        echo "---> Checking out $CLOSEST_COMMON_BRANCH"
        git checkout $CLOSEST_COMMON_BRANCH
        git pull

      else
        echo "---> No common branch. Using default."
      fi
    popd
  done
popd

# Removal of undesired plugins
pushd $PLUGINS_ROOT
  for plugin in ${UNDESIRED_PLUGINS[*]}; do
    echo "--> Remove plugin: $plugin"

    if [[ -d $plugin ]]; then
      echo "---> Remove from plugins"
      rm -rf $plugin
    elif [[ -d easyproject/easy_plugins/$plugin ]]; then
      echo "---> Remove from easyproject/easy_plugins"
      rm -rf easyproject/easy_plugins/$plugin
    else
      echo "---> Plugin doesn't exist"
    fi
  done
popd

to_test="{$(echo ${ADDITIONAL_PLUGINS[*]} $CURRENT_PLUGIN | tr ' ' ',')}"

bundle update
bundle exec rake db:drop db:create db:migrate
bundle exec rake easyproject:install
bundle exec rake test:prepare RAILS_ENV=test
bundle exec rake easyproject:tests:spec NAME=$to_test RAILS_ENV=test
