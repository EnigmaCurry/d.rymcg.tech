class EasyBaselineSource < ActiveRecord::Base

  belongs_to :baseline, class_name: 'Project'

  scope :issues, -> { where(:relation_type => 'Issue') }
  scope :versions, -> { where(:relation_type => 'Version') }

  scope :with_source, -> { where.not(:source_id => nil) }
  scope :without_source, -> { where(:source_id => nil) }

  scope :joins_source_versions, -> { joins("INNER JOIN #{Version.table_name} ON #{self.table_name}.source_id = #{Version.table_name}.id") }
  scope :joins_baseline_versions, -> { joins("INNER JOIN #{Version.table_name} ON #{self.table_name}.destination_id = #{Version.table_name}.id") }

  def source
    @source ||= self.relation_type.constantize.find(source_id)
  end

  def destination
    @destination ||= self.relation_type.constantize.find(destination_id)
  end

end
