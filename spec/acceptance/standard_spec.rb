require 'spec_helper_acceptance'

describe 'nomad class' do
  context 'default parameters' do
    # Using puppet_apply as a helper
    it 'works with no errors based on the example' do
      pp = <<-EOS
        class { 'nomad':
          version     => '0.2.3',
          config_hash => {
            "region"     => 'us-west',
            "datacenter" => 'ptk',
            "log_level"  => 'INFO',
            "bind_dir"   => "0.0.0.0",
            "data_dir"   => "/var/lib/nomad",
            "server" => {
              "enabled"          => true,
              "bootstrap_expect" => 1
            }
          }
        }
      EOS

      # Run it twice and test for idempotency
      expect(apply_manifest(pp).exit_code).not_to eq(1)
      expect(apply_manifest(pp).exit_code).to eq(0)
    end

    describe file('/opt/nomad') do
      it { is_expected.to be_directory }
    end

    describe service('nomad') do
      it { is_expected.to be_enabled }
    end

    describe command('nomad version') do
      its(:stdout) { is_expected.to match %r{Nomad v0\.2\.3} }
    end
  end
end
