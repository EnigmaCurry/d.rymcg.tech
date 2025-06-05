class AddEasyBaselineForToProject < ActiveRecord::Migration[6.1]
  def change
    add_reference :projects, :easy_baseline_for, index: true
  end
end
