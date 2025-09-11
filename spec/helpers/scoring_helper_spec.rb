# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScoringHelper, type: :helper do
  describe "#normalize_partner_score" do
    it "maps scores from external range to canonical 300-950 range" do
      # Test mapping from TransUnion's typical 300-850 range
      result = helper.normalize_partner_score(750, from_min: 300, from_max: 850)
      expect(result).to be_between(300, 950)
      expect(result).to eq(832) # Linear interpolation: 750 maps to 832 in 300-950
    end

    it "clamps values below minimum to target minimum" do
      result = helper.normalize_partner_score(250, from_min: 300, from_max: 850)
      expect(result).to eq(300)
    end

    it "clamps values above maximum to target maximum" do
      result = helper.normalize_partner_score(900, from_min: 300, from_max: 850)
      expect(result).to eq(950)
    end

    it "handles edge case values correctly" do
      # Test exact boundaries
      expect(helper.normalize_partner_score(300, from_min: 300, from_max: 850)).to eq(300)
      expect(helper.normalize_partner_score(850, from_min: 300, from_max: 850)).to eq(950)
    end

    it "allows custom target range" do
      # Test mapping to a different target range
      result = helper.normalize_partner_score(500, from_min: 300, from_max: 850, to_min: 0, to_max: 100)
      expect(result).to be_between(0, 100)
      expect(result).to eq(36) # 500 maps to ~36 in 0-100 range
    end

    it "handles BigDecimal precision correctly" do
      result = helper.normalize_partner_score(575.5, from_min: 300, from_max: 850)
      expect(result).to be_a(Integer)
      expect(result).to be_between(300, 950)
    end
  end
end
