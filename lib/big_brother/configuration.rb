module BigBrother
  class Configuration
    def self.evaluate(file)
      yaml = YAML.load(File.read(file))
      assoc_array = yaml.map do |name, values|
        nodes = _parse_nodes(values.delete('nodes'))
        [name, Cluster.new(name, values.merge('nodes' => nodes))]
      end

      Hash[assoc_array]
    end

    def self.synchronize_with_ipvs(clusters, ipvs_state)
      ipvs_state.each do |fwmark, running_nodes|
        running_cluster = clusters.values.detect { |cluster| cluster.fwmark == fwmark.to_i }

        if running_cluster.nil?
          BigBrother.ipvs.stop_cluster(fwmark)
        else
          running_cluster.resume_monitoring!

          running_nodes = ipvs_state[running_cluster.fwmark.to_s]
          cluster_nodes = running_cluster.nodes.map(&:address)

          _remove_nodes(running_cluster, running_nodes - cluster_nodes)
          _add_nodes(running_cluster, cluster_nodes - running_nodes)
        end
      end
    end

    def self._add_nodes(cluster, addresses)
      addresses.each do |address|
        BigBrother.logger.info "adding #{address} to cluster #{cluster}"
        BigBrother.ipvs.start_node(cluster.fwmark, address, 100)
      end
    end

    def self._remove_nodes(cluster, addresses)
      addresses.each do |address|
        BigBrother.logger.info "removing #{address} to cluster #{cluster}"
        BigBrother.ipvs.stop_node(cluster.fwmark, address)
      end
    end

    def self._parse_nodes(nodes)
      nodes.map do |values|
        Node.new(values['address'], values['port'], values['path'])
      end
    end

  end
end
