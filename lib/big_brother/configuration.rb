module BigBrother
  class Configuration
    GLOBAL_CONFIG_KEY = '_big_brother'

    def self.from_file(config_file)
      config = YAML.load_file(config_file)
      return {} unless _valid?(config)

      configured_clusters = config.fetch("clusters")
      defaults = config.delete(GLOBAL_CONFIG_KEY)

      configured_clusters.inject({}) do |clusters, cluster|
        cluster_details = _apply_defaults(defaults, cluster)
        cluster_name    = cluster.fetch("cluster_name")
        #clusters.merge(cluster_name => BigBrother::ClusterFactory.create_cluster(cluster_name, _deeply_symbolize_keys(cluster_details)))
        clusters.merge( cluster_name => Cluster.new(cluster_name, _deeply_symbolize_keys(cluster_details)))
      end
    end

    def self._deeply_symbolize_keys(value)
      if value.is_a?(Hash)
        value.inject({}) do |symbolized_hash, (hash_key, hash_value)|
          symbolized_hash[hash_key.to_sym] = _deeply_symbolize_keys(hash_value)
          symbolized_hash
        end
      elsif value.is_a?(Array)
        value.map { |item| _deeply_symbolize_keys(item) }
      else
        value
      end
    end

    def self._apply_defaults(defaults_hash, settings_hash)
      return settings_hash unless defaults_hash
      defaults_hash.merge(settings_hash) do |key, oldval, newval|
        oldval.is_a?(Hash) && newval.is_a?(Hash) ? _apply_defaults(oldval, newval) : newval
      end
    end

    def self._valid?(config)
      schema_path = File.join(File.dirname(__FILE__), "../resources", "config_schema.yml")
      schema = YAML.load_file(schema_path)
      validator = Kwalify::Validator.new(schema)
      errors = validator.validate(config)
      valid = !(errors && !errors.empty?)

      unless valid
        errors.each { |err| BigBrother.logger.info("- [#{err.path}] #{err.message}") }
      end

      valid
    end
  end
end
