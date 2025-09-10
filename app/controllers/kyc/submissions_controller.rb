# frozen_string_literal: true

module Kyc
  class SubmissionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user

    def show
      authorize @user, :show?, policy_class: Kyc::SubmissionPolicy
      @kyc_status = @user.kyc_status
      @kyc_submitted = @user.kyc_complete?
    end

    def new
      authorize @user, :new?, policy_class: Kyc::SubmissionPolicy
      @kyc_form_data = {
        full_name: @user.full_name,
        phone: @user.phone,
        date_of_birth: @user.date_of_birth
      }
    end

    def create
      authorize @user, :create?, policy_class: Kyc::SubmissionPolicy

      # Check for required files first
      unless kyc_params[:gov_id_image].present? && kyc_params[:selfie_image].present?
        flash.now[:alert] = "Both government ID and selfie images are required."
        @kyc_form_data = kyc_params.except(:gov_id_image, :selfie_image).to_h
        render :new, status: :unprocessable_content
        return
      end

      # Validate file types
      gov_id_file = kyc_params[:gov_id_image]
      selfie_file = kyc_params[:selfie_image]

      unless valid_image_type?(gov_id_file.content_type)
        flash.now[:alert] = "Government ID must be a PNG or JPEG image."
        @kyc_form_data = kyc_params.except(:gov_id_image, :selfie_image).to_h
        render :new, status: :unprocessable_content
        return
      end

      unless valid_image_type?(selfie_file.content_type)
        flash.now[:alert] = "Selfie must be a PNG or JPEG image."
        @kyc_form_data = kyc_params.except(:gov_id_image, :selfie_image).to_h
        render :new, status: :unprocessable_content
        return
      end

      # Extract and mask sensitive data for storage
      kyc_params_hash = kyc_params.to_h
      masked_payload = {
        gov_id_type: kyc_params_hash["gov_id_type"],
        gov_id_number_last4: kyc_params_hash["gov_id_number"]&.last(4),
        id_expiry: kyc_params_hash["id_expiry"],
        address_line1: kyc_params_hash["address_line1"],
        date_of_birth: kyc_params_hash["date_of_birth"]
      }

      ActiveRecord::Base.transaction do
        # Update user attributes
        @user.update!(
          full_name: kyc_params_hash["full_name"],
          date_of_birth: kyc_params_hash["date_of_birth"],
          kyc_payload: masked_payload,
          kyc_status: "pending"
        )

        # Attach files
        @user.kyc_gov_id_image.attach(kyc_params_hash["gov_id_image"])
        @user.kyc_selfie_image.attach(kyc_params_hash["selfie_image"])

        # Publish outbox event for KYC submission
        OutboxEvent.publish!(
          name: "kyc.submitted.v1",
          aggregate: @user,
          payload: { 
            user_id: @user.id,
            submission_timestamp: Time.current.iso8601,
            document_types: ["government_id", "selfie"]
          }
        )
      end

      flash[:notice] = "KYC documents submitted successfully. We'll review your submission shortly."
      redirect_to kyc_path
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = "Please correct the errors below: #{e.record.errors.full_messages.join(', ')}"
      @kyc_form_data = kyc_params.except(:gov_id_image, :selfie_image).to_h
      render :new, status: :unprocessable_content
    end

    def simulate_decision
      return head :not_found unless Rails.env.development?

      authorize @user, :simulate_decision?, policy_class: Kyc::SubmissionPolicy

      decision = params.require(:status)
      raise ArgumentError, "Invalid status" unless %w[approved rejected].include?(decision)

      @user.update!(kyc_status: decision)

      if decision == "approved"
        # Publish outbox event for approved KYC
        OutboxEvent.publish!(
          name: "kyc.approved.v1",
          aggregate: @user,
          payload: { 
            user_id: @user.id,
            approval_timestamp: Time.current.iso8601,
            previous_status: "pending"
          }
        )
        flash[:notice] = "KYC approved! You can now apply for loans."
      else
        flash[:alert] = "KYC was rejected. Please resubmit with correct documents."
      end

      redirect_to kyc_path
    end

    private

    def set_user
      @user = current_user
    end

    def kyc_params
      params.require(:kyc).permit(
        :full_name, :date_of_birth, :gov_id_type, :gov_id_number, :id_expiry, :address_line1,
        :gov_id_image, :selfie_image
      )
    end

    def valid_image_type?(content_type)
      %w[image/png image/jpeg].include?(content_type)
    end
  end
end
