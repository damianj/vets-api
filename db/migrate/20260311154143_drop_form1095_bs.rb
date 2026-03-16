# frozen_string_literal: true

class DropForm1095Bs < ActiveRecord::Migration[7.2]
  def change
    drop_table :form1095_bs, id: :uuid, if_exists: true do |t|
      t.string :veteran_icn, null: false
      t.integer :tax_year, null: false
      t.jsonb :form_data_ciphertext, null: false
      t.text :encrypted_kms_key
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.boolean :needs_kms_rotation, default: false, null: false

      t.index [:veteran_icn, :tax_year], name: 'index_form1095_bs_on_veteran_icn_and_tax_year', unique: true
      t.index [:needs_kms_rotation], name: 'index_form1095_bs_on_needs_kms_rotation'
    end
  end
end
