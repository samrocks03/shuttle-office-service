# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stop, type: :model do
  it 'rejects an unknown kind' do
    expect(build(:stop, kind: 'depot')).not_to be_valid
  end

  it 'scopes pickups, offices and active stops' do
    pickup = create(:stop)
    office = create(:stop, :office)
    inactive = create(:stop, active: false)

    expect(described_class.pickups).to include(pickup, inactive)
    expect(described_class.pickups).not_to include(office)
    expect(described_class.offices).to contain_exactly(office)
    expect(described_class.active).not_to include(inactive)
  end
end
