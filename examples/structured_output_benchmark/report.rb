# frozen_string_literal: true

# Renders a self-contained HTML report from bench.rb's JSONL and
# probe_limits.rb's JSON.
#
#   ruby examples/structured_output_benchmark/report.rb --results results/run.jsonl,results/forced.jsonl \
#     --reliability results/reliability.jsonl --limits results/limits.json --out report.html

require "json"
require "cgi"
require "optparse"

paths = { results: [] }
OptionParser.new do |o|
  o.on("--results LIST", Array) { |v| paths[:results] = v }
  o.on("--reliability PATH") { |v| paths[:reliability] = v }
  o.on("--limits PATH") { |v| paths[:limits] = v }
  o.on("--out PATH") { |v| paths[:out] = v }
end.parse!
abort "usage: report.rb --results A.jsonl,B.jsonl --reliability R.jsonl --limits L.json --out OUT.html" unless paths[:out] && paths[:limits]

def read_jsonl(path) = File.readlines(path).map { |l| JSON.parse(l, symbolize_names: true) }

ALL_RUNS = paths[:results].flat_map { |p| read_jsonl(p) }.freeze
FORCED_SCENARIOS = %w[forced_choice forced_choice_open].freeze
# The forced-choice scenarios measure abstention vs invention and get their own
# section, so the headline numbers stay comparable across the other scenarios.
FORCED = ALL_RUNS.select { |r| FORCED_SCENARIOS.include?(r[:scenario]) }.freeze
RUNS = (ALL_RUNS - FORCED).freeze
RELIABILITY = (paths[:reliability] ? read_jsonl(paths[:reliability]) : []).freeze
LIMITS = JSON.parse(File.read(paths[:limits]), symbolize_names: true).freeze
out_path = paths[:out]

STRATEGIES = %w[prompted native].freeze
STRATEGY_LABEL = { "prompted" => "Riffer prompted", "native" => "Bedrock native" }.freeze
MODEL_LABEL = {
  "us.anthropic.claude-opus-5-5" => "Opus 5.5",
  "us.anthropic.claude-sonnet-5-5" => "Sonnet 5.5",
  "us.anthropic.claude-haiku-5-5" => "Haiku 5.5",
}.freeze
MODELS = MODEL_LABEL.keys.select { |m| RUNS.any? { |r| r[:model] == m } }.freeze
SCENARIO_ORDER = %w[intake_lite intake intake_xl ledger treatment_plan previsit_context previsit_tools
                    noshow_tools chat].freeze
SCENARIOS = SCENARIO_ORDER.select { |s| RUNS.any? { |r| r[:scenario] == s } }.freeze
SCENARIO_LABEL = {
  "intake_lite" => "Intake (native-sized schema)",
  "intake" => "Intake (full schema)",
  "intake_xl" => "Intake (extended schema)",
  "ledger" => "Ledger, 80 rows",
  "treatment_plan" => "Treatment plan, 4 levels",
  "previsit_context" => "Pre-visit, data in prompt",
  "previsit_tools" => "Pre-visit, tools required",
  "noshow_tools" => "No-show report, 8 patients",
  "chat" => "Front-desk chat, 16 turns",
}.freeze
TOOLS_REQUIRED = %w[previsit_tools noshow_tools chat].freeze

def h(text) = CGI.escapeHTML(text.to_s)

def median(values)
  sorted = values.compact.sort
  return nil if sorted.empty?

  mid = sorted.size / 2
  sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
end

def percentile(values, pct)
  sorted = values.compact.sort
  return nil if sorted.empty?

  sorted[((sorted.size - 1) * pct).round]
end

def pct(num, den) = den.zero? ? nil : 100.0 * num / den

def fmt_pct(value)
  if value.nil?
    "–"
  else
    "#{value.round == value ? value.round : value.round(1)}%"
  end
end

def fmt_s(value)
  if value.nil?
    "–"
  else
    "#{value < 10 ? value.round(1) : value.round}s"
  end
end

def select(model: nil, strategy: nil, scenario: nil)
  RUNS.select do |r|
    (model.nil? || r[:model] == model) && (strategy.nil? || r[:strategy] == strategy) && (scenario.nil? || r[:scenario] == scenario)
  end
end

