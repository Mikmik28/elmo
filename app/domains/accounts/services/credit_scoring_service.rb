# frozen_string_literal: true

module Accounts
  module Services
    # Deterministic, rule-based credit scoring service
    class CreditScoringService
      def initialize(user)
        @user = user
      end

      def compute!(persist: false, emit_event: false)
        old_score = @user.current_score
        score = calculate_score.to_i

        if persist
          @user.transaction do
            @user.update!(current_score: score)

            if score != old_score
              create_credit_score_event!(score - old_score)
            end
          end
        end

        if emit_event && score != old_score
          emit_score_changed_event!(old_score, score)
        end

        score
      end

      def breakdown
        {
          payment_history: {
            raw_value: payment_history_rate,
            normalized: payment_history_component,
            weight: weights[:payment_history],
            contribution: payment_history_component * weights[:payment_history]
          },
          utilization: {
            raw_value: utilization_rate,
            normalized: utilization_component,
            weight: weights[:utilization],
            contribution: utilization_component * weights[:utilization]
          },
          tenure: {
            raw_value: account_age_days,
            normalized: tenure_component,
            weight: weights[:tenure],
            contribution: tenure_component * weights[:tenure]
          },
          behavior: {
            raw_value: recent_behavior_score,
            normalized: behavior_component,
            weight: weights[:behavior],
            contribution: behavior_component * weights[:behavior]
          },
          kyc: {
            raw_value: kyc_approved?,
            normalized: kyc_component,
            weight: weights[:kyc],
            contribution: kyc_component * weights[:kyc]
          }
        }
      end

      private

      attr_reader :user

      def calculate_score
        weighted_score = base_score +
                        (payment_history_component * weights[:payment_history]) +
                        (utilization_component * weights[:utilization]) +
                        (tenure_component * weights[:tenure]) +
                        (behavior_component * weights[:behavior]) +
                        (kyc_component * weights[:kyc])

        clamp_score(weighted_score)
      end

      def payment_history_component
        # Map on-time rate [0..1] to [-100..+100] linearly
        rate = payment_history_rate
        BigDecimal((rate * 200 - 100).to_s)
      end

      def utilization_component
        # Lower utilization is better: 0→+100, ≥0.9→-100 (piecewise linear)
        rate = utilization_rate

        if rate <= BigDecimal("0.0")
          BigDecimal("100")
        elsif rate >= BigDecimal("0.9")
          BigDecimal("-100")
        else
          # Linear interpolation: 100 - (rate / 0.9) * 200
          BigDecimal("100") - (rate / BigDecimal("0.9")) * BigDecimal("200")
        end
      end

      def tenure_component
        # ≥365 days → +100, ≤7 days → -50, interpolate
        days = account_age_days

        case days
        when 0..7
          BigDecimal("-50")
        when 8..364
          # Linear interpolation from -50 to +100
          BigDecimal("-50") + ((BigDecimal(days.to_s) - BigDecimal("7")) / BigDecimal("357")) * BigDecimal("150")
        else
          BigDecimal("100")
        end
      end

      def behavior_component
        # If any overdue/defaulted in last 90 days → -100
        # Else scale by number of recent on-time payments (cap at +100)
        return BigDecimal("-100") if has_recent_delinquency?

        on_time_count = recent_on_time_payments_count
        # Cap at +100, scale by 10 points per on-time payment
        [ BigDecimal("100"), BigDecimal(on_time_count.to_s) * BigDecimal("10") ].min
      end

      def kyc_component
        kyc_approved? ? BigDecimal("100") : BigDecimal("0")
      end

      # Data retrieval methods
      def payment_history_rate
        @payment_history_rate ||= calculate_payment_history_rate
      end

      def calculate_payment_history_rate
        twelve_months_ago = 12.months.ago

        total_payments = user.loans
                            .joins(:payments)
                            .where(payments: { created_at: twelve_months_ago.. })
                            .count

        return BigDecimal("0.5") if total_payments.zero? # Neutral for no history

        on_time_payments = user.loans
                              .joins(:payments)
                              .where(payments: { created_at: twelve_months_ago.. })
                              .where("payments.created_at <= loans.due_on")
                              .count

        BigDecimal(on_time_payments.to_s) / BigDecimal(total_payments.to_s)
      end

      def utilization_rate
        @utilization_rate ||= Queries::UtilizationQuery.new(user).call
      end

      def account_age_days
        @account_age_days ||= (Date.current - user.created_at.to_date).to_i
      end

      def recent_behavior_score
        @recent_behavior_score ||= has_recent_delinquency? ? -100 : recent_on_time_payments_count * 10
      end

      def has_recent_delinquency?
        ninety_days_ago = 90.days.ago
        user.loans
            .where(state: %w[overdue defaulted])
            .where("updated_at >= ?", ninety_days_ago)
            .exists?
      end

      def recent_on_time_payments_count
        ninety_days_ago = 90.days.ago
        user.loans
            .where(state: "paid")
            .joins(:payments)
            .where(payments: { created_at: ninety_days_ago.. })
            .where("payments.created_at <= loans.due_on")
            .distinct
            .count
      end

      def kyc_approved?
        user.kyc_approved?
      end

      # Configuration helpers
      def weights
        @weights ||= Rails.configuration.x.scoring.weights
      end

      def bounds
        @bounds ||= Rails.configuration.x.scoring.bounds
      end

      def base_score
        @base_score ||= BigDecimal(bounds[:base].to_s)
      end

      def clamp_score(score)
        [ [ bounds[:min], score.to_i ].max, bounds[:max] ].min
      end

      # Persistence helpers
      def create_credit_score_event!(delta)
        user.credit_score_events.create!(
          reason: "recompute",
          delta: delta,
          meta: {
            scoring_components: breakdown.transform_values { |v| v[:contribution].to_f }
          }
        )
      end

      def emit_score_changed_event!(old_score, new_score)
        OutboxEvent.publish!(
          name: "user.score_changed.v1",
          aggregate: user,
          payload: {
            user_id: user.id,
            old_score: old_score,
            new_score: new_score
          }
        )
      end
    end
  end
end
