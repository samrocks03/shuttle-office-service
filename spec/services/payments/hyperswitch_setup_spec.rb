# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::HyperswitchSetup do
  # A small stateful stand-in for the Hyperswitch admin API, so a second run sees what the first made.
  class FakeHyperswitch # rubocop:disable Lint/ConstantDefinitionInBlock
    attr_reader :profiles, :connectors, :routes, :api_keys, :bins, :requests, :created

    def initialize(merchant_id)
      @merchant_id = merchant_id
      @profiles = []
      @connectors = []
      @routes = []
      @api_keys = []
      @bins = []
      @active_route = nil
      @requests = []
      @created = []
      @fail_connector_with = nil
    end

    def fail_connector_with(body)
      @fail_connector_with = body
    end

    def respond(request)
      uri = request.uri
      body = request.body.to_s.empty? ? {} : JSON.parse(request.body)
      @requests << [request.method, uri.path, body]
      status, data = route(request.method, uri.path, uri.query, body, request.headers['Api-Key'])
      { status: status, body: data.to_json, headers: { 'Content-Type' => 'application/json' } }
    end

    def route(verb, path, query, body, key)
      mid = @merchant_id
      case [verb, path]
      in [:get, "/accounts/#{mid}"] then [200, { publishable_key: 'pk_fake_publishable' }]
      in [:get, "/account/#{mid}/business_profile"] then api_key_valid?(key) ? [200, @profiles] : [401, {}]
      in [:post, "/account/#{mid}/business_profile"] then api_key_valid?(key) ? create_profile(body) : [401, {}]
      in [:post, %r{\A/account/#{mid}/business_profile/(.+)\z}] then update_profile(Regexp.last_match(1), body)
      in [:post, "/api_keys/#{mid}"] then create_api_key(body)
      in [:get, "/account/#{mid}/connectors"] then [200, @connectors]
      in [:post, "/account/#{mid}/connectors"] then create_connector(body)
      in [:post, %r{\A/account/#{mid}/connectors/(.+)\z}] then update_connector(Regexp.last_match(1), body)
      in [:get, '/routing/active'] then [200, @active_route ? [{ id: @active_route[:id] }] : []]
      in [:get, %r{\A/routing/(.+)\z}] then [200, @routes.find { |r| r[:id] == Regexp.last_match(1) }]
      in [:post, '/routing'] then create_route(body)
      in [:post, %r{\A/routing/(.+)/activate\z}] then activate_route(Regexp.last_match(1))
      in [:post, '/cards/create'] then create_bin(body)
      end
    end

    def create_profile(body)
      profile = { profile_id: "pro_#{@profiles.size + 1}", profile_name: body['profile_name'],
                  payment_response_hash_key: 'whsec_fake_hash_key' }
      @profiles << profile
      @created << "profile #{body['profile_name']}"
      [200, profile]
    end

    def update_profile(profile_id, body)
      profile = @profiles.find { |p| p[:profile_id] == profile_id }
      profile.merge!(body.transform_keys(&:to_sym))
      [200, profile]
    end

    def api_key_valid?(key)
      @api_keys.any? { |k| k[:api_key] == key }
    end

    def create_api_key(body)
      key = { name: body['name'], api_key: "snd_fake_api_key_#{@api_keys.size + 1}" }
      @api_keys << key
      @created << "api key #{body['name']}"
      [200, key]
    end

    def create_connector(body)
      return [500, @fail_connector_with] if @fail_connector_with

      connector = body.transform_keys(&:to_sym).merge(
        merchant_connector_id: "mca_#{@connectors.size + 1}",
        connector_name: body['connector_name']
      )
      @connectors << connector
      @created << "connector #{body['connector_name']}"
      [200, connector]
    end

    def update_connector(id, body)
      connector = @connectors.find { |c| c[:merchant_connector_id] == id }
      connector.merge!(body.transform_keys(&:to_sym))
      [200, connector]
    end

    def create_route(body)
      route = { id: "routing_#{@routes.size + 1}", profile_id: body['profile_id'],
                algorithm: { type: 'priority', data: body.dig('algorithm', 'data') } }
      @routes << route
      @created << 'routing rule'
      [200, route]
    end

    def activate_route(id)
      @active_route = @routes.find { |r| r[:id] == id }
      [200, @active_route]
    end

    def create_bin(body)
      return [400, { error: { message: 'Card info already exists' } }] if @bins.include?(body['card_iin'])

      @bins << body['card_iin']
      @created << "bin #{body['card_iin']}"
      [200, body]
    end
  end

  let(:base_url) { 'http://hyperswitch.test' }
  let(:merchant_id) { 'merchant_fake_1' }
  let(:hyperswitch) { FakeHyperswitch.new(merchant_id) }
  let(:out) { StringIO.new }
  let(:all_keys) do
    { stripe_secret: 'sk_test_SECRETSTRIPE', razorpay_key_id: 'rzp_test_SECRETID', razorpay_key_secret: 'SECRETRAZORPAY' }
  end
  let(:keys) { all_keys }

  def build_setup(existing_api_key: nil)
    described_class.new(base_url: base_url, admin_api_key: 'admin_SECRETADMIN', merchant_id: merchant_id,
                        keys: keys, existing_api_key: existing_api_key, out: out)
  end

  before do
    stub_request(:any, /\Ahttp:\/\/hyperswitch\.test/).to_return { |request| hyperswitch.respond(request) }
  end

  describe '#call' do
    it 'creates the shuttle profile with the webhook URL, payment events and automatic retries' do
      result = build_setup.call

      profile = hyperswitch.profiles.first
      expect(hyperswitch.profiles.size).to eq(1)
      expect(profile[:profile_name]).to eq('shuttle')
      expect(profile[:webhook_details]).to include(
        'webhook_url' => 'http://host.docker.internal:3000/api/v1/webhooks/hyperswitch',
        'payment_created_enabled' => true, 'payment_succeeded_enabled' => true, 'payment_failed_enabled' => true
      )
      expect(profile).to include(is_auto_retries_enabled: true, max_auto_retries_enabled: 2)
      expect(result[:profile_id]).to eq('pro_1')
    end

    it 'connects stripe_test, stripe and razorpay on that profile in test mode' do
      build_setup.call

      by_name = hyperswitch.connectors.index_by { |c| c[:connector_name] }
      expect(by_name.keys).to contain_exactly('stripe_test', 'stripe', 'razorpay')
      expect(by_name.values).to all(include(profile_id: 'pro_1', test_mode: true))
      stripe_methods = by_name['stripe'][:payment_methods_enabled].first
      expect(stripe_methods['payment_method']).to eq('card')
      expect(stripe_methods['payment_method_types'].first['accepted_currencies'])
        .to eq('type' => 'enable_only', 'list' => %w[INR USD])
      upi = by_name['razorpay'][:payment_methods_enabled].first
      expect(upi['payment_method']).to eq('upi')
      expect(upi['payment_method_types'].first).to include('payment_method_type' => 'upi_collect')
    end

    it 'routes stripe first, then stripe_test, then razorpay' do
      build_setup.call

      mca = hyperswitch.connectors.to_h { |c| [c[:connector_name], c[:merchant_connector_id]] }
      order = hyperswitch.routes.last[:algorithm][:data].map { |c| c['merchant_connector_id'] }
      expect(order).to eq([mca['stripe'], mca['stripe_test'], mca['razorpay']])
    end

    it 'adds the card BIN rows and returns the values for .env' do
      result = build_setup.call

      expect(hyperswitch.bins).to contain_exactly('424242', '411111', '400005', '555555', '520082')
      expect(result[:env]).to eq(
        'HYPERSWITCH_PROFILE_ID' => 'pro_1',
        'HYPERSWITCH_API_KEY' => 'snd_fake_api_key_1',
        'HYPERSWITCH_WEBHOOK_SECRET' => 'whsec_fake_hash_key',
        'HYPERSWITCH_PUBLISHABLE_KEY' => 'pk_fake_publishable'
      )
    end

    it 'creates nothing on a second run' do
      first = build_setup.call
      created_after_first = hyperswitch.created.dup
      out.truncate(0)
      out.rewind

      second = build_setup(existing_api_key: first[:env]['HYPERSWITCH_API_KEY']).call

      expect(hyperswitch.created).to eq(created_after_first)
      expect(hyperswitch.profiles.size).to eq(1)
      expect(hyperswitch.connectors.size).to eq(3)
      expect(hyperswitch.routes.size).to eq(1)
      expect(second[:env]).to eq(first[:env])
      expect(out.string).to include('found').and include('unchanged')
    end

    it 'hands over the API key before the later steps, so a failure cannot lose it' do
      hyperswitch.fail_connector_with(error: { message: 'boom' })
      saved = []
      setup = described_class.new(base_url: base_url, admin_api_key: 'admin_SECRETADMIN', merchant_id: merchant_id,
                                  keys: keys, on_api_key: ->(key) { saved << key }, out: out)

      expect { setup.call }.to raise_error(Payments::HyperswitchSetup::Error)
      expect(saved).to eq([hyperswitch.api_keys.first[:api_key]])
    end

    context 'when no processor keys are set' do
      let(:keys) { { stripe_secret: nil, razorpay_key_id: '', razorpay_key_secret: nil } }

      it 'connects only stripe_test and says what was skipped' do
        build_setup.call

        expect(hyperswitch.connectors.map { |c| c[:connector_name] }).to eq(['stripe_test'])
        expect(hyperswitch.routes.last[:algorithm][:data].size).to eq(1)
        expect(out.string).to include('stripe: skipped').and include('razorpay: skipped')
      end
    end

    context 'when a processor key is absent but its connector already exists on the profile' do
      it 'keeps that connector and keeps it in the routing order' do
        first = build_setup.call
        mca = hyperswitch.connectors.to_h { |c| [c[:connector_name], c[:merchant_connector_id]] }
        razorpay_before = hyperswitch.connectors.find { |c| c[:connector_name] == 'razorpay' }.dup

        rerun = described_class.new(base_url: base_url, admin_api_key: 'admin_SECRETADMIN', merchant_id: merchant_id,
                                    keys: { stripe_secret: keys[:stripe_secret] },
                                    existing_api_key: first[:env]['HYPERSWITCH_API_KEY'], out: out)
        result = rerun.call

        expect(result[:connector_ids].keys).to eq(%w[stripe stripe_test razorpay])
        order = hyperswitch.routes.last[:algorithm][:data].map { |c| c['merchant_connector_id'] }
        expect(order).to eq([mca['stripe'], mca['stripe_test'], mca['razorpay']])
        expect(hyperswitch.routes.size).to eq(1)
        expect(hyperswitch.connectors.find { |c| c[:connector_name] == 'razorpay' }).to eq(razorpay_before)
        expect(out.string).to include('razorpay: found, kept')
      end

      it 'routes the kept stripe connector first when only razorpay keys are given' do
        first = build_setup.call
        mca = hyperswitch.connectors.to_h { |c| [c[:connector_name], c[:merchant_connector_id]] }

        described_class.new(base_url: base_url, admin_api_key: 'admin_SECRETADMIN', merchant_id: merchant_id,
                            keys: keys.except(:stripe_secret),
                            existing_api_key: first[:env]['HYPERSWITCH_API_KEY'], out: out).call

        order = hyperswitch.routes.last[:algorithm][:data].map { |c| c['merchant_connector_id'] }
        expect(order).to eq([mca['stripe'], mca['stripe_test'], mca['razorpay']])
      end
    end

    describe 'test keys only' do
      it 'refuses a Stripe key that is not sk_test_, naming the variable but not the value' do
        live_like = 'rk_live_NOTATESTKEY123'
        setup = described_class.new(base_url: base_url, admin_api_key: 'admin_SECRETADMIN', merchant_id: merchant_id,
                                    keys: keys.merge(stripe_secret: live_like), out: out)

        expect { setup.call }.to raise_error(Payments::HyperswitchSetup::Error) do |error|
          expect(error.message).to include('STRIPE_TEST_SECRET_KEY').and include('sk_test_')
          expect(error.message).not_to include(live_like)
        end
        expect(hyperswitch.requests).to be_empty
      end

      it 'refuses a Razorpay key id that is not rzp_test_, naming the variable but not the value' do
        live_like = 'rzp_live_NOTATESTKEY'
        setup = described_class.new(base_url: base_url, admin_api_key: 'admin_SECRETADMIN', merchant_id: merchant_id,
                                    keys: keys.merge(razorpay_key_id: live_like), out: out)

        expect { setup.call }.to raise_error(Payments::HyperswitchSetup::Error) do |error|
          expect(error.message).to include('RAZORPAY_TEST_KEY_ID').and include('rzp_test_')
          expect(error.message).not_to include(live_like)
        end
        expect(hyperswitch.requests).to be_empty
      end
    end

    describe 'blank values for .env' do
      def stub_route(path_to_override, response)
        allow(hyperswitch).to receive(:route).and_wrap_original do |original, verb, path, *rest|
          path == path_to_override ? response : original.call(verb, path, *rest)
        end
      end

      it 'raises, naming the value, when the merchant has no publishable key' do
        stub_route("/accounts/#{merchant_id}", [200, { publishable_key: '' }])

        expect { build_setup.call }.to raise_error(Payments::HyperswitchSetup::Error, /HYPERSWITCH_PUBLISHABLE_KEY/)
      end

      it 'raises when the profile has no webhook signing secret' do
        allow(hyperswitch).to receive(:update_profile).and_wrap_original do |original, *args|
          status, profile = original.call(*args)
          [status, profile.merge(payment_response_hash_key: nil)]
        end

        expect { build_setup.call }.to raise_error(Payments::HyperswitchSetup::Error, /HYPERSWITCH_WEBHOOK_SECRET/)
      end

      it 'raises and hands over nothing when Hyperswitch returns a blank API key' do
        stub_route("/api_keys/#{merchant_id}", [200, { api_key: '' }])
        saved = []
        setup = described_class.new(base_url: base_url, admin_api_key: 'admin_SECRETADMIN', merchant_id: merchant_id,
                                    keys: keys, on_api_key: ->(key) { saved << key }, out: out)

        expect { setup.call }.to raise_error(Payments::HyperswitchSetup::Error, /HYPERSWITCH_API_KEY/)
        expect(saved).to be_empty
      end
    end

    it 'puts none of the secret values in its output' do
      result = build_setup.call
      build_setup(existing_api_key: result[:env]['HYPERSWITCH_API_KEY']).call

      secrets = all_keys.values + ['admin_SECRETADMIN'] + result[:env].values_at('HYPERSWITCH_API_KEY',
                                                                                  'HYPERSWITCH_WEBHOOK_SECRET')
      secrets.each { |secret| expect(out.string).not_to include(secret) }
    end

    it 'keeps secrets out of the error when Hyperswitch echoes them back' do
      hyperswitch.fail_connector_with(error: { message: 'bad key sk_test_SECRETSTRIPE' })

      expect { build_setup.call }.to raise_error(Payments::HyperswitchSetup::Error) do |error|
        expect(error.message).to include('Create stripe').and include('500')
        expect(error.message).not_to include('sk_test_SECRETSTRIPE')
      end
    end
  end

  describe '.default_merchant_id' do
    it 'signs in as the default user of the Hyperswitch checkout and reads the merchant id' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'scripts'))
        File.write(File.join(dir, 'scripts', 'create_default_user.sh'), "EMAIL=\"a@b.test\"\nPASSWORD=\"pw-123\"\n")
        signin = stub_request(:post, "#{base_url}/user/signin")
                 .with(body: { email: 'a@b.test', password: 'pw-123' }.to_json)
                 .to_return(status: 200, body: { token: 'tok', token_type: 'user_info' }.to_json)
        stub_request(:get, "#{base_url}/user").with(headers: { 'Authorization' => 'Bearer tok' })
                                              .to_return(status: 200, body: { merchant_id: 'merchant_x' }.to_json)

        expect(described_class.default_merchant_id(base_url: base_url, hyperswitch_dir: dir)).to eq('merchant_x')
        expect(signin).to have_been_requested
      end
    end
  end
end
