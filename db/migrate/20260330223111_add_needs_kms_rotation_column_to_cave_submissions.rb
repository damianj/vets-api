class AddNeedsKmsRotationColumnToCaveSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :cave_submissions, :needs_kms_rotation, :boolean, default: false, null: false
  end
end
