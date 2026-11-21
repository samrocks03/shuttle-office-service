# frozen_string_literal: true

namespace :payments do
  desc 'Set up the local Hyperswitch for the shuttle app (profile, webhook, API key, connectors, routing, BINs)'
  task setup_hyperswitch: :environment do
    env_file = Payments::EnvFile.new(Rails.root.join('.env'))
    saved = env_file.read
    setting = ->(name) { ENV[name].presence || saved[name].presence }

    base_url = ENV['HYPERSWITCH_URL'].presence || 'http://localhost:8080'
    admin_key = ENV['HYPERSWITCH_ADMIN_API_KEY'].presence || 'test_admin'
    hyperswitch_dir = ENV['HYPERSWITCH_DIR'].presence || File.join(Dir.home, 'Documents', 'hyperswitch')

    puts "Setting up Hyperswitch at #{base_url}"
    begin
      merchant_id = ENV['HYPERSWITCH_MERCHANT_ID'].presence ||
                    Payments::HyperswitchSetup.default_merchant_id(base_url: base_url, hyperswitch_dir: hyperswitch_dir)
      puts "  merchant #{merchant_id}"

      result = Payments::HyperswitchSetup.new(
        base_url: base_url,
        admin_api_key: admin_key,
        merchant_id: merchant_id,
        existing_api_key: setting.call('HYPERSWITCH_API_KEY'),
        on_api_key: ->(key) { env_file.merge!('HYPERSWITCH_API_KEY' => key) },
        keys: {
          stripe_secret: setting.call('STRIPE_TEST_SECRET_KEY'),
          razorpay_key_id: setting.call('RAZORPAY_TEST_KEY_ID'),
          razorpay_key_secret: setting.call('RAZORPAY_TEST_KEY_SECRET')
        }
      ).call
    rescue Payments::HyperswitchSetup::Error, SystemCallError => e
      abort "Hyperswitch setup failed: #{e.message}"
    end

    written = env_file.merge!(result[:env].merge('HYPERSWITCH_URL' => base_url))
    puts "Wrote #{written.join(', ')} to .env"
  end

  desc 'Start the refund status sync (RefundSyncJob reschedules itself every 10 minutes). Run once per environment.'
  task start_refund_sync: :environment do
    RefundSyncJob.perform_later
    puts 'Queued RefundSyncJob'
  end
end
