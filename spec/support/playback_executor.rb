class PlaybackExecutor
  def initialize
    @responses = []
  end

  def invoke(command)
    @responses.pop
  end

  def add_response(output, status)
    @responses.push [output, status]
  end
end
