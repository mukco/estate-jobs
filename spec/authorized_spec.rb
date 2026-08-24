# frozen_string_literal: true

require "estate/jobs"

RSpec.describe Estate::Jobs do
  describe ".authorized?" do
    it "accepts the right bearer value" do
      expect(described_class.authorized?("Bearer sekrit", "sekrit")).to be(true)
      expect(described_class.authorized?("sekrit", "sekrit")).to be(true)
    end

    it "refuses wrong, empty and missing tokens" do
      expect(described_class.authorized?("Bearer wrong", "sekrit")).to be(false)
      expect(described_class.authorized?("Bearer ", "sekrit")).to be(false)
      expect(described_class.authorized?("Bearer sekrit", "")).to be(false)
      expect(described_class.authorized?("Bearer sekrit", nil)).to be(false)
    end
  end
end
