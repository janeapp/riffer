# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Wire::SSE
  # @rbs @buffer: String
  # @rbs @data: Array[String]
  # @rbs @event: String?

  #--
  #: () -> void
  def initialize
    @buffer = +""
    @data = []
    @event = nil
  end

  # An event is dispatched only once its terminating blank line arrives, so a
  # trailing partial event stays buffered.
  #--
  #: (String) { (String, String?) -> void } -> void
  def feed(chunk, &)
    @buffer << chunk

    while (match = @buffer.match(/\r\n|\r|\n/))
      line_end = match.end(0) #: Integer
      # A trailing CR may be the first half of a CRLF split across chunks.
      break if match[0] == "\r" && line_end == @buffer.length

      line = @buffer.slice!(0, line_end).to_s.chomp
      process_line(line, &)
    end
  end

  private

  #--
  #: (String) { (String, String?) -> void } -> void
  def process_line(line)
    if line.empty?
      yield(@data.join("\n"), @event) unless @data.empty?
      @data = []
      @event = nil
      return
    end
    return if line.start_with?(":")

    field, value = line.split(":", 2)
    value = value.to_s.delete_prefix(" ")

    case field
    when "data" then @data << value
    when "event" then @event = value
    end
  end
end
