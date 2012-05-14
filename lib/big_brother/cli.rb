require 'thin'
module BigBrother
  class CLI < Rack::Server
    class Options
      def parse!(args)
        args, options = args.dup, {}

        opt_parser = OptionParser.new do |opts|
          opts.banner = "Usage: bigbro [options]"
          opts.on("-c", "--config=file", String,
                  "BigBrother configuration file", "Default: /etc/big_brother.conf") { |v| options[:big_brother_config] = v }
          opts.on("-D", "--data-dir=path", String,
                  "BigBrother data directory", "Default: /etc/big_brother") { |v| options[:config_dir] = v }

          opts.separator ""

          opts.on("-p", "--port=port", Integer,
                  "Runs BigBrother on the specified port.", "Default: 9292") { |v| options[:Port] = v }
          opts.on("-b", "--binding=ip", String,
                  "Binds BigBrother to the specified ip.", "Default: 0.0.0.0") { |v| options[:Host] = v }
          opts.on("-d", "--daemon", "Make server run as a Daemon.") { options[:daemonize] = true }
          opts.on("-P","--pid=pid",String,
                  "Specifies the PID file.",
                  "Default: rack.pid") { |v| options[:pid] = v }

          opts.separator ""

          opts.on("-h", "--help", "Show this help message.") { puts opts; exit }
        end

        opt_parser.parse! args

        options[:config] = File.expand_path("../../config.ru", File.dirname(__FILE__))
        options[:server] = 'thin-with-callbacks'
        options[:backend] = Thin::Backends::TcpServerWithCallbacks
        options
      end
    end

    def initialize(options = nil)
      super
    end

    def opt_parser
      Options.new
    end

    def start
      if !File.exists?(options[:big_brother_config])
        puts "Could not find #{options[:big_brother_config]}. Specify correct location with -c file"
        exit 1
      end

      BigBrother.config_dir = options[:config_dir]

      Thin::Callbacks.after_connect do
        EM.synchrony do
          BigBrother.configure(options[:big_brother_config])
          BigBrother.start_ticker!
        end
      end

      super
    end

    def default_options
      super.merge(
        :big_brother_config => '/etc/big_brother.conf',
        :config_dir => '/etc/big_brother'
      )
    end
  end
end
