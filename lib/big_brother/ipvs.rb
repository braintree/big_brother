module BigBrother
  class IPVS
    def initialize(executor = ShellExecutor.new)
      @executor = executor
    end

    def start_cluster(fwmark, scheduler)
      @executor.invoke("ipvsadm --add-service --fwmark-service #{fwmark} --scheduler #{scheduler}")
    end
  end
end
