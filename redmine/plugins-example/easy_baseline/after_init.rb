lib_dir = File.join(File.dirname(__FILE__), 'lib', 'easy_baseline')

# Redmine patches
patch_path = File.join(lib_dir, '*_patch.rb')
Dir.glob(patch_path).each do |file|
  require file
end

require lib_dir
require File.join(lib_dir, 'hooks')

Redmine::AccessControl.map do |map|
  map.project_module :easy_baselines do |pmap|
    pmap.permission :view_baselines, {
      easy_baselines: [:index, :show],
      easy_baseline_gantt: [:show]
    }
    pmap.permission :edit_baselines, {
      easy_baselines: [:create, :destroy, :new]
    }
  end
end
