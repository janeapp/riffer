# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Delegates guardrail execution to a callback for RPC use.
#
# Mirrors Riffer::Guardrails::Runner but instead of instantiating
# guardrail classes, it calls back to the client for each guardrail.
#
#   runner = RpcRunner.new(
#     guardrail_definitions,
#     phase: :before,
#     callback: ->(name, phase, data, options_json) { { action: :pass } }
#   )
#   data, tripwire, modifications = runner.run(messages)
class Riffer::Guardrails::RpcRunner
  # Creates a new RPC guardrail runner.
  #
  # +guardrail_definitions+ - array of hashes with :name, :phase, :options_json keys.
  # +phase+ - :before or :after.
  # +context+ - optional context (unused by runner, forwarded for symmetry).
  # +callback+ - callable receiving (name, phase, data, options_json) and returning a result hash.
  #
  #: (Array[Hash[Symbol, untyped]], phase: Symbol, callback: ^(String, Symbol, untyped, String?) -> Hash[Symbol, untyped], ?context: untyped) -> void
  def initialize(guardrail_definitions, phase:, callback:, context: nil)
    @guardrail_definitions = guardrail_definitions
    @phase = phase
    @context = context
    @callback = callback
  end

  # Runs guardrails sequentially via the callback.
  #
  # Returns the same triple as Riffer::Guardrails::Runner#run:
  # [data, Tripwire?, Array[Modification]]
  #
  #: (untyped, ?messages: Array[Riffer::Messages::Base]?) -> [untyped, Riffer::Guardrails::Tripwire?, Array[Riffer::Guardrails::Modification]]
  def run(data, messages: nil)
    current_data = data
    modifications = [] #: Array[Riffer::Guardrails::Modification]

    @guardrail_definitions.each do |defn|
      next unless matches_phase?(defn)

      result = @callback.call(defn[:name], @phase, current_data, defn[:options_json])

      case result[:action]
      when :block
        tripwire = Riffer::Guardrails::Tripwire.new(
          reason: result[:block_reason],
          guardrail: defn[:name],
          phase: @phase,
          metadata: parse_metadata(result[:metadata_json])
        )
        return [current_data, tripwire, modifications]
      when :transform
        modifications << Riffer::Guardrails::Modification.new(
          guardrail: defn[:name],
          phase: @phase,
          message_indices: result[:modified_message_indices] || []
        )
        current_data = result[:messages] || current_data
      end
    end

    [current_data, nil, modifications]
  end

  private

  #: (Hash[Symbol, untyped]) -> bool
  def matches_phase?(defn)
    defn[:phase].nil? || defn[:phase] == @phase
  end

  #: (String?) -> Hash[Symbol, untyped]?
  def parse_metadata(metadata_json)
    return nil if metadata_json.nil? || metadata_json.empty?
    JSON.parse(metadata_json, symbolize_names: true)
  end
end
