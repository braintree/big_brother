module BigBrother
  class Configuration
    def self.evaluate(file, current_clusters)
      yaml = YAML.load(File.read(file))
      assoc_array = yaml.map do |name, values|
        new_nodes = _parse_nodes(values.delete('nodes'), current_clusters[name])
        [name, Cluster.new(name, values.merge('nodes' => new_nodes))]
      end

      Hash[assoc_array]
    end

    def self._parse_nodes(nodes, current_cluster)
      nodes.map do |values|
        old_node = _find_node_in_cluster(current_cluster, values['address'], values['port'])

        node_attrs = _symbolize_keys(values)
        node_attrs.merge!({:start_time => old_node.start_time, :weight => old_node.weight}) if old_node

        Node.new(node_attrs)
      end
    end

    def self._symbolize_keys(hash)
      hash.inject({}) {|memo,(key, value)| memo[key.to_sym] = value; memo }
    end

    def self._find_node_in_cluster(cluster, address, port)
      return nil if cluster.nil?
      cluster.nodes.find{|node| node.address == address && node.port == port}
    end
  end
end
