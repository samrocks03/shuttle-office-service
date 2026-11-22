# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::Hyperswitch do
  let(:base_url) { 'https://hyperswitch.test' }
  let(:api_key) { 'snd_test_api_key_do_not_leak' }
  let(:webhook_secret) { 'whsec_test_secret_do_not_leak' }
  let(:gateway) do
    described_class.new(base_url: base_url, api_key: api_key, profile_id: 'pro_shuttle123',
                        webhook_secret: webhook_secret)
  end

  def fixture(name)
    Rails.root.join("spec/fixtures/hyperswitch/#{name}.json").read
  end

  def json_response(name, status: 200)
    { status: status, body: fixture(name), headers: { 'Content-Type' => 'application/json' } }
  end

  describe Payments::Result do
    it 'exposes success, data and error' do
      ok = described_class.new(success: true, data: { id: 'x' })
      failed = described_class.new(success: false, error: 'boom')

      expect(ok).to be_success
      expect(ok.data).to eq(id: 'x')
      expect(ok.error).to be_nil
      expect(failed).not_to be_success
      expect(failed.data).to eq({})
      expect(failed.error).to eq('boom')
    end
  end

  describe '#create_payment' do
    let(:params) do
      { amount_minor: 3500, currency: 'INR', reference: 'res_abc123',
        customer_email: 'rider@example.com', return_url: 'https://app.example.com/payments/return' }
    end

    it 'POSTs /payments with the api-key header and the documented body' do
      stub = stub_request(:post, 'https://hyperswitch.test/payments')
             .with(
               headers: { 'api-key' => api_key, 'Content-Type' => 'application/json' },
               body: {
                 amount: 3500, currency: 'INR', confirm: false, capture_method: 'automatic',
                 profile_id: 'pro_shuttle123', email: 'rider@example.com',
                 return_url: 'https://app.example.com/payments/return',
                 metadata: { reservation_uid: 'res_abc123' }
               }
             )
             .to_return(json_response('payment_create'))

      gateway.create_payment(**params)

      expect(stub).to have_been_requested.once
    end

    it 'maps payment_id, client_secret and status into data' do
      stub_request(:post, 'https://hyperswitch.test/payments').to_return(json_response('payment_create'))

      result = gateway.create_payment(**params)

      expect(result).to be_success
      expect(result.error).to be_nil
      expect(result.data).to eq(
        id: 'pay_8Hq2Zk0vLxT3mNcWbR4e',
        client_secret: 'pay_8Hq2Zk0vLxT3mNcWbR4e_secret_Qw9xYtU1aBcD2eFgH3iJ',
        status: 'requires_payment_method'
      )
    end

    it 'tolerates a trailing slash on the base url' do
      slashed = described_class.new(base_url: "#{base_url}/", api_key: api_key, profile_id: 'p', webhook_secret: 's')
      stub = stub_request(:post, 'https://hyperswitch.test/payments').to_return(json_response('payment_create'))

      slashed.create_payment(**params)

      expect(stub).to have_been_requested
    end
  end

  describe '#fetch_payment' do
    it 'GETs /payments/:id without force_sync by default' do
      stub = stub_request(:get, 'https://hyperswitch.test/payments/pay_8Hq2Zk0vLxT3mNcWbR4e')
             .with(headers: { 'api-key' => api_key }, query: {})
             .to_return(json_response('payment_get'))

      gateway.fetch_payment('pay_8Hq2Zk0vLxT3mNcWbR4e')

      expect(stub).to have_been_requested.once
    end

    it 'adds force_sync=true only when sync: true' do
      stub = stub_request(:get, 'https://hyperswitch.test/payments/pay_8Hq2Zk0vLxT3mNcWbR4e')
             .with(query: { force_sync: 'true' })
             .to_return(json_response('payment_get'))

      gateway.fetch_payment('pay_8Hq2Zk0vLxT3mNcWbR4e', sync: true)

      expect(stub).to have_been_requested.once
    end

    it 'maps status, connector and the error message into data' do
      stub_request(:get, %r{/payments/pay_}).to_return(json_response('payment_get'))

      result = gateway.fetch_payment('pay_8Hq2Zk0vLxT3mNcWbR4e')

      expect(result).to be_success
      expect(result.data).to eq(
        id: 'pay_8Hq2Zk0vLxT3mNcWbR4e',
        status: 'failed',
        connector: 'razorpay',
        error: 'Your card was declined by the issuer'
      )
    end

    it 'falls back to error_code and then nil for data[:error]' do
      body = JSON.parse(fixture('payment_get')).merge('error_message' => nil)
      stub_request(:get, %r{/payments/pay_}).to_return(status: 200, body: body.to_json)
      expect(gateway.fetch_payment('pay_1').data[:error]).to eq('card_declined')

      body = body.merge('error_code' => nil)
      stub_request(:get, %r{/payments/pay_}).to_return(status: 200, body: body.to_json)
      expect(gateway.fetch_payment('pay_1').data[:error]).to be_nil
    end
  end

  describe '#cancel_payment' do
    it 'POSTs /payments/:id/cancel with a cancellation_reason' do
      stub = stub_request(:post, 'https://hyperswitch.test/payments/pay_8Hq2Zk0vLxT3mNcWbR4e/cancel')
             .with(headers: { 'api-key' => api_key }, body: { cancellation_reason: 'reservation_cancelled' })
             .to_return(json_response('payment_cancel'))

      result = gateway.cancel_payment('pay_8Hq2Zk0vLxT3mNcWbR4e')

      expect(stub).to have_been_requested.once
      expect(result).to be_success
      expect(result.data).to eq(id: 'pay_8Hq2Zk0vLxT3mNcWbR4e', status: 'cancelled')
    end
  end

  describe '#create_refund' do
    it 'POSTs /refunds with payment_id, amount and reason' do
      stub = stub_request(:post, 'https://hyperswitch.test/refunds')
             .with(
               headers: { 'api-key' => api_key, 'Content-Type' => 'application/json' },
               body: { payment_id: 'pay_8Hq2Zk0vLxT3mNcWbR4e', amount: 3500, reason: 'Reservation cancelled by rider' }
             )
             .to_return(json_response('refund_create'))

      result = gateway.create_refund(payment_id: 'pay_8Hq2Zk0vLxT3mNcWbR4e', amount_minor: 3500,
                                     reason: 'Reservation cancelled by rider')

      expect(stub).to have_been_requested.once
      expect(result).to be_success
      expect(result.data).to eq(id: 'ref_5Tn7Ym2pQsV8wXzA1bC3', status: 'pending')
    end
  end

  describe '#fetch_refund' do
    it 'GETs /refunds/:id and maps refund_id and status' do
      stub = stub_request(:get, 'https://hyperswitch.test/refunds/ref_5Tn7Ym2pQsV8wXzA1bC3')
             .with(headers: { 'api-key' => api_key })
             .to_return(json_response('refund_get'))

      result = gateway.fetch_refund('ref_5Tn7Ym2pQsV8wXzA1bC3')

      expect(stub).to have_been_requested.once
      expect(result).to be_success
      expect(result.data).to eq(id: 'ref_5Tn7Ym2pQsV8wXzA1bC3', status: 'succeeded')
    end
  end

  describe 'error handling' do
    it 'maps a 4xx Hyperswitch error body to a failed result with error.message' do
      stub_request(:post, 'https://hyperswitch.test/payments').to_return(json_response('error', status: 400))

      result = gateway.create_payment(amount_minor: 0, currency: 'INR', reference: 'r',
                                      customer_email: 'a@b.c', return_url: 'https://x.test')

      expect(result).not_to be_success
      expect(result.error).to eq('Missing required param: amount')
      expect(result.data).to eq({})
    end

    it 'maps errors on every call, not only create' do
      stub_request(:get, %r{/refunds/}).to_return(json_response('error', status: 404))
      stub_request(:post, %r{/refunds\z}).to_return(json_response('error', status: 400))
      stub_request(:post, %r{/cancel\z}).to_return(json_response('error', status: 400))
      stub_request(:get, %r{/payments/}).to_return(json_response('error', status: 404))

      results = [
        gateway.fetch_refund('ref_1'),
        gateway.create_refund(payment_id: 'pay_1', amount_minor: 1, reason: 'r'),
        gateway.cancel_payment('pay_1'),
        gateway.fetch_payment('pay_1')
      ]

      expect(results.map(&:success?)).to all(be(false))
      expect(results.map(&:error)).to all(eq('Missing required param: amount'))
    end

    it 'reports a generic error for a non-JSON error body' do
      stub_request(:get, %r{/payments/}).to_return(status: 502, body: '<html>Bad gateway</html>')

      result = gateway.fetch_payment('pay_1')

      expect(result).not_to be_success
      expect(result.error).to eq('Hyperswitch request failed (HTTP 502)')
    end

    it 'fails (does not raise) on a 2xx with an unparseable body' do
      stub_request(:get, %r{/payments/}).to_return(status: 200, body: 'not json')

      result = gateway.fetch_payment('pay_1')

      expect(result).not_to be_success
      expect(result.error).to eq('Hyperswitch returned an invalid response')
    end

    it 'maps a timeout to a failed result' do
      stub_request(:post, 'https://hyperswitch.test/payments').to_timeout

      result = gateway.create_payment(amount_minor: 3500, currency: 'INR', reference: 'r',
                                      customer_email: 'a@b.c', return_url: 'https://x.test')

      expect(result).not_to be_success
      expect(result.error).to eq('Hyperswitch request failed (Net::OpenTimeout)')
    end

    [
      Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Errno::EPIPE, Errno::ENETUNREACH,
      SocketError, EOFError, IOError, Net::HTTPBadResponse, Net::ProtocolError, Net::WriteTimeout,
      Timeout::Error, OpenSSL::SSL::SSLError
    ].each do |error_class|
      it "maps #{error_class} to a failed result" do
        stub_request(:get, %r{/payments/}).to_raise(error_class)

        result = gateway.fetch_payment('pay_1')

        expect(result).not_to be_success
        expect(result.error).to start_with('Hyperswitch request failed')
      end
    end

    it 'never puts the api key or webhook secret in an error string' do
      stub_request(:get, %r{/payments/}).to_raise(SocketError.new("failed with #{api_key}"))

      result = gateway.fetch_payment('pay_1')

      expect(result.error).not_to include(api_key)
      expect(result.error).not_to include(webhook_secret)
    end

    it 'uses 10 second open and read timeouts' do
      http = instance_double(Net::HTTP, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil)
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return(fixture('payment_get'))
      allow(http).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:new).with('hyperswitch.test', 443).and_return(http)

      gateway.fetch_payment('pay_1')

      expect(http).to have_received(:use_ssl=).with(true)
      expect(http).to have_received(:open_timeout=).with(10)
      expect(http).to have_received(:read_timeout=).with(10)
    end
  end

  describe '#verify_webhook' do
    let(:raw_body) { '{"event_type":"payment_succeeded","content":{"object":{"payment_id":"pay_1"}}}' }
    let(:signature) { OpenSSL::HMAC.hexdigest('SHA512', webhook_secret, raw_body) }

    it 'accepts a valid signature' do
      expect(gateway.verify_webhook(raw_body: raw_body, headers: { 'x-webhook-signature-512' => signature })).to be(true)
    end

    it 'accepts any header-key casing and rack-style keys' do
      ['X-Webhook-Signature-512', 'X-WEBHOOK-SIGNATURE-512', 'HTTP_X_WEBHOOK_SIGNATURE_512'].each do |key|
        expect(gateway.verify_webhook(raw_body: raw_body, headers: { key => signature })).to be(true), key
      end
    end

    it 'rejects a signature made with another secret' do
      bad = OpenSSL::HMAC.hexdigest('SHA512', 'other', raw_body)

      expect(gateway.verify_webhook(raw_body: raw_body, headers: { 'x-webhook-signature-512' => bad })).to be(false)
    end

    it 'rejects a body that differs by a single byte' do
      expect(
        gateway.verify_webhook(raw_body: "#{raw_body} ", headers: { 'x-webhook-signature-512' => signature })
      ).to be(false)
    end

    it 'rejects a missing or blank header' do
      expect(gateway.verify_webhook(raw_body: raw_body, headers: {})).to be(false)
      expect(gateway.verify_webhook(raw_body: raw_body, headers: { 'x-webhook-signature-512' => '' })).to be(false)
      expect(gateway.verify_webhook(raw_body: raw_body, headers: nil)).to be(false)
    end

    it 'rejects when the webhook secret is blank, even with a matching empty-key signature' do
      keyless = described_class.new(base_url: base_url, api_key: api_key, profile_id: 'p', webhook_secret: '')
      forged = OpenSSL::HMAC.hexdigest('SHA512', '', raw_body)

      expect(keyless.verify_webhook(raw_body: raw_body, headers: { 'x-webhook-signature-512' => forged })).to be(false)
    end
  end
end
