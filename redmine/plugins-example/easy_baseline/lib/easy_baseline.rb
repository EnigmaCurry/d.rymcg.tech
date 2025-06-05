module EasyBaseline

  IDENTIFIER = 'easy_baselines-root'

  def self.baseline_root_project
    project = Project.find_by_identifier(IDENTIFIER)
    return project if project

    project = Project.new(identifier: IDENTIFIER)
    project.name = 'Easy Baselines Root'
    project.status = Project::STATUS_ARCHIVED
    project.is_public = false
    project.save!(validate: false)
    project

    # Project.where(identifier: IDENTIFIER).first_or_create! do |project|
    #   project.name = 'Easy Baselines Root'
    #   project.status = Project::STATUS_ARCHIVED
    #   project.is_public = false
    # end
  end

end
