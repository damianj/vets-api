class CreateAskVAInquirySubmissionTables < ActiveRecord::Migration[7.2]
  def change
    create_table :ask_va_inquiry_submissions do |t|
      t.string :crm_message_id
      t.string :inquiry_number

      t.timestamps
    end

    create_table :ask_va_inquiry_submission_checkpoints do |t|
      t.belongs_to :ask_va_inquiry_submission, null: false, foreign_key: true
      t.string :checkpoint_type, null: false
      t.text :payload_ciphertext, null: false
      t.text :encrypted_kms_key
      t.boolean :needs_kms_rotation, default: false, null: false

      t.timestamps
    end
  end
end
