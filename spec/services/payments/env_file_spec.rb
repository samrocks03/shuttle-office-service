# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::EnvFile do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, '.env') }

  after { FileUtils.remove_entry(dir) }

  it 'updates and adds only the given keys, keeps every other line, and sets mode 600' do
    File.write(path, "# keep me\nDATABASE_NAME=shuttle\n\nHYPERSWITCH_API_KEY=old\nSTRIPE_SECRET_KEY=sk_live_x\n")
    File.chmod(0o644, path)

    written = described_class.new(path).merge!('HYPERSWITCH_API_KEY' => 'new', 'HYPERSWITCH_PROFILE_ID' => 'pro_1')

    expect(written).to eq(%w[HYPERSWITCH_API_KEY HYPERSWITCH_PROFILE_ID])
    expect(File.read(path)).to eq(
      "# keep me\nDATABASE_NAME=shuttle\n\nHYPERSWITCH_API_KEY=new\nSTRIPE_SECRET_KEY=sk_live_x\nHYPERSWITCH_PROFILE_ID=pro_1\n"
    )
    expect(File.stat(path).mode & 0o777).to eq(0o600)
  end

  it 'writes through a symlink and leaves the link in place' do
    target = File.join(dir, 'real.env')
    File.write(target, "A=1\n")
    File.symlink(target, path)

    described_class.new(path).merge!('B' => '2')

    expect(File.symlink?(path)).to be(true)
    expect(File.read(target)).to eq("A=1\nB=2\n")
  end

  it 'reads values and returns an empty hash for a missing file' do
    File.write(path, "# c\nA=1\nB=\"two\"\n")

    expect(described_class.new(path).read).to eq('A' => '1', 'B' => 'two')
    expect(described_class.new(File.join(dir, 'none')).read).to eq({})
  end
end
