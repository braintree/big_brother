module BigBrother
  class IPVS
    def initialize(executor = ShellExecutor.new)
      @executor = executor
    end

    def start_cluster(fwmark, scheduler)
      @executor.invoke("ipvsadm --add-service --fwmark-service #{fwmark} --scheduler #{scheduler}")
    end

    def edit_node(fwmark, address, weight)
      @executor.invoke("ipvsadm --edit-server --fwmark-service #{fwmark} --real-server #{address} --ipip --weight #{weight}")
    end

    def start_node(fwmark, address, weight)
      @executor.invoke("ipvsadm --add-server --fwmark-service #{fwmark} --real-server #{address} --ipip --weight #{weight}")
    end
  end
end
