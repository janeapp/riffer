# frozen_string_literal: true

require "date"

# A month of front-desk ledger entries exported from three different systems,
# so the same kind of entry appears in several formats. Voided entries are
# traps: they must not appear in the output.
module Ledger
  CODES = {
    "PT-INIT" => { description: "Physiotherapy initial assessment", standard_fee: 135.0 },
    "PT-FU" => { description: "Physiotherapy follow-up", standard_fee: 95.0 },
    "RMT-60" => { description: "Registered massage, 60 minutes", standard_fee: 120.0 },
    "RMT-30" => { description: "Registered massage, 30 minutes", standard_fee: 70.0 },
    "CHIRO-FU" => { description: "Chiropractic follow-up", standard_fee: 75.0 },
    "ACU-45" => { description: "Acupuncture, 45 minutes", standard_fee: 95.0 },
    "COUN-50" => { description: "Counselling session, 50 minutes", standard_fee: 140.0 },
  }.freeze

  CODE_DURATIONS = {
    "PT-INIT" => 60, "PT-FU" => 30, "RMT-60" => 60, "RMT-30" => 30, "CHIRO-FU" => 15, "ACU-45" => 45, "COUN-50" => 50,
  }.freeze

  PRODUCTS = {
    "SKU-TB-RED" => ["TheraBand, red (light)", 14.5],
    "SKU-TB-BLU" => ["TheraBand, blue (heavy)", 18.0],
    "SKU-PILLOW" => ["Cervical support pillow", 89.0],
    "SKU-ICE" => ["Reusable cold pack", 12.75],
    "SKU-TAPE" => ["Kinesiology tape roll", 21.99],
    "SKU-ROLLER" => ["Foam roller, 36 inch", 39.95],
  }.freeze

  ADJUSTMENT_REASONS = %w[courtesy_writeoff insurance_shortfall late_cancel_fee_waived refund].freeze

  ADJUSTMENT_WORDING = {
    "courtesy_writeoff" => "courtesy write-off",
    "insurance_shortfall" => "insurance shortfall written off",
    "late_cancel_fee_waived" => "late-cancel fee waived",
    "refund" => "refund issued",
  }.freeze

  NAMES = (Clinic::PATIENTS.map { |p| "#{p[:first_name]} #{p[:last_name]}" } +
           ["Beatrice Oyelaran", "Samuel Whitlock", "Mei-Ling Tran", "Jonas Eriksen"]).freeze

  ENTRY_COUNT = 80
  VOID_COUNT = 5

  module_function

  def generate
    rng = Random.new(20_261_020)
    dates = Array.new(ENTRY_COUNT) { Date.new(2026, 9, 1) + rng.rand(0..29) }.sort
    entries = dates.map { |date| build_entry(date, rng) }
    voids = Array.new(VOID_COUNT) { build_entry(Date.new(2026, 9, 1) + rng.rand(0..29), rng).merge(void: true) }
    rendered = (entries + voids).sort_by { |e| [e[:date], e[:void] ? 1 : 0] }
    [entries.freeze, rendered.freeze]
  end

  def build_entry(date, rng)
    name = NAMES.sample(random: rng)
    roll = rng.rand
    if roll < 0.6
      code = CODES.keys.sample(random: rng)
      practitioner = Clinic::PRACTITIONERS.sample(random: rng)[:name]
      { date: date.iso8601, patient_name: name, kind: "service", billing_code: code, practitioner_name: practitioner,
        duration_minutes: CODE_DURATIONS.fetch(code), amount: CODES.dig(code, :standard_fee), }
    elsif roll < 0.85
      sku = PRODUCTS.keys.sample(random: rng)
      quantity = rng.rand(1..3)
      unit = PRODUCTS.dig(sku, 1)
      { date: date.iso8601, patient_name: name, kind: "product", sku: sku, quantity: quantity, unit_price: unit,
        amount: (unit * quantity).round(2), }
    else
      reason = ADJUSTMENT_REASONS.sample(random: rng)
      { date: date.iso8601, patient_name: name, kind: "adjustment", reason: reason,
        amount: -[15.0, 20.0, 25.0, 35.0, 47.5, 95.0].sample(random: rng), }
    end
  end

  ENTRIES, RENDERED = generate

  def money(value) = format("$%.2f", value.abs)

  def render_entry(entry, index)
    date = Date.parse(entry[:date])
    line = case [entry[:kind], index % 3]
           in ["service", 0]
             "| #{date.iso8601} | #{entry[:patient_name]} | #{entry[:billing_code]} | #{entry[:practitioner_name]} | " \
             "#{entry[:duration_minutes]} min | #{money(entry[:amount])} |"
           in ["service", 1]
             "#{date.strftime('%b %-d')}: #{entry[:patient_name]} saw #{entry[:practitioner_name]} for a " \
             "#{entry[:duration_minutes]}-minute #{CODES.dig(entry[:billing_code], :description).downcase} " \
             "(#{entry[:billing_code]}), billed #{money(entry[:amount])}."
           in ["service", _]
             "SVC;#{date.strftime('%d/%m/%Y')};#{entry[:patient_name].upcase};code=#{entry[:billing_code]};" \
             "prov=#{entry[:practitioner_name]};mins=#{entry[:duration_minutes]};amt=#{format('%.2f',
                                                                                              entry[:amount],)}"
           in ["product", _]
             "POS #{date.strftime('%Y/%m/%d')} #{entry[:patient_name]} — #{entry[:quantity]} x #{entry[:sku]} " \
             "(#{PRODUCTS.dig(entry[:sku],
                              0,)}) @ #{format('%.2f', entry[:unit_price])} = #{format('%.2f', entry[:amount])}"
           in ["adjustment", _]
             "ADJ #{date.strftime('%d-%b-%Y')} #{entry[:patient_name]}: #{ADJUSTMENT_WORDING.fetch(entry[:reason])}, " \
             "credit #{money(entry[:amount])}"
           end
    entry[:void] ? "VOID ✗ #{line}  <-- entered in error, voided by front desk; exclude from reconciliation" : line
  end

  def document
    lines = RENDERED.each_with_index.map { |entry, i| render_entry(entry, i) }
    <<~TEXT
      SEPTEMBER 2026 FRONT-DESK LEDGER — Granville Island Physio & Wellness
      Combined export: scheduling system (pipe rows and prose notes), legacy billing (SVC; rows, dates DD/MM/YYYY),
      point-of-sale terminal (POS rows), and manual adjustments (ADJ rows). Amounts in CAD.
      Billing code reference: #{CODES.map { |code, v| "#{code} = #{v[:description]}" }.join('; ')}.

      #{lines.join("\n")}

      -- end of export (#{RENDERED.size} rows including voids) --
    TEXT
  end

  def totals
    by_kind = ENTRIES.group_by { |e| e[:kind] }.transform_values { |es| es.sum { |e| e[:amount] }.round(2) }
    services = by_kind.fetch("service", 0.0)
    products = by_kind.fetch("product", 0.0)
    adjustments = by_kind.fetch("adjustment", 0.0)
    { services: services, products: products, adjustments: adjustments,
      net: (services + products + adjustments).round(2), }
  end
end
