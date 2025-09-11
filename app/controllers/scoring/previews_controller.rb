# frozen_string_literal: true

module Scoring
  # Dev-only controller for credit scoring preview
  class PreviewsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_preview_allowed!

    def show
      @service = Accounts::Services::CreditScoringService.new(current_user)
      @current_score = current_user.current_score
      @breakdown = @service.breakdown
      @total_contribution = @breakdown.values.sum { |v| v[:contribution].to_f }
    end

    def create
      @service = Accounts::Services::CreditScoringService.new(current_user)
      @new_score = @service.compute!(persist: true, emit_event: true)

      redirect_to scoring_preview_path, notice: "Score recomputed: #{@new_score}"
    end

    private

    def ensure_preview_allowed!
      unless Rails.env.development? || Rails.configuration.x.scoring.preview_enabled
        raise ActionController::RoutingError, "Not Found"
      end
    end
  end
end
