class CreateCaveSubmission < ActiveRecord::Migration[7.2]
  def change
    create_table :cave_submissions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.bigint :saved_claim_id
      t.string :cave_response_ciphertext
      t.text :encrypted_kms_key
      t.timestamps
      t.index ["saved_claim_id"], name: "index_cave_submissions_on_saved_claim_id"
    end
  end
end
