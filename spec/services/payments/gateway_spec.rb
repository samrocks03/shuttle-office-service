# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::Gateway do
  before do
    allow(ENV).to receive(:[]).and_call_original
  end

  it 'returns the gateway a spec injected' do
    fake = FakeGateway.new
    described_class.current = fake

    expect(described_class.current).to be(fake)
  end

  it 'raises NotConfigured when HYPERSWITCH_URL is not set' do
    allow(ENV).to receive(:[]).with('HYPERSWITCH_URL').and_return(nil)

    expect { described_class.current }.to raise_error(Payments::NotConfigured, /HYPERSWITCH_URL/)
  end

  it 'raises NotConfigured naming the missing key when only the URL is set' do
    allow(ENV).to receive(:[]).with('HYPERSWITCH_URL').and_return('https://hyperswitch.test')
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('HYPERSWITCH_API_KEY').and_raise(KeyError.new('key not found', key: 'HYPERSWITCH_API_KEY', receiver: ENV))
    stub_const('Payments::Hyperswitch', Class.new { def initialize(**) = nil })

    expect { described_class.current }.to raise_error(Payments::NotConfigured, /HYPERSWITCH_API_KEY/)
  end
end
