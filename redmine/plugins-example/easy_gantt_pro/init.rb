Redmine::Plugin.register :easy_gantt_pro do
  name 'PRO Easy Gantt'
  author 'Easy Software Ltd'
  url 'https://www.easysoftware.com'
  author_url 'https://www.easysoftware.com'
  description 'PRO version'
  version '3.0'

  requires_redmine_plugin :easy_gantt, version_or_higher: '3.0'
end

require_relative 'after_init'

