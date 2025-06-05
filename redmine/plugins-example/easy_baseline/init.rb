Redmine::Plugin.register :easy_baseline do
  name 'Easy Baseline'
  author 'Easy Software Ltd'
  url 'https://www.easysoftware.com'
  author_url 'https://www.easysoftware.com'
  description 'Allow to create a snapshot of a project in time.'
  version '3.0'
end

require_relative 'after_init'

