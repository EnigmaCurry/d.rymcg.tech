module EasyBaseline
  module IssuePatch

    def self.prepended(base)
      base.class_eval do

        has_one :easy_baseline_source, -> { where(relation_type: 'Issue') }, class_name: 'EasyBaselineSource', foreign_key: :destination_id, dependent: :nullify
        has_many :easy_baseline_destinations, -> { where(relation_type: 'Issue') }, class_name: 'EasyBaselineSource', foreign_key: :source_id, dependent: :destroy

        after_save :create_baseline_from_copy, if: :copy?

        def create_baseline_from_copy
          return if self.project.easy_baseline_for_id.nil?

          EasyBaselineSource.create(baseline_id: self.project_id, relation_type: 'Issue', source_id: @copied_from.id, destination_id: self.id)
        end

      end
    end

  end
end
Issue.prepend EasyBaseline::IssuePatch

