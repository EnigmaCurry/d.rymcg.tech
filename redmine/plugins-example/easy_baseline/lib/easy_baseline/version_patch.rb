module EasyBaseline
  module VersionPatch

    def self.prepended(base)
      base.class_eval do

        after_save :create_baseline_from_copy, if: :copy?

        attr_accessor :copied_from

        def copy?
          @copied_from.present?
        end

        private

          def create_baseline_from_copy
            return if self.project.easy_baseline_for_id.nil?
            EasyBaselineSource.create(baseline_id: self.project_id, relation_type: 'Version', source_id: @copied_from.id, destination_id: self.id)
          end

      end
    end

  end
end
Version.prepend EasyBaseline::VersionPatch

