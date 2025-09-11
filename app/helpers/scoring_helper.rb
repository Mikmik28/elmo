# frozen_string_literal: true

module ScoringHelper
  # Normalize external partner credit scores to our canonical 300-950 range
  #
  # @param raw [Numeric] The raw score from external provider
  # @param from_min [Numeric] Minimum value of source range
  # @param from_max [Numeric] Maximum value of source range
  # @param to_min [Numeric] Minimum value of target range (default: 300)
  # @param to_max [Numeric] Maximum value of target range (default: 950)
  # @return [Integer] Normalized score in target range
  #
  # Example:
  #   normalize_partner_score(750, from_min: 300, from_max: 850)
  #   # => 815 (maps 750 from 300-850 range to 300-950 range)
  def normalize_partner_score(raw, from_min:, from_max:, to_min: 300, to_max: 950)
    return to_min if raw <= from_min
    return to_max if raw >= from_max

    # Linear interpolation
    ratio = BigDecimal((raw - from_min).to_s) / BigDecimal((from_max - from_min).to_s)
    normalized = BigDecimal(to_min.to_s) + (ratio * BigDecimal((to_max - to_min).to_s))

    normalized.round.to_i
  end
end
