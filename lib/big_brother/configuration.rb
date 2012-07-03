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

    def self._parse_nodes(nodes)
      nodes.map do |values|
        Node.new(values['address'], values['port'], values['path'])
      end
    end
  end
end
