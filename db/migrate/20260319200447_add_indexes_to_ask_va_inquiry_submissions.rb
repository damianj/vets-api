class AddIndexesToAskVAInquirySubmissions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :ask_va_inquiry_submissions, :crm_message_id, algorithm: :concurrently, if_not_exists: true
    add_index :ask_va_inquiry_submissions, :inquiry_number, algorithm: :concurrently, if_not_exists: true
    add_index :ask_va_inquiry_submission_checkpoints, :checkpoint_type, algorithm: :concurrently, if_not_exists: true
    add_index :ask_va_inquiry_submission_checkpoints, :needs_kms_rotation, algorithm: :concurrently, if_not_exists: true
  end
end
