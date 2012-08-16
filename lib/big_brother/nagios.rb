module BigBrother
  class Nagios
    module Code
      Ok       = 0
      Warning  = 1
      Critical = 2
      Unknown  = 3
    end

    def initialize(executor = ShellExecutor.new)
      @executor = executor
    end

    def send_critical(host, check, message, server)
      _send_passive(host, check, Code::Critical, "CRITICAL #{message}", server)
    end

    def send_ok(host, check, message, server)
      _send_passive(host, check, Code::Ok, "OK #{message}", server)
    end

    def send_warning(host, check, message, server)
      _send_passive(host, check, Code::Warning, "WARNING #{message}", server)
    end

    def _send_passive(host, check, code, message, server)
      @executor.invoke("echo '#{host},#{check},#{code},#{message}' | send_nsca -H #{server} -d ,")
    end
  end
end
