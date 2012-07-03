module BigBrother
  class IPVS
    def initialize(executor = ShellExecutor.new)
      @executor = executor
    end

    def start_cluster(fwmark, scheduler, persistent)
      @executor.invoke("ipvsadm --add-service --fwmark-service #{fwmark} --scheduler #{scheduler} --persistent #{persistent}")
    end

    def stop_cluster(fwmark)
      @executor.invoke("ipvsadm --delete-service --fwmark-service #{fwmark}")
    end

    def edit_node(fwmark, address, weight)
      @executor.invoke("ipvsadm --edit-server --fwmark-service #{fwmark} --real-server #{address} --ipip --weight #{weight}")
    end

    def start_node(fwmark, address, weight)
      @executor.invoke("ipvsadm --add-server --fwmark-service #{fwmark} --real-server #{address} --ipip --weight #{weight}")
    end

    def stop_node(fwmark, address)
      @executor.invoke("ipvsadm --delete-server --fwmark-service #{fwmark} --real-server #{address}")
    end

    def running_configuration
      raw_output, status = @executor.invoke("ipvsadm --save --numeric")

      parsed_lines = raw_output.split("\n").map do |line|
        next if line =~ /-A/
        {
          :fwmark => line.slice(/-f (\d+)/, 1),
          :real_server => line.slice(/-r ([0-9\.]+)/, 1)
        }
      end

      _group_by_fwmark(parsed_lines.compact)
    end


    def _group_by_fwmark(parsed_lines)
      parsed_lines.inject({}) do |accum, parsed_line|
        accum[parsed_line[:fwmark]] ||= []
        accum[parsed_line[:fwmark]] << parsed_line[:real_server]

        accum
      end
    end
  end
end
