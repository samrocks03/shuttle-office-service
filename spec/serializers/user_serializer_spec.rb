# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSerializer do
  let(:user) { create(:user) }

  def serialize(**options)
    described_class.new(user, **options).as_json
  end

  it 'counts only active reservations' do
    create(:reservation, user: user, status: 'confirmed')
    create(:reservation, user: user, status: 'expired')
    create(:reservation, user: user, status: 'cancelled')

    expect(serialize(include_reservations_count: true)[:reservations_count]).to eq(1)
  end

  it 'has no reservations when the only one has expired' do
    create(:reservation, user: user, status: 'expired')

    expect(serialize(include_has_reservations: true)[:has_reservations]).to be false
  end
end
