# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

# Files uploaded as part of a form526 submission that will be sent to EVSS upon form submission.
# Documents may be routed to either the Benefits Documents API (Lighthouse) or the Benefits Intake API,
# so we validate against the constraints of both APIs at upload time.
class SupportingEvidenceAttachmentUploader < EVSSClaimDocumentUploaderBase
  # Virus scanning from Lighthouse Benefits Documents API constraints
  include UploaderVirusScan

  # Maximum filename length to avoid filesystem errors (ENAMETOOLONG)
  # Linux/macOS typically allow 255 chars, but CarrierWave temp files append suffixes.
  # CarrierWave's temp filenames (e.g., during retrieve_from_store!) add a timestamp and random
  # component to the original filename (roughly 25–35 extra characters such as
  # "_20240101-1234-1a2b3c4d5e"). Limiting the base filename to 100 characters keeps the final
  # temp path well under common 255-character filesystem limits, even if the pattern changes slightly.
  MAX_FILENAME_LENGTH = 100

  # Override the inherited EVSS 99MB limit to match the Benefits Intake API's 100MB limit.
  # Without this, CarrierWave rejects PDFs between 99–100MB before Benefits Intake validation runs.
  def size_range
    (1.byte)..(100.megabytes)
  end

  before :store, :validate_with_benefits_intake_constraints
  before :store, :log_transaction_start
  after :store, :log_transaction_complete

  def initialize(guid, _unused = nil)
    # carrierwave allows only 2 arguments, which they will pass onto
    # different versions by calling the initialize function again
    # so the _unused argument is necessary

    super
    @guid = guid

    #  defaults to CarrierWave::Storage::File if not AWS
    if Rails.env.production?
      set_aws_config(
        Settings.evss.s3.aws_access_key_id,
        Settings.evss.s3.aws_secret_access_key,
        Settings.evss.s3.region,
        Settings.evss.s3.bucket
      )
    end
  end

  def store_dir
    raise 'missing guid' if @guid.blank?

    "disability_compensation_supporting_form/#{@guid}"
  end

  # Override CarrierWave's filename method to shorten long filenames
  # This ensures the stored filename is short enough to avoid ENAMETOOLONG errors
  # when CarrierWave later creates temp files during retrieve_from_store!
  def filename
    base_filename = super
    return base_filename if base_filename.nil?

    shorten_filename(base_filename)
  end

  def log_transaction_start(uploaded_file = nil)
    log = {
      process_id: Process.pid,
      filesize: uploaded_file.try(:size),
      upload_start: Time.current
    }

    Rails.logger.info(log)
  end

  def log_transaction_complete(uploaded_file = nil)
    log = {
      process_id: Process.pid,
      filesize: uploaded_file.try(:size),
      upload_complete: Time.current
    }

    Rails.logger.info(log)
  end

  private

  # Validates PDF files against Benefits Intake API constraints (page dimensions, file size)
  # using the existing PDFUtilities::PDFValidator. Non-PDF files are skipped since Benefits Intake
  # only accepts PDFs. Encryption checking is disabled here because the ValidatePdf concern
  # (inherited from EVSSClaimDocumentUploaderBase) already handles encrypted PDFs in a prior
  # before :store callback — duplicating it would produce conflicting error types.
  BENEFITS_INTAKE_VALIDATOR_OPTIONS = BenefitsIntake::Service::PDF_VALIDATOR_OPTIONS.merge(
    check_encryption: false
  ).freeze

  def validate_with_benefits_intake_constraints(file)
    return unless Flipper.enabled?(:disability_compensation_upload_dual_api_validation)
    return unless File.extname(file.path).casecmp('.pdf').zero?

    result = PDFUtilities::PDFValidator::Validator.new(
      file.path, BENEFITS_INTAKE_VALIDATOR_OPTIONS
    ).validate
    return if result.valid_pdf?

    raise CarrierWave::IntegrityError, result.errors.join('. ')
  end

  # Override to gate virus scanning behind the feature toggle and convert VirusFoundError
  # into a CarrierWave::IntegrityError so it surfaces as a 422 with a safe message.
  def validate_virus_free(file)
    return unless Flipper.enabled?(:disability_compensation_upload_dual_api_validation)

    super
  rescue UploaderVirusScan::VirusFoundError
    raise CarrierWave::IntegrityError, 'We were unable to process your file. Please try again.'
  end

  # Shortens a filename to MAX_FILENAME_LENGTH while preserving the extension
  def shorten_filename(filename)
    return filename if filename.length <= MAX_FILENAME_LENGTH

    extension = File.extname(filename)
    basename = File.basename(filename, extension)
    max_basename_length = MAX_FILENAME_LENGTH - extension.length

    "#{basename[0, max_basename_length]}#{extension}"
  end
end
