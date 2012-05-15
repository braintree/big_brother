module BigBrother
  class Logger
    def write(message)
      EM.info message
    end
  end
end
