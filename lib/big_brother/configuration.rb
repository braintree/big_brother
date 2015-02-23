module BigBrother
  class Configuration
    GLOBAL_CONFIG_KEY = '_big_brother'

    def self.from_file(config_file)
      config = YAML.load_file(config_file)
      defaults = config.delete(GLOBAL_CONFIG_KEY)

      config.inject({}) do |clusters, (cluster_name, cluster_values)|
        cluster_details = _apply_defaults(defaults, cluster_values)
        clusters.merge(cluster_name => Cluster.create_cluster(cluster_name, _deeply_symbolize_keys(cluster_details)))
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
  end
end
