# frozen_string_literal: true

require 'rails_helper'

describe ValidatePdf, :uploader_helpers do
  class ValidatePdfTest < CarrierWave::Uploader::Base
    include ValidatePdf
  end

  def store_image
    ValidatePdfTest.new.store!(file)
  end

  context 'with a file that is not a PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif') }

    it 'does not raise an error' do
      expect { store_image }.not_to raise_error
    end
  end

  context 'with a valid PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', 'application/pdf') }

    it 'does not raise an error' do
      expect { store_image }.not_to raise_error
    end
  end

  context 'with a user-password-protected PDF' do
    let(:file) do
      Rack::Test::UploadedFile.new('spec/fixtures/files/locked_pdf_password_is_test.pdf',
                                   'application/pdf')
    end

    it 'raises an error' do
      expect { store_image }
        .to raise_error(Common::Exceptions::UnprocessableEntity)
    end
  end

  context 'with a corrupted PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/malformed-pdf.pdf', 'application/pdf') }

    it 'raises an error' do
      expect { store_image }
        .to raise_error(Common::Exceptions::UnprocessableEntity)
    end
  end

  context 'with an owner-password-only PDF' do
    let(:file) do
      Rack::Test::UploadedFile.new('spec/fixtures/files/locked-pdf.pdf',
                                   'application/pdf')
    end

    context 'when pdf_allow_owner_encrypted_uploads is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:pdf_allow_owner_encrypted_uploads).and_return(true)
      end

      it 'does not raise an error' do
        expect { store_image }.not_to raise_error
      end
    end

    context 'when pdf_allow_owner_encrypted_uploads is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:pdf_allow_owner_encrypted_uploads).and_return(false)
      end

      it 'raises an error' do
        expect { store_image }
          .to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
