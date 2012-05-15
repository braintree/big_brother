module BigBrother
  class Logger
    def write(message)
      info(message)
    end

    def info(message)
      EM.info(message)
    end
  end
end
