module BigBrother
  class Logger
    module Level
      DEBUG = 0
      INFO = 1
    end

    attr_accessor :level

    def initialize
      @level = Level::INFO
    end

    def write(message)
      info(message)
    end

    def info(message)
      EM.info(message)
    end

    def debug(message)
      EM.debug(message) if level == Level::DEBUG
    end
  end
end