def stats(runs)
  ok = runs.select { |r| r[:status] == "ok" }
  graded = ok.filter_map { |r| r[:grade] }
  checks = graded.sum { |g| g[:total] }
  forbidden = runs.reject { |r| TOOLS_REQUIRED.include?(r[:scenario]) || r[:status] == "api_error" }
  required = runs.select { |r| TOOLS_REQUIRED.include?(r[:scenario]) && r[:status] != "api_error" }
  timed = runs.reject { |r| r[:status] == "api_error" }
  {
    n: runs.size,
    ok: ok.size,
    statuses: runs.map { |r| r[:status] }.tally,
    success: pct(ok.size, runs.size),
    accuracy: pct(graded.sum { |g| g[:correct] }, checks),
    fabricated: graded.sum { |g| g[:fabricated] },
    wrong: graded.sum { |g| g[:wrong] },
    missing: graded.sum { |g| g[:missing] },
    runs_with_fabrication: graded.count { |g| g[:fabricated].positive? },
    graded: graded.size,
    forbidden_runs: forbidden.size,
    unnecessary_tool_use: forbidden.count { |r| r[:unnecessary_tool_use] },
    required_runs: required.size,
    skipped_tools: required.count { |r| r[:skipped_tools] },
    missing_required: required.count { |r| !Array(r[:missing_required_tools]).empty? },
    tool_calls: median(required.map { |r| r[:tool_calls]&.size }),
    ttft: median(timed.map { |r| r[:ttft_s] }),
    ttft_p90: percentile(timed.map { |r| r[:ttft_s] }, 0.9),
    total: median(timed.map { |r| r[:total_s] }),
    total_p90: percentile(timed.map { |r| r[:total_s] }, 0.9),
    output_tokens: median(timed.map { |r| r[:output_tokens] }),
    input_tokens: median(timed.map { |r| r[:input_tokens] }),
    first_request_input: median(timed.map { |r| r[:step_detail]&.first&.dig(:input_tokens) }),
    input_total: timed.sum { |r| r[:input_tokens].to_i },
    output_total: timed.sum { |r| r[:output_tokens].to_i },
    cold_ttft: median(timed.select { |r| r[:rep].zero? }.map { |r| r[:ttft_s] }),
    warm_ttft: median(timed.reject { |r| r[:rep].zero? }.map { |r| r[:ttft_s] }),
    clean_json: pct(ok.count { |r| r[:raw_json_clean] }, ok.size),
  }
end

def problems(runs)
  runs.filter_map { |r| r[:grade] }.flat_map { |g| g[:problems] }.
    group_by { |p| [p[:field].gsub(/\[\d+\]/, "[n]"), p[:outcome]] }.
    map { |(field, outcome), list| { field: field, outcome: outcome, count: list.size, example: list.first } }.
    sort_by { |p| -p[:count] }
end

# ── charts ──────────────────────────────────────────────────────────────────

