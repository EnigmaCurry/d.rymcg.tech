resources :projects do
  resources :easy_baselines, :except => [:show, :edit, :update]
end

resources :easy_baseline_gantt, :only => :show

