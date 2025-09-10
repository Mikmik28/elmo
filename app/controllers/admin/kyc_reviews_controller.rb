# frozen_string_literal: true

class Admin::KycReviewsController < Admin::BaseController
  before_action :set_user, only: [ :show, :approve, :reject ]

  def index
    authorize :admin_area, :access?
    @pending_kyc_users = User.where(kyc_status: "pending")
                             .where.not(kyc_payload: nil)
                             .includes(kyc_gov_id_image_attachment: :blob, kyc_selfie_image_attachment: :blob)
                             .order(:created_at)
  end

  def show
    authorize :admin_area, :access?
    @kyc_data = @user.kyc_payload
  end

  def approve
    authorize :admin_area, :access?

    @user.transaction do
      @user.update!(kyc_status: "approved")

      # Publish outbox event for approved KYC
      OutboxEvent.publish!(
        name: "kyc.approved.v1",
        aggregate: @user,
        payload: {
          user_id: @user.id,
          approval_timestamp: Time.current.iso8601,
          previous_status: "pending",
          approved_by: current_user.id
        }
      )
    end

    redirect_to admin_kyc_reviews_path, notice: "KYC approved for #{@user.full_name}"
  end

  def reject
    authorize :admin_area, :access?

    @user.update!(kyc_status: "rejected")

    redirect_to admin_kyc_reviews_path, alert: "KYC rejected for #{@user.full_name}"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end
end