# rows: [{ label:, values: { "prompted" => Float?, "native" => Float? }, notes: { strategy => String } }]
def bar_chart(rows, max:, unit:, title:, value_fmt:)
  bar = 14
  gap = 2
  group_pad = 14
  label_w = 210
  plot_w = 440
  right = 70
  group_h = (bar * 2) + gap + group_pad
  height = (rows.size * group_h) + 28
  width = label_w + plot_w + right
  scale = ->(v) { (v / max.to_f) * plot_w }
  ticks = nice_ticks(max)

  grid = ticks.map do |t|
    x = label_w + scale.call(t)
    %(<line x1="#{x}" x2="#{x}" y1="0" y2="#{height - 24}" class="grid"/>) +
      %(<text x="#{x}" y="#{height - 8}" class="tick" text-anchor="middle">#{h(value_fmt.call(t))}</text>)
  end.join

  groups = rows.each_with_index.map do |row, i|
    y0 = (i * group_h) + 6
    label = %(<text x="#{label_w - 12}" y="#{y0 + bar + 1}" class="row-label" text-anchor="end" dominant-baseline="middle">#{h(row[:label])}</text>)
    marks = STRATEGIES.each_with_index.map do |strategy, j|
      y = y0 + (j * (bar + gap))
      value = row[:values][strategy]
      note = row.dig(:notes, strategy)
      tip = "#{STRATEGY_LABEL[strategy]} · #{row[:label]}: #{value.nil? ? note || 'no data' : value_fmt.call(value)}#{" (#{note})" if note && value}"
      if value.nil?
        %(<g class="mark" tabindex="0" data-tip="#{h(tip)}"><rect x="#{label_w}" y="#{y}" width="#{plot_w}" height="#{bar}" class="hit"/>) +
          %(<text x="#{label_w + 6}" y="#{y + (bar / 2) + 1}" class="na" dominant-baseline="middle">#{h(note || 'no data')}</text></g>)
      else
        w = [scale.call(value), 1.5].max
        %(<g class="mark" tabindex="0" data-tip="#{h(tip)}"><rect x="#{label_w}" y="#{y - 1}" width="#{plot_w + right}" height="#{bar + 2}" class="hit"/>) +
          %(<path d="#{bar_path(label_w, y, w, bar)}" class="s-#{strategy}"/>) +
          %(<text x="#{label_w + w + 6}" y="#{y + (bar / 2) + 1}" class="value" dominant-baseline="middle">#{h(value_fmt.call(value))}</text></g>)
      end
    end.join
    label + marks
  end.join

  baseline = %(<line x1="#{label_w}" x2="#{label_w}" y1="0" y2="#{height - 24}" class="axis"/>)
  <<~HTML
    <figure class="chart">
      <figcaption>#{h(title)} <span class="unit">#{h(unit)}</span></figcaption>
      <svg viewBox="0 0 #{width} #{height}" width="100%" role="img" aria-label="#{h(title)}">#{grid}#{baseline}#{groups}</svg>
    </figure>
  HTML
end

# Rounded data-end, square at the baseline.
def bar_path(x, y, w, hgt)
  r = [4, w / 2.0, hgt / 2.0].min
  "M#{x},#{y} H#{x + w - r} Q#{x + w},#{y} #{x + w},#{y + r} V#{y + hgt - r} Q#{x + w},#{y + hgt} #{x + w - r},#{y + hgt} H#{x} Z"
end

def nice_ticks(max)
  raw = max / 4.0
  mag = 10**Math.log10(raw).floor
  step = [1, 2, 2.5, 5, 10].map { |m| m * mag }.find { |s| s >= raw }
  (0..(max / step).floor).map { |i| i * step }
end

def legend
  STRATEGIES.map { |s| %(<span class="key"><i class="sw s-#{s}"></i>#{h(STRATEGY_LABEL[s])}</span>) }.join
end

# ── sections ────────────────────────────────────────────────────────────────

overall = STRATEGIES.to_h { |s| [s, stats(select(strategy: s))] }
comparable = SCENARIOS.select { |sc| select(scenario: sc, strategy: "native").any? { |r| r[:status] != "api_error" } }
comparable_stats = STRATEGIES.to_h { |s| [s, stats(RUNS.select { |r| r[:strategy] == s && comparable.include?(r[:scenario]) })] }
rejected_scenarios = SCENARIOS - comparable
reps = RUNS.map { |r| r[:rep] }.max.to_i + 1

# Pooled medians mix very different scenarios, so speed is compared per
# model×scenario cell: native median over prompted median.
def cell_ratios(metric, scenarios)
  MODELS.product(scenarios).filter_map do |m, sc|
    native = stats(select(model: m, scenario: sc, strategy: "native"))[metric]
    prompted = stats(select(model: m, scenario: sc, strategy: "prompted"))[metric]
    native / prompted if native && prompted&.positive?
  end
end

ttft_ratios = cell_ratios(:ttft, comparable)
total_ratios = cell_ratios(:total, comparable)

def tile(label, prompted, native, note = nil)
  <<~HTML
    <div class="tile">
      <div class="tile-label">#{h(label)}</div>
      <div class="tile-row"><i class="sw s-prompted"></i><span class="tile-name">Riffer prompted</span><span class="tile-value">#{h(prompted)}</span></div>
      <div class="tile-row"><i class="sw s-native"></i><span class="tile-name">Bedrock native</span><span class="tile-value">#{h(native)}</span></div>
      #{%(<div class="tile-note">#{h(note)}</div>) if note}
    </div>
  HTML
end

def misuse(st) = st[:unnecessary_tool_use] + st[:skipped_tools] + st[:missing_required]

def speed_tile(label, ratios)
  slower = ratios.count { |r| r > 1 }
  <<~HTML
    <div class="tile">
      <div class="tile-label">#{h(label)}</div>
      <div class="tile-value big">#{h(median(ratios)&.round(2))}×</div>
      <div class="tile-note">Native is slower in #{slower} of #{ratios.size} model × scenario cells (median of native ÷ prompted)</div>
    </div>
  HTML
end

# Rare events need the 100-run cells too, so these two tiles count every run on
# schemas native accepts.
every_run_stats = STRATEGIES.to_h do |s|
  [s, stats((RUNS + RELIABILITY).select { |r| r[:strategy] == s && comparable.include?(r[:scenario]) })]
end

tiles = [
  tile("Runs that returned valid output", fmt_pct(overall.dig("prompted", :success)), fmt_pct(overall.dig("native", :success)),
       "All #{SCENARIOS.size} scenarios, #{MODELS.size} models, #{reps} reps each",),
  tile("Field accuracy where both ran", fmt_pct(comparable_stats.dig("prompted", :accuracy)), fmt_pct(comparable_stats.dig("native", :accuracy)),
       "The #{comparable.size} scenarios native accepts",),
  tile("Hallucinated values where both ran", every_run_stats["prompted"][:fabricated].to_s, every_run_stats["native"][:fabricated].to_s,
       "Invented values, trap items, fake IDs, over all #{every_run_stats['native'][:n]} runs per strategy incl. the 100-run cells",),
  tile("Tool misuse", misuse(every_run_stats["prompted"]).to_s, misuse(every_run_stats["native"]).to_s,
       "Runs with a needless call, a skipped call or a missing required tool, over the same runs",),
  speed_tile("Bedrock native total run time vs prompted", total_ratios),
  speed_tile("Bedrock native time to first token vs prompted", ttft_ratios),
].join

success_rows = SCENARIOS.map do |sc|
  values = STRATEGIES.to_h { |s| [s, stats(select(scenario: sc, strategy: s))[:success]] }
  notes = STRATEGIES.to_h do |s|
    st = stats(select(scenario: sc, strategy: s))
    failures = st[:statuses].except("ok")
    [s, failures.empty? ? nil : failures.map { |k, v| "#{v} #{k.tr('_', ' ')}" }.join(", ")]
  end
  { label: SCENARIO_LABEL.fetch(sc, sc), values: values, notes: notes }
end
success_chart = bar_chart(success_rows, max: 100, unit: "% of runs, all models", title: "Runs that returned schema-valid output",
                                        value_fmt: ->(v) { fmt_pct(v) },)

accuracy_rows = comparable.map do |sc|
  values = STRATEGIES.to_h { |s| [s, stats(select(scenario: sc, strategy: s))[:accuracy]] }
  notes = STRATEGIES.to_h do |s|
    st = stats(select(scenario: sc, strategy: s))
    [s, "#{st[:fabricated]} hallucinated, #{st[:wrong]} wrong, #{st[:missing]} missing over #{st[:graded]} runs"]
  end
  { label: SCENARIO_LABEL.fetch(sc, sc), values: values, notes: notes }
end
min_accuracy = accuracy_rows.flat_map { |r| r[:values].values.compact }.min || 0
accuracy_chart = bar_chart(accuracy_rows, max: 100, unit: "% of graded fields correct, valid runs only",
                                          title: "Field accuracy against ground truth", value_fmt: lambda { |v|
                                            fmt_pct(v)
                                          },)

def perf_charts(metric, title, scenarios)
  max = MODELS.flat_map do |m|
    scenarios.flat_map do |sc|
      STRATEGIES.map do |s|
        stats(select(model: m, scenario: sc, strategy: s))[metric]
      end
    end
  end.compact.max || 1
  MODELS.map do |m|
    rows = scenarios.map do |sc|
      values = STRATEGIES.to_h { |s| [s, stats(select(model: m, scenario: sc, strategy: s))[metric]] }
      notes = STRATEGIES.to_h { |s| [s, values[s].nil? ? "schema rejected" : nil] }
      { label: SCENARIO_LABEL.fetch(sc, sc), values: values, notes: notes }
    end
    bar_chart(rows, max: max * 1.05, unit: "median seconds", title: "#{MODEL_LABEL[m]} — #{title}", value_fmt: lambda { |v|
      fmt_s(v)
    },)
  end.join
end

ttft_charts = perf_charts(:ttft, "time to first token", comparable)
total_charts = perf_charts(:total, "total run time", comparable)

tool_table_rows = MODELS.flat_map do |m|
  STRATEGIES.map do |s|
    st = stats(select(model: m, strategy: s))
    calls = TOOLS_REQUIRED.map do |sc|
      stats(select(model: m, strategy: s, scenario: sc))[:tool_calls]&.round || "–"
    end.join(" / ")
    <<~HTML
      <tr><td>#{h(MODEL_LABEL[m])}</td><td><i class="sw s-#{s}"></i>#{h(STRATEGY_LABEL[s])}</td>
      <td class="num">#{st[:unnecessary_tool_use]} / #{st[:forbidden_runs]}</td>
      <td class="num">#{st[:skipped_tools]} / #{st[:required_runs]}</td>
      <td class="num">#{st[:missing_required]} / #{st[:required_runs]}</td>
      <td class="num">#{calls}</td>
      <td class="num">#{fmt_pct(st[:clean_json])}</td></tr>
    HTML
  end
end.join

detail_rows = SCENARIOS.flat_map do |sc|
  MODELS.flat_map do |m|
    STRATEGIES.map do |s|
      st = stats(select(model: m, scenario: sc, strategy: s))
      failures = st[:statuses].except("ok").map { |k, v| "#{v} #{k.tr('_', ' ')}" }.join(", ")
      <<~HTML
        <tr><td>#{h(SCENARIO_LABEL.fetch(sc, sc))}</td><td>#{h(MODEL_LABEL[m])}</td><td><i class="sw s-#{s}"></i>#{h(STRATEGY_LABEL[s])}</td>
        <td class="num">#{st[:ok]}/#{st[:n]}</td><td>#{h(failures)}</td>
        <td class="num">#{fmt_pct(st[:accuracy])}</td><td class="num">#{st[:fabricated]}</td><td class="num">#{st[:wrong]}</td><td class="num">#{st[:missing]}</td>
        <td class="num">#{fmt_s(st[:ttft])}</td><td class="num">#{fmt_s(st[:ttft_p90])}</td><td class="num">#{fmt_s(st[:total])}</td><td class="num">#{fmt_s(st[:total_p90])}</td>
        <td class="num">#{st[:output_tokens]&.round || '–'}</td></tr>
      HTML
    end
  end
end.join

cold_rows = MODELS.map do |m|
  native = stats(RUNS.select { |r| r[:model] == m && r[:strategy] == "native" && comparable.include?(r[:scenario]) })
  prompted = stats(RUNS.select do |r|
    r[:model] == m && r[:strategy] == "prompted" && comparable.include?(r[:scenario])
  end)
  "<tr><td>#{h(MODEL_LABEL[m])}</td><td class=\"num\">#{fmt_s(native[:cold_ttft])}</td><td class=\"num\">#{fmt_s(native[:warm_ttft])}</td>" \
    "<td class=\"num\">#{fmt_s(prompted[:cold_ttft])}</td><td class=\"num\">#{fmt_s(prompted[:warm_ttft])}</td></tr>"
end.join

def fmt_tokens(value)
  return "–" if value.nil?

  value >= 1000 ? "#{(value / 1000.0).round(1)}K" : value.round.to_s
end

def fmt_delta(native, prompted)
  return "–" unless native && prompted&.positive?

  delta = 100.0 * (native - prompted) / prompted
  "#{'+' if delta.positive?}#{delta.round(1)}%"
end

def token_chart(metric, title, scenarios)
  rows = scenarios.map do |sc|
    values = STRATEGIES.to_h { |s| [s, stats(select(scenario: sc, strategy: s))[metric]] }
    notes = { "native" => "#{fmt_delta(values['native'], values['prompted'])} vs prompted" }
    { label: SCENARIO_LABEL.fetch(sc, sc), values: values, notes: notes }
  end
  max = rows.flat_map { |r| r[:values].values.compact }.max || 1
  bar_chart(rows, max: max * 1.05, unit: "median tokens per run, all models", title: title, value_fmt: ->(v) { fmt_tokens(v) })
end

input_token_chart = token_chart(:input_tokens, "Input tokens per run", comparable)
output_token_chart = token_chart(:output_tokens, "Output tokens per run (includes unseen thinking)", comparable)

# Single-turn and multi-turn runs are reported apart: prompted repeats the
# schema on every user message, so a pooled total would depend on the mix.
single_turn = comparable - ["chat"]
def token_stats(scenarios, strategy) = stats(RUNS.select { |r| r[:strategy] == strategy && scenarios.include?(r[:scenario]) })

token_tiles = [
  [single_turn, :input_total, "Input tokens, single-turn scenarios"],
  [single_turn, :output_total, "Output tokens, single-turn scenarios"],
  [["chat"], :input_tokens, "Input tokens per run, 16-turn chat"],
].filter_map do |scenarios, metric, label|
  next unless scenarios.intersect?(comparable)

  prompted = token_stats(scenarios, "prompted")
  native = token_stats(scenarios, "native")
  note = metric == :input_tokens ? "Median per run" : "#{native[:n]} runs each"
  tile(label, fmt_tokens(prompted[metric]), fmt_tokens(native[metric]), "#{note} · native #{fmt_delta(native[metric], prompted[metric])}")
end.join

token_rows = comparable.flat_map do |sc|
  MODELS.map do |m|
    p = stats(select(model: m, scenario: sc, strategy: "prompted"))
    n = stats(select(model: m, scenario: sc, strategy: "native"))
    "<tr><td>#{h(SCENARIO_LABEL.fetch(sc, sc))}</td><td>#{h(MODEL_LABEL[m])}</td>" \
      "<td class=\"num\">#{(n[:first_request_input] - p[:first_request_input]).round}</td>" \
      "<td class=\"num\">#{fmt_tokens(p[:input_tokens])}</td><td class=\"num\">#{fmt_tokens(n[:input_tokens])}</td>" \
      "<td class=\"num\">#{fmt_delta(n[:input_tokens], p[:input_tokens])}</td>" \
      "<td class=\"num\">#{fmt_tokens(p[:output_tokens])}</td><td class=\"num\">#{fmt_tokens(n[:output_tokens])}</td>" \
      "<td class=\"num\">#{fmt_delta(n[:output_tokens], p[:output_tokens])}</td></tr>"
  end
end.join

limit_schemas = LIMITS.map { |l| l[:schema] }.uniq
limit_rows = limit_schemas.map do |schema|
  entries = LIMITS.select { |l| l[:schema] == schema }
  accepted = entries.all? { |l| l[:accepted] }
  rejected = entries.none? { |l| l[:accepted] }
  verdict = if accepted
              %(<span class="ok">✓ Accepted</span>)
            elsif rejected
              %(<span class="bad">✕ Rejected</span>)
            else
              "Mixed"
            end
  reason = entries.find { |l| l[:error] }&.dig(:error).to_s
  reason = if reason.include?("union") then "Too many nullable/union fields (limit 16)"
           elsif reason.include?("grammar is too large") then "Compiled grammar too large"
           else reason
           end
  "<tr><td>#{h(schema)}</td><td class=\"num\">#{entries.first[:unions]}</td><td>#{verdict}</td><td>#{h(reason)}</td></tr>"
end.join

problem_rows = comparable.flat_map do |sc|
  STRATEGIES.flat_map do |s|
    problems(select(scenario: sc, strategy: s)).first(6).map do |p|
      ex = p[:example]
      "<tr><td>#{h(SCENARIO_LABEL.fetch(sc,
                                        sc,))}</td><td><i class=\"sw s-#{s}\"></i>#{h(STRATEGY_LABEL[s])}</td><td><code>#{h(p[:field])}</code></td>" \
        "<td>#{h(p[:outcome])}</td><td class=\"num\">#{p[:count]}</td><td>expected <code>#{h(ex[:expected].inspect)}</code>, got <code>#{h(ex[:actual].inspect)}</code></td></tr>"
    end
  end
end.join

def forced_grade(run) = run[:grade] || run[:grade_unvalidated]

PLACEHOLDER = %r{unknown|not[ _-]?provided|null|placeholder|lookup|invalid|n/a|not available|pending}i

# A placeholder string is invented but at least flags itself; a plausible value
# (an enum choice, a boolean, a count) is indistinguishable from real data.
def placeholder?(value) = value.is_a?(String) && PLACEHOLDER.match?(value)

def truncate(text, max = 70) = text.size > max ? "#{text[0, max]}…" : text

def forced_stats(runs)
  graded = runs.filter_map { |r| forced_grade(r) }
  invented = graded.flat_map { |g| g[:problems] }.select { |p| p[:outcome].to_s == "fabricated" }
  slots = graded.size * 6
  {
    n: runs.size, valid: runs.count { |r| r[:status] == "ok" }, statuses: runs.map { |r| r[:status] }.tally,
    fabricated: invented.size, slots: slots, abstained: slots - invented.size,
    plausible: invented.count { |p| !placeholder?(p[:actual]) },
    placeholders: invented.count { |p| placeholder?(p[:actual]) },
    values: invented.map { |p| [p[:field].sub(" (not in letter)", ""), p[:actual]] },
    delivered: runs.select { |r| r[:status] == "ok" }.sum { |r| r[:grade][:fabricated] },
  }
end

FORCED_VARIANT = { "forced_choice" => "All required", "forced_choice_open" => "Unknown allowed" }.freeze

def forced_runs(variant, model: nil, strategy: nil)
  FORCED.select do |r|
    r[:scenario] == variant && (model.nil? || r[:model] == model) && (strategy.nil? || r[:strategy] == strategy)
  end
end

forced_rows = FORCED_VARIANT.flat_map do |variant, variant_label|
  MODELS.flat_map do |m|
    STRATEGIES.map do |s|
      st = forced_stats(forced_runs(variant, model: m, strategy: s))
      failures = st[:statuses].except("ok").map { |k, v| "#{v} #{k.tr('_', ' ')}" }.join(", ")
      "<tr><td>#{h(variant_label)}</td><td>#{h(MODEL_LABEL[m])}</td><td><i class=\"sw s-#{s}\"></i>#{h(STRATEGY_LABEL[s])}</td>" \
        "<td class=\"num\">#{st[:valid]}/#{st[:n]}</td><td>#{h(failures)}</td>" \
        "<td class=\"num\">#{st[:abstained]}</td><td class=\"num\">#{st[:plausible]}</td><td class=\"num\">#{st[:placeholders]}</td>" \
        "<td class=\"num\">#{st[:slots]}</td></tr>"
    end
  end
end.join

forced_value_rows = FORCED_VARIANT.flat_map do |variant, variant_label|
  STRATEGIES.map do |s|
    values = forced_stats(forced_runs(variant, strategy: s))[:values]
    summary = values.group_by(&:first).map do |field, list|
      "<code>#{h(field)}</code>: #{list.map(&:last).tally.sort_by { |_, c| -c }.map { |v, c| "#{h(truncate(v.inspect))} ×#{c}" }.join(', ')}"
    end
    "<tr><td>#{h(variant_label)}</td><td><i class=\"sw s-#{s}\"></i>#{h(STRATEGY_LABEL[s])}</td>" \
      "<td>#{summary.empty? ? 'None' : summary.join('<br>')}</td></tr>"
  end
end.join

forced_chart_rows = FORCED_VARIANT.flat_map do |variant, variant_label|
  MODELS.map do |m|
    values = STRATEGIES.to_h do |s|
      st = forced_stats(forced_runs(variant, model: m, strategy: s))
      [s, st[:n].zero? ? nil : 100.0 * st[:delivered] / (st[:n] * 6)]
    end
    { label: "#{MODEL_LABEL[m]} · #{variant_label.downcase}", values: values, notes: {} }
  end
end
forced_chart = if FORCED.empty?
                 ""
               else
                 bar_chart(forced_chart_rows, max: 100, unit: "% of unanswerable fields, across all runs",
                                              title: "Invented values that reached the application", value_fmt: ->(v) { fmt_pct(v) },)
               end

# Reliability at volume: many repeats of a few scenarios, to bound rare failures.

# Upper end of the Wilson 95% interval; with zero failures it is close to the
# rule of three (3/n).
def failure_upper_bound(failures, n)
  return nil if n.zero?

  z = 1.96
  p = failures.to_f / n
  centre = p + ((z**2) / (2 * n))
  margin = z * Math.sqrt((p * (1 - p) / n) + ((z**2) / (4 * (n**2))))
  100.0 * (centre + margin) / (1 + ((z**2) / n))
end

RELIABILITY_SCENARIOS = SCENARIO_ORDER.select { |sc| RELIABILITY.any? { |r| r[:scenario] == sc } }.freeze

def reliability_stats(runs)
  ok = runs.select { |r| r[:status] == "ok" }
  failures = runs.size - ok.size
  graded = ok.filter_map { |r| r[:grade] }
  {
    n: runs.size, failures: failures, statuses: runs.map { |r| r[:status] }.tally.except("ok"),
    upper: failure_upper_bound(failures, runs.size),
    recovered: ok.count { |r| !r[:raw_json_clean] },
    accuracy: pct(graded.sum { |g| g[:correct] }, graded.sum { |g| g[:total] }),
    fabricated: graded.sum { |g| g[:fabricated] },
    needless: runs.count { |r| r[:unnecessary_tool_use] },
    missed: runs.count { |r| r[:skipped_tools] || !Array(r[:missing_required_tools]).empty? },
    ttft: median(runs.map { |r| r[:ttft_s] }), total: median(runs.map { |r| r[:total_s] }),
    total_p90: percentile(runs.map { |r| r[:total_s] }, 0.9),
  }
end

def fmt_upper(value) = value.nil? ? "–" : "≤ #{value.round(1)}%"

reliability_totals = STRATEGIES.to_h { |s| [s, reliability_stats(RELIABILITY.select { |r| r[:strategy] == s })] }

reliability_tiles = if RELIABILITY.empty?
                      ""
                    else
                      [
                        tile("Runs that failed", "#{reliability_totals.dig('prompted', :failures)} of #{reliability_totals.dig('prompted', :n)}",
                             "#{reliability_totals.dig('native', :failures)} of #{reliability_totals.dig('native', :n)}",
                             "Any failure: API error, invalid JSON, schema violation, truncation, step limit",),
                        tile("Failure rate, 95% upper bound", fmt_upper(reliability_totals.dig("prompted", :upper)),
                             fmt_upper(reliability_totals.dig("native", :upper)), "The true rate is very likely below this",),
                        tile("Replies needing riffer's recovery parser", reliability_totals.dig("prompted", :recovered).to_s,
                             reliability_totals.dig("native", :recovered).to_s, "JSON wrapped in a code fence or prose, then recovered",),
                        tile("Hallucinated values", reliability_totals.dig("prompted", :fabricated).to_s,
                             reliability_totals.dig("native", :fabricated).to_s, "Across every graded field",),
                      ].join
                    end

reliability_rows = RELIABILITY_SCENARIOS.flat_map do |sc|
  MODELS.flat_map do |m|
    STRATEGIES.map do |s|
      st = reliability_stats(RELIABILITY.select { |r| r[:scenario] == sc && r[:model] == m && r[:strategy] == s })
      failed = "#{st[:failures]} / #{st[:n]}"
      "<tr><td>#{h(SCENARIO_LABEL.fetch(sc, sc))}</td><td>#{h(MODEL_LABEL[m])}</td><td><i class=\"sw s-#{s}\"></i>#{h(STRATEGY_LABEL[s])}</td>" \
        "<td class=\"num\">#{h(failed)}</td><td class=\"num\">#{st[:recovered]}</td><td class=\"num\">#{fmt_pct(st[:accuracy])}</td>" \
        "<td class=\"num\">#{st[:fabricated]}</td><td class=\"num\">#{st[:needless] + st[:missed]}</td>" \
        "<td class=\"num\">#{fmt_s(st[:total])}</td></tr>"
    end
  end
end.join

reliability_runs = RELIABILITY.map { |r| r[:rep] }.max.to_i + 1

template = File.read(File.expand_path("report_template.html", __dir__)).
  sub("{{body}}") { File.read(File.expand_path("report_body.html", __dir__)) }
html = template.gsub(/\{\{(\w+)\}\}/) do
  {
    "generated" => h(RUNS.map { |r| r[:finished_at] }.max.to_s[0, 10]),
    "runs" => RUNS.size.to_s,
    "reps" => reps.to_s,
    "models" => h(MODELS.map { |m| MODEL_LABEL[m] }.join(", ")),
    "legend" => legend,
    "tiles" => tiles,
    "success_chart" => success_chart,
    "accuracy_chart" => accuracy_chart,
    "ttft_charts" => ttft_charts,
    "total_charts" => total_charts,
    "tool_table_rows" => tool_table_rows,
    "detail_rows" => detail_rows,
    "cold_rows" => cold_rows,
    "input_token_chart" => input_token_chart,
    "output_token_chart" => output_token_chart,
    "token_tiles" => token_tiles,
    "token_rows" => token_rows,
    "limit_rows" => limit_rows,
    "problem_rows" => problem_rows,
    "rejected" => h(rejected_scenarios.map { |s| SCENARIO_LABEL.fetch(s, s) }.join(" and ")),
    "min_accuracy" => fmt_pct(min_accuracy),
    "forced_rows" => forced_rows,
    "forced_value_rows" => forced_value_rows,
    "forced_chart" => forced_chart,
    "reliability_tiles" => reliability_tiles,
    "reliability_rows" => reliability_rows,
    "reliability_reps" => reliability_runs.to_s,
    "reliability_total" => RELIABILITY.size.to_s,
    "forced_runs" => FORCED.size.to_s,
  }.fetch(Regexp.last_match(1))
end
File.write(out_path, html)
warn "wrote #{out_path}"
