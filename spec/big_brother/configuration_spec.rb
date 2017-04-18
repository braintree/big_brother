require 'spec_helper'

describe BigBrother::Configuration do
  describe 'self.from_file' do
    context 'loading invalid config' do
      before do
        @config_file = Tempfile.new('config.yml')
        File.open(@config_file, 'w') do |f|
          f.puts(<<-EOF)
---
clusters:
  - cluster_name: 1
    check_interval: ""
    scheduler: wrr
    fwmark: 1
    nodes:
      - address: 127.0.0
        port: 9001
        path: /test/valid
          EOF
        end
      end

      it 'fails' do
        BigBrother.configure(@config_file.path)

        BigBrother.clusters.size.should be_zero
      end

      it 'logs errors' do
        errors = ["- [/clusters/0/cluster_name] '1': not a string.", "- [/clusters/0/check_interval] '': not a integer.", "- [/clusters/0/nodes/0/address] '127.0.0': not matched to pattern /^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$/."]

        BigBrother.logger = NullLogger.new([])
        BigBrother::Configuration.from_file(@config_file.path)

        BigBrother.logger.messages.should == errors

        BigBrother.logger = NullLogger.new
      end
    end

    it 'maintains a collection of clusters' do
      clusters = BigBrother::Configuration.from_file(TEST_CONFIG)

      clusters['test1'].check_interval.should == 1
      clusters['test1'].scheduler.should == 'wrr'
      clusters['test1'].fwmark.should == 1
      clusters['test1'].ramp_up_time.should == 120
      clusters['test1'].has_downpage?.should == true
      clusters['test1'].nagios[:check].should == 'test1_status'
      clusters['test1'].nagios[:host].should == 'prod-load'
      clusters['test1'].nagios[:server].should == 'nsca.host'

      clusters['test2'].check_interval.should == 2
      clusters['test2'].scheduler.should == 'wrr'
      clusters['test2'].fwmark.should == 2

      clusters['test3'].check_interval.should == 1
      clusters['test3'].scheduler.should == 'wrr'
      clusters['test3'].fwmark.should == 3

      clusters['test4'].backend_mode.should == 'active_active'
      clusters['test4'].offset.should == 10000
      clusters['test4'].max_down_ticks.should == 100
      clusters['test4'].ramp_up_time.should == 60
      clusters['test4'].non_egress_locations.should == ['test']
    end

    it 'populates a clusters nodes' do
      clusters = BigBrother::Configuration.from_file(TEST_CONFIG)

      clusters['test1'].nodes.length.should == 2

      clusters['test1'].nodes[0].address.should == '127.0.0.1'
      clusters['test1'].nodes[0].port.should == 9001
      clusters['test1'].nodes[0].path.should == '/test/valid'

      clusters['test1'].nodes[1].address.should == '127.0.0.1'
      clusters['test1'].nodes[1].port.should == 9002
      clusters['test1'].nodes[1].path.should == '/test/valid'

      clusters['test4'].interpol_nodes.first.should be_interpol
    end

    it 'allows a default cluster configuration under the global config key' do
      config_file = Tempfile.new('config.yml')
      File.open(config_file, 'w') do |f|
        f.puts(<<-EOF.gsub(/^ {10}/,''))
          ---
          _big_brother:
            check_interval: 2
            nagios:
              server: 127.0.0.2
              host: ha-services
          clusters:
            - cluster_name: test_without_overrides
              scheduler: wrr
              fwmark: 2
              nagios:
                check: test_check
              nodes:
                - address: 127.0.0.1
                  port: 9001
                  path: /test/invalid
            - cluster_name: test_with_overrides
              fwmark: 3
              scheduler: wlc
              nagios:
                host: override-host
                check: test_overrides_check
              nodes:
                - address: 127.0.0.1
                  port: 9001
                  path: /test/invalid
        EOF
      end

      clusters = BigBrother::Configuration.from_file(config_file)

      clusters['test_without_overrides'].check_interval.should == 2
      clusters['test_without_overrides'].scheduler.should == 'wrr'
      clusters['test_without_overrides'].fwmark.should == 2
      clusters['test_without_overrides'].nagios[:server].should == '127.0.0.2'
      clusters['test_without_overrides'].nagios[:host].should == 'ha-services'
      clusters['test_without_overrides'].nagios[:check].should == 'test_check'


      clusters['test_with_overrides'].check_interval.should == 2
      clusters['test_with_overrides'].scheduler.should == 'wlc'
      clusters['test_with_overrides'].fwmark.should == 3
      clusters['test_with_overrides'].nagios[:server].should == '127.0.0.2'
      clusters['test_with_overrides'].nagios[:host].should == 'override-host'
      clusters['test_with_overrides'].nagios[:check].should == 'test_overrides_check'
    end
  end

  describe '_apply_defaults' do
    it 'returns a new hash with the defaults hash and the settings hash merged recursively' do
      defaults = {:foo => {:bar => 1}}
      settings = {:foo => {:baz => 2}}
      h = BigBrother::Configuration._apply_defaults(defaults, settings)
      h.should == {:foo => {:bar => 1, :baz => 2}}
    end
  end
end
