class CreateEasyBaselineSources < ActiveRecord::Migration[6.1]
  def change
    create_table :easy_baseline_sources do |t|
      t.references :baseline, index: true
      t.references :source
      t.references :destination
      t.string :relation_type
    end
  end
end
