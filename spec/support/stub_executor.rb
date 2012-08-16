class StubExecutor
  attr_reader :commands

  def initialize
    @responses = {}
    @commands = []
  end

  def invoke(command)
    @commands << command
    @responses.fetch(command, [["", 0]]).pop
  end

  def add_response(command, output, status)
    @responses[command] ||= []
    @responses[command].push [output, status]
  end

  def clear_commands!
    @commands = []
  end
end
