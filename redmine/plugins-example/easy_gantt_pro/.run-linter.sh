#!/bin/bash -l

any_error=false

if [[ -d "plugins" ]]; then
  directory="plugins"
else
  directory="."
fi

for file in $(find $directory -name "*.rb" -type f -print); do
  ruby -wc $file 1>/dev/null
  [[ $? -eq 1 ]] && any_error=true
done

if [[ $any_error = "true" ]]; then
  exit 1
fi
