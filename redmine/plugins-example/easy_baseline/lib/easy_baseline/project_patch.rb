module EasyBaseline
  module ProjectPatch

    def self.prepended(base)
      base.prepend InstanceMethods
      base.singleton_class.prepend(ClassMethods)

      base.class_eval do
        belongs_to :easy_baseline_for, class_name: 'Project'
        has_many :easy_baseline_sources, foreign_key: 'baseline_id'

        before_save :prevent_unarchive_easy_baseline
      end
    end

    module InstanceMethods

      def baseline_root?
        identifier == EasyBaseline::IDENTIFIER
      end

      def copy_versions(project)
        super

        if self.easy_baseline_for_id == project.id
          self.versions.each do |v|
            v.copied_from = project.versions.detect{|cv| cv.name == v.name }
            v.save
          end
        end
      end

      def allows_to(action)
        return true if easy_baseline_for_id && archived?

        super
      end

      def validate_custom_field_values_with_easy_baseline
        if baseline_root? && archived?
          true
        else
          super
        end
      end

      private

        def validate_parent_with_easy_baseline
          if @unallowed_parent_id
            errors.add(:parent_id, :invalid)
          elsif parent_id_changed?
            if parent.present? && (!parent.active? || !move_possible?(parent)) && !parent.baseline_root?
              errors.add(:parent_id, :invalid)
            end
          end
        end

        def prevent_unarchive_easy_baseline
          if (easy_baseline_for_id || baseline_root?) && status_changed? && !archived?
            errors.add(:status, :invalid)
            return false
          end
        end

    end

    module ClassMethods

      def allowed_to_condition(user, permission, options={}, &block)
        condition = super

        if options[:easy_baseline].present?
          condition.gsub!("#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND", "")
        end
        condition
      end

    end
  end
end
Project.prepend EasyBaseline::ProjectPatch

