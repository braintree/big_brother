class RecordingExecutor
  attr_reader :commands

  def initialize
    @commands = []
  end

  def invoke(command)
    @commands << command
    ["", 0]
  end
end
