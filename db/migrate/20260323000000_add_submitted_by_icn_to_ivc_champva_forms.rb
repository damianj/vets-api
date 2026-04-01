# frozen_string_literal: true

class AddSubmittedByIcnToIvcChampvaForms < ActiveRecord::Migration[7.2]
  def change
    add_column :ivc_champva_forms, :submitted_by_icn, :string,
               comment: 'ICN of the authenticated user who submitted the form. ' \
                        'Null for unauthenticated submissions or forms created before this column existed.',
               if_not_exists: true
  end
end
