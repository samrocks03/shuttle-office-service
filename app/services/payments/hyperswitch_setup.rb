# frozen_string_literal: true

require 'net/http'
require 'json'

module Payments
  # Makes a local Hyperswitch ready for the shuttle app: a "shuttle" business profile with the webhook
  # URL and automatic retries, an API key, the stripe_test / stripe / razorpay connectors, a priority
  # routing rule, and the card BIN rows. It finds what exists before it creates anything, so a second
  # run creates nothing.
  #
  # #call returns ids plus the values for .env under :env. That hash holds secrets: print names only.
  class HyperswitchSetup
    class Error < StandardError; end

    PROFILE_NAME = 'shuttle'
    API_KEY_NAME = 'shuttle-office-service'
    WEBHOOK_URL = 'http://host.docker.internal:3000/api/v1/webhooks/hyperswitch'
    MAX_AMOUNT = 68_607_706
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30

    # First six digits of common test cards: [iin, network, credit or debit].
    BINS = [
      %w[424242 Visa credit], %w[411111 Visa credit], %w[400005 Visa debit],
      %w[555555 Mastercard credit], %w[520082 Mastercard debit]
    ].freeze

    Response = Struct.new(:status, :data) do
      def ok?
        status.between?(200, 299)
      end
    end

    def self.default_merchant_id(base_url:, hyperswitch_dir:)
      new(base_url: base_url, admin_api_key: nil, merchant_id: nil).default_merchant_id(hyperswitch_dir)
    end

    # on_api_key is called with the API key as soon as it exists, so a caller can save it before
    # the later steps run (a lost key cannot be read back from Hyperswitch).
    def initialize(base_url:, admin_api_key:, merchant_id:, keys: {}, existing_api_key: nil, on_api_key: nil,
                   out: $stdout)
      @base_url = base_url.chomp('/')
      @admin_api_key = admin_api_key
      @merchant_id = merchant_id
      @keys = keys
      @existing_api_key = existing_api_key
      @on_api_key = on_api_key
      @out = out
    end

    # Signs in as the default user the Hyperswitch checkout creates (scripts/create_default_user.sh)
    # and returns that user's merchant id.
    def default_merchant_id(hyperswitch_dir)
      script_path = File.join(hyperswitch_dir, 'scripts', 'create_default_user.sh')
      script = File.read(script_path)
      email = script[/^EMAIL="(.*)"$/, 1]
      password = script[/^PASSWORD="(.*)"$/, 1]
      raise Error, "No default user login found in #{script_path}" unless email && password

      signin = must(request(:post, '/user/signin', 'hyperswitch', { email: email, password: password }),
                    'Sign in as the default user')
      token = signin['token']
      if signin['token_type'] == 'totp'
        skipped = must(request(:get, '/user/2fa/terminate?skip_two_factor_auth=true', 'hyperswitch', nil,
                               'Authorization' => "Bearer #{token}"), 'Skip two-factor sign-in')
        token = skipped['token']
      end
      user = must(request(:get, '/user', 'hyperswitch', nil, 'Authorization' => "Bearer #{token}"),
                  'Read the default user')
      user['merchant_id']
    end

    def call
      merchant = must(request(:get, "/accounts/#{@merchant_id}", @admin_api_key), 'Read merchant')
      api_key = ensure_api_key
      @on_api_key&.call(api_key)
      profile_id = ensure_profile(api_key)
      webhook_secret = configure_profile(profile_id, api_key)
      connector_ids = ensure_connectors(profile_id, api_key)
      routing_id = ensure_routing(profile_id, api_key, connector_ids)
      ensure_bins

      {
        profile_id: profile_id,
        connector_ids: connector_ids,
        routing_id: routing_id,
        env: {
          'HYPERSWITCH_PROFILE_ID' => profile_id,
          'HYPERSWITCH_API_KEY' => api_key,
          'HYPERSWITCH_PUBLISHABLE_KEY' => merchant['publishable_key'],
          'HYPERSWITCH_WEBHOOK_SECRET' => webhook_secret
        }
      }
    end

    private

    def say(message)
      @out.puts "  #{message}"
    end

    # ---- profile, API key ---------------------------------------------------------------------

    def ensure_profile(api_key)
      profiles = must(request(:get, "/account/#{@merchant_id}/business_profile", api_key), 'List business profiles')
      found = profiles.find { |profile| profile['profile_name'] == PROFILE_NAME }
      if found
        say "profile #{PROFILE_NAME}: found (#{found['profile_id']})"
        return found['profile_id']
      end

      made = must(request(:post, "/account/#{@merchant_id}/business_profile", api_key,
                          { profile_name: PROFILE_NAME }), 'Create business profile')
      say "profile #{PROFILE_NAME}: created (#{made['profile_id']})"
      made['profile_id']
    end

    # Profile, connector and routing calls need the merchant's own API key, not the admin key.
    def ensure_api_key
      if @existing_api_key.to_s != '' &&
         request(:get, "/account/#{@merchant_id}/business_profile", @existing_api_key).ok?
        say "api key #{API_KEY_NAME}: reused from .env"
        return @existing_api_key
      end

      made = must(request(:post, "/api_keys/#{@merchant_id}", @admin_api_key,
                          { name: API_KEY_NAME, description: 'Server key of the shuttle app', expiration: 'never' }),
                  'Create API key')
      say "api key #{API_KEY_NAME}: created"
      made['api_key']
    end

    # Webhook URL and events, automatic retries. Returns the profile's webhook signing secret.
    def configure_profile(profile_id, api_key)
      profile = must(request(:post, "/account/#{@merchant_id}/business_profile/#{profile_id}", api_key, {
        webhook_details: {
          webhook_url: WEBHOOK_URL,
          payment_created_enabled: true,
          payment_succeeded_enabled: true,
          payment_failed_enabled: true
        },
        is_auto_retries_enabled: true,
        max_auto_retries_enabled: 2
      }), 'Update business profile')
      say "webhook URL set to #{WEBHOOK_URL}; payment events on; automatic retries on (2 more tries)"
      profile['payment_response_hash_key']
    end

    # ---- connectors ---------------------------------------------------------------------------

    def ensure_connectors(profile_id, api_key)
      existing = must(request(:get, "/account/#{@merchant_id}/connectors", api_key), 'List connectors')
      ids = {}
      wanted_connectors.each do |name, spec|
        if spec.nil?
          say "processor #{name}: skipped, #{skip_reason(name)}"
          next
        end

        body = connector_body(spec)
        found = existing.find { |c| c['connector_name'] == name && c['profile_id'] == profile_id }
        if found
          must(request(:post, "/account/#{@merchant_id}/connectors/#{found['merchant_connector_id']}", api_key, body),
               "Update #{name}")
          ids[name] = found['merchant_connector_id']
          say "processor #{name}: found, updated"
        else
          made = must(request(:post, "/account/#{@merchant_id}/connectors", api_key,
                              body.merge(connector_name: name, profile_id: profile_id, connector_label: "#{name}_shuttle")),
                      "Create #{name}")
          ids[name] = made['merchant_connector_id']
          say "processor #{name}: connected"
        end
      end
      ids
    end

    # In routing order. A nil spec means the key is missing, so the connector is skipped.
    def wanted_connectors
      {
        'stripe' => stripe_secret.empty? ? nil : { auth: { auth_type: 'HeaderKey', api_key: stripe_secret }, methods: card_methods },
        'stripe_test' => { auth: { auth_type: 'HeaderKey', api_key: 'shuttle_practice' }, methods: card_methods },
        'razorpay' => razorpay_keys? ? { auth: { auth_type: 'BodyKey', api_key: @keys[:razorpay_key_id], key1: @keys[:razorpay_key_secret] }, methods: upi_methods } : nil
      }
    end

    def skip_reason(name)
      name == 'stripe' ? 'no STRIPE_TEST_SECRET_KEY' : 'no RAZORPAY_TEST_KEY_ID and RAZORPAY_TEST_KEY_SECRET'
    end

    def stripe_secret
      @keys[:stripe_secret].to_s
    end

    def razorpay_keys?
      @keys[:razorpay_key_id].to_s != '' && @keys[:razorpay_key_secret].to_s != ''
    end

    def connector_body(spec)
      {
        connector_type: 'payment_processor',
        connector_account_details: spec[:auth],
        payment_methods_enabled: spec[:methods],
        test_mode: true,
        disabled: false,
        status: 'active'
      }
    end

    def card_methods
      [{ payment_method: 'card', payment_method_types: %w[credit debit].map do |type|
        {
          payment_method_type: type,
          card_networks: %w[Visa Mastercard],
          accepted_currencies: { type: 'enable_only', list: %w[INR USD] },
          minimum_amount: 1,
          maximum_amount: MAX_AMOUNT,
          recurring_enabled: false,
          installment_payment_enabled: false
        }
      end }]
    end

    def upi_methods
      [{ payment_method: 'upi', payment_method_types: [{
        payment_method_type: 'upi_collect',
        accepted_currencies: { type: 'enable_only', list: %w[INR] },
        minimum_amount: 1,
        maximum_amount: MAX_AMOUNT,
        recurring_enabled: false,
        installment_payment_enabled: false
      }] }]
    end

    # ---- routing ------------------------------------------------------------------------------

    # One priority rule: stripe, then stripe_test, then razorpay (only those that are connected).
    # Hyperswitch skips a connector that does not support the payment method, so cards go to the
    # Stripe ones and UPI goes to razorpay.
    def ensure_routing(profile_id, api_key, connector_ids)
      names = connector_ids.keys
      data = names.map { |name| { connector: name, merchant_connector_id: connector_ids[name] } }
      wanted = data.map { |c| c[:merchant_connector_id] }

      active = request(:get, "/routing/active?profile_id=#{profile_id}", api_key)
      active_id = active.ok? && active.data.is_a?(Array) ? active.data.first&.dig('id') : nil
      current = active_id ? request(:get, "/routing/#{active_id}", api_key).data : nil
      if current && current.dig('algorithm', 'data')&.map { |c| c['merchant_connector_id'] } == wanted
        say "routing: unchanged (#{names.join(' then ')})"
        return active_id
      end

      made = must(request(:post, '/routing', api_key,
                          { name: "shuttle-#{names.join('-')}", description: names.join(' then '),
                            profile_id: profile_id, algorithm: { type: 'priority', data: data } }),
                  'Create routing rule')
      must(request(:post, "/routing/#{made['id']}/activate", api_key, {}), 'Activate routing rule')
      say "routing: #{names.join(' then ')}"
      made['id']
    end

    # ---- card BIN rows ------------------------------------------------------------------------
    # Hyperswitch reads the first six digits of a card to learn credit or debit. A fresh local database
    # has no BIN table and refunds are then refused, so the same rows as the lab are added.

    def ensure_bins
      added = BINS.count do |iin, network, type|
        response = request(:post, '/cards/create', @admin_api_key,
                           { card_iin: iin, card_network: network, card_type: type, card_issuer: 'Test bank',
                             card_issuing_country: 'UNITEDSTATES', country_code: 'US' })
        next true if response.ok?

        raise Error, "Card BIN #{iin} failed (#{response.status}): #{error_text(response)}" unless
          error_text(response).match?(/exist|duplicate|unique/i)

        false
      end
      say "card BIN info: #{added} added, #{BINS.size - added} already there"
    end

    # ---- HTTP ---------------------------------------------------------------------------------

    def request(verb, path, api_key, body = nil, headers = {})
      uri = URI("#{@base_url}#{path}")
      req = Net::HTTP.const_get(verb.to_s.capitalize).new(uri)
      req['Content-Type'] = 'application/json'
      req['api-key'] = api_key if api_key
      headers.each { |name, value| req[name] = value }
      req.body = body.to_json unless body.nil?

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(req)
      end
      Response.new(res.code.to_i, parse(res.body))
    rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
      raise Error, "Hyperswitch is not reachable at #{@base_url} (#{e.class})"
    end

    def parse(text)
      text.to_s.empty? ? {} : JSON.parse(text)
    rescue JSON::ParserError
      { 'raw' => text.to_s }
    end

    def must(response, what)
      raise Error, "#{what} failed (#{response.status}): #{error_text(response)}" unless response.ok?

      response.data
    end

    # The server's own error message, with every secret this run holds blanked out.
    def error_text(response)
      data = response.data
      text = data.is_a?(Hash) ? (data.dig('error', 'message') || data['message'] || data['raw'] || data.to_s) : data.to_s
      redact(text.to_s)[0, 300]
    end

    def redact(text)
      secrets = [@admin_api_key, @existing_api_key, @keys[:stripe_secret], @keys[:razorpay_key_id], @keys[:razorpay_key_secret]]
      secrets.map(&:to_s).reject { |s| s.length < 4 }.reduce(text) { |t, s| t.gsub(s, '[redacted]') }
    end
  end
end
