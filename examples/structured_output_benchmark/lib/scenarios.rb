# frozen_string_literal: true

require "json"

module Scenarios
  # tools: :forbidden — every fact is in the prompt, so any tool call is unnecessary.
  #        :required  — the facts only exist behind the tools listed in required_tools.
  Scenario = Data.define(:key, :title, :summary, :tools, :required_tools, :schema, :prompt, :grader)

  SYSTEM = <<~TEXT.freeze
    You are the back-office assistant for Granville Island Physio & Wellness. Today's date is #{Clinic::TODAY.iso8601}.
    You can read the clinic's systems through tools. Use a tool only when the information you need is not already in the conversation.
    Never guess or invent information. If a value is not available, leave the optional field null.
  TEXT

  PROVINCES = %w[BC AB SK MB ON QC NB NS PE NL YT NT NU].freeze
  BODY_REGIONS = %w[head neck shoulder upper_back lower_back elbow wrist_hand hip knee ankle_foot other].freeze

  module_function

  def params(&block)
    Riffer::Params.new.tap { |p| p.instance_eval(&block) }
  end

  def g = Grading

  # ── intake ────────────────────────────────────────────────────────────────

  INTAKE_FIELDS = proc do
    required :patient, Hash do
      required :first_name, String
      required :last_name, String
      optional :preferred_name, String, description: "Only if the patient gave one"
      required :date_of_birth, String, format: "date"
      optional :email, String, format: "email"
      required :phone, String, description: "Patient's own primary phone"
      optional :secondary_phone, String
      required :address, Hash, description: "Current home address" do
        required :street, String, description: "Including unit, e.g. 4-123 Main St"
        required :city, String
        required :province, String, enum: PROVINCES
        required :postal_code, String
      end
      optional :occupation, String
      optional :employer, String
    end
    optional :emergency_contact, Hash do
      required :name, String
      required :relationship, String, enum: %w[spouse partner parent child sibling friend other]
      required :phone, String
    end
    optional :family_physician, Hash do
      required :name, String
      required :clinic, String
    end
    optional :insurance, Hash do
      required :insurer, String
      required :policy_number, String
      required :member_id, String
    end
    required :referral, Hash do
      required :referred_by, String
      required :reason, String
      optional :referral_date, String, format: "date"
      optional :urgency, String, enum: %w[routine urgent emergent], description: "Only if the referral states it"
    end
    required :presenting_complaints, Array do
      required :body_region, String, enum: BODY_REGIONS
      required :side, String, enum: %w[left right bilateral midline]
      required :pain_now, Integer, description: "0-10"
      required :pain_worst, Integer, description: "0-10"
      required :onset, String, format: "date"
      required :aggravating_factors, Array, of: String
    end
    required :medications, Array, description: "Medications the patient currently takes" do
      required :name, String, description: "Drug name only, e.g. Metformin"
      required :dose, String
      required :frequency, String, enum: %w[once_daily twice_daily three_times_daily as_needed weekly]
      optional :prescriber, String
    end
    required :allergies, Array, description: "The patient's own allergies" do
      required :name, String
      required :reaction, String
      required :severity, String, enum: %w[mild moderate severe]
    end
    required :conditions, Array, of: String, description: "The patient's current diagnosed conditions"
    required :surgeries, Array do
      required :procedure, String
      required :year, Integer
    end
    required :red_flags, Hash, description: "Screening answers about the patient" do
      required :unexplained_weight_loss, Riffer::Params::Boolean
      required :night_pain, Riffer::Params::Boolean
      required :bowel_bladder_changes, Riffer::Params::Boolean
      required :fever, Riffer::Params::Boolean
      required :history_of_cancer, Riffer::Params::Boolean
    end
    required :consents, Hash do
      required :treatment, Riffer::Params::Boolean
      required :email_reminders, Riffer::Params::Boolean
      required :sms_reminders, Riffer::Params::Boolean
      required :research, Riffer::Params::Boolean
    end
    optional :goals, Array, of: String
    optional :notes_for_practitioner, String
  end

  INTAKE_XL_FIELDS = proc do
    instance_eval(&INTAKE_FIELDS)
    optional :pronouns, String
    optional :height_cm, Integer
    optional :weight_kg, Float
    optional :smoking_status, String, enum: %w[never former current]
    optional :alcohol_drinks_per_week, Integer
    optional :dominant_hand, String, enum: %w[left right ambidextrous]
    optional :blood_type, String
    optional :marital_status, String, enum: %w[single married common_law divorced widowed]
    optional :number_of_children, Integer
    optional :work_status, String, enum: %w[full_time part_time off_work retired student]
    optional :workers_comp_claim, Riffer::Params::Boolean
    optional :motor_vehicle_accident, Riffer::Params::Boolean
    optional :previous_physiotherapy, Riffer::Params::Boolean
    optional :previous_imaging, String
    optional :preferred_contact_method, String, enum: %w[email phone sms]
    optional :preferred_language, String
    optional :interpreter_required, Riffer::Params::Boolean
    optional :pharmacy, String
    optional :personal_health_number, String
    optional :gender_identity, String
    optional :sleep_hours_per_night, Integer
    optional :stress_level, Integer, description: "0-10, only if stated"
    optional :referral_source, String, description: "How the patient heard about the clinic"
    optional :accessibility_needs, String
    optional :legal_guardian, String
  end

  def grade_intake(out)
    t = Intake::TRUTH
    pat = out[:patient] || {}
    addr = pat[:address] || {}
    meds = out[:medications] || []
    allergies = out[:allergies] || []
    complaints = out[:presenting_complaints] || []
    conditions = out[:conditions] || []

    checks = [
      g.check("patient.first_name", t.dig(:patient, :first_name), pat[:first_name], :text),
      g.check("patient.last_name", t.dig(:patient, :last_name), pat[:last_name], :text),
      g.check("patient.preferred_name", nil, pat[:preferred_name]),
      g.check("patient.date_of_birth", t.dig(:patient, :date_of_birth), pat[:date_of_birth]),
      g.check("patient.email", t.dig(:patient, :email), pat[:email], :text),
      g.check("patient.phone", t.dig(:patient, :phone), pat[:phone], :phone),
      g.check("patient.secondary_phone", nil, pat[:secondary_phone]),
      g.check("patient.address.street", "2211 Commercial", addr[:street], :loose),
      g.check("patient.address.city", "Vancouver", addr[:city], :text),
      g.check("patient.address.province", "BC", addr[:province]),
      g.check("patient.address.postal_code", "V5N 4B4", addr[:postal_code], :text),
      g.check("patient.occupation", "teacher", pat[:occupation], :loose),
      g.check("patient.employer", nil, pat[:employer]),
      g.check("emergency_contact.name", "Erik Lindqvist", out.dig(:emergency_contact, :name), :text),
      g.check("emergency_contact.relationship", "spouse", out.dig(:emergency_contact, :relationship)),
      g.check("emergency_contact.phone", "604-555-0169", out.dig(:emergency_contact, :phone), :phone),
      g.check("family_physician.name", "Helen Mbeki", out.dig(:family_physician, :name), :loose),
      g.check("family_physician.clinic", "Grandview Family Practice", out.dig(:family_physician, :clinic), :loose),
      g.check("insurance.insurer", "Pacific Blue Cross", out.dig(:insurance, :insurer), :text),
      g.check("insurance.policy_number", "PBC-603318", out.dig(:insurance, :policy_number), :text),
      g.check("insurance.member_id", "NL-77810", out.dig(:insurance, :member_id), :text),
      g.check("referral.referred_by", "Helen Mbeki", out.dig(:referral, :referred_by), :loose),
      g.check("referral.referral_date", "2026-10-06", out.dig(:referral, :referral_date)),
      g.check("referral.urgency", nil, out.dig(:referral, :urgency)),
      g.check("presenting_complaints.count", 3, complaints.size),
    ]

    pairs, extra = g.pair(t[:presenting_complaints], complaints) { |e, a| a[:body_region] == e[:body_region] }
    pairs.each do |e, a|
      prefix = "presenting_complaints[#{e[:body_region]}]"
      next checks << g.check(prefix, e[:body_region], nil) unless a

      checks << g.check("#{prefix}.side", e[:side], a[:side])
      checks << g.check("#{prefix}.pain_now", e[:pain_now], a[:pain_now])
      checks << g.check("#{prefix}.pain_worst", e[:pain_worst], a[:pain_worst])
      checks << g.check("#{prefix}.onset", e[:onset], a[:onset])
    end
    extra.each { |a| checks << g.invented("presenting_complaints[extra]", a[:body_region]) }

    pairs, extra = g.pair(t[:medications], meds) { |e, a| g.norm(a[:name]).include?(g.norm(e[:name])) }
    pairs.each do |e, a|
      prefix = "medications[#{e[:name]}]"
      next checks << g.check(prefix, e[:name], nil) unless a

      checks << g.check("#{prefix}.frequency", e[:frequency], a[:frequency])
      checks << g.check("#{prefix}.prescriber", e[:prescriber] && "Mbeki", a[:prescriber], :loose)
    end
    extra.each { |a| checks << g.invented("medications[extra]", a[:name]) }
    t[:trap_medications].each do |trap|
      checks << g.exclusion("medications excludes #{trap}", trap, meds.map { |m|
        m[:name]
      },)
    end

    pairs, extra = g.pair(t[:allergies], allergies) { |e, a| g.norm(a[:name]).include?(g.norm(e[:name])) }
    pairs.each do |e, a|
      next checks << g.check("allergies[#{e[:name]}]", e[:name], nil) unless a

      checks << g.check("allergies[#{e[:name]}].severity", e[:severity], a[:severity])
    end
    extra.each { |a| checks << g.invented("allergies[extra]", a[:name]) }
    t[:trap_allergies].each do |trap|
      checks << g.exclusion("allergies excludes #{trap}", trap, allergies.map { |a|
        a[:name]
      },)
    end

    t[:conditions].each do |c|
      checks << g.check("conditions includes #{c}", c, conditions.find { |x|
        g.norm(x).include?(c)
      }, :loose,)
    end
    t[:trap_conditions].each { |trap| checks << g.exclusion("conditions excludes #{trap}", trap, conditions) }

    surgeries = out[:surgeries] || []
    t[:surgeries].each do |s|
      found = surgeries.find { |x| g.norm(x[:procedure]).include?(s[:procedure]) }
      checks << g.check("surgeries[#{s[:procedure]}].year", s[:year], found&.dig(:year))
    end
    t[:red_flags].each { |k, v| checks << g.check("red_flags.#{k}", v, out.dig(:red_flags, k)) }
    t[:consents].each { |k, v| checks << g.check("consents.#{k}", v, out.dig(:consents, k)) }
    checks
  end

  # Small enough for Bedrock's native grammar limits, with the same traps.
  INTAKE_LITE_FIELDS = proc do
    required :patient, Hash do
      required :first_name, String
      required :last_name, String
      optional :preferred_name, String, description: "Only if the patient gave one"
      required :date_of_birth, String, format: "date"
      required :phone, String, description: "Patient's own primary phone"
      optional :secondary_phone, String
      optional :employer, String
      required :address, Hash, description: "Current home address" do
        required :street, String, description: "Including unit, e.g. 4-123 Main St"
        required :city, String
        required :postal_code, String
      end
    end
    optional :emergency_contact, Hash do
      required :name, String
      required :phone, String
    end
    required :referral, Hash do
      required :referred_by, String
      optional :referral_date, String, format: "date"
      optional :urgency, String, enum: %w[routine urgent emergent], description: "Only if the referral states it"
    end
    required :medications, Array, description: "Medications the patient currently takes" do
      required :name, String, description: "Drug name only, e.g. Metformin"
      required :frequency, String, enum: %w[once_daily twice_daily three_times_daily as_needed weekly]
      optional :prescriber, String
    end
    required :allergies, Array, description: "The patient's own allergies" do
      required :name, String
      required :severity, String, enum: %w[mild moderate severe]
    end
    required :conditions, Array, of: String, description: "The patient's current diagnosed conditions"
    required :red_flags, Hash, description: "Screening answers about the patient" do
      required :night_pain, Riffer::Params::Boolean
      required :history_of_cancer, Riffer::Params::Boolean
    end
  end

  INTAKE_LITE_CHECKS = %w[
    patient.first_name patient.last_name patient.preferred_name patient.date_of_birth patient.phone patient.secondary_phone
    patient.employer patient.address.street patient.address.city patient.address.postal_code emergency_contact.name
    emergency_contact.phone referral.referred_by referral.referral_date referral.urgency medications allergies conditions
    red_flags.night_pain red_flags.history_of_cancer
  ].freeze

  def grade_intake_lite(out)
    grade_intake(out).select { |c| INTAKE_LITE_CHECKS.any? { |prefix| c.field.start_with?(prefix) } }
  end

  def grade_intake_xl(out)
    loose = %i[pronouns previous_imaging referral_source]
    numeric = %i[weight_kg]
    grade_intake(out) + Intake::XL_TRUTH.map do |field, expected|
      kind = if loose.include?(field)
               :loose
             elsif numeric.include?(field)
               :number
             elsif field == :personal_health_number
               :phone
             else
               :exact
             end
      g.check(field.to_s, expected, out[field], kind)
    end
  end

  # ── ledger ────────────────────────────────────────────────────────────────

  LEDGER_FIELDS = proc do
    required :line_items, Array, description: "Every ledger entry except voided ones, in the order they appear" do
      required :date, String, format: "date"
      required :patient_name, String, description: "As written, in normal capitalisation"
      required :entry, Riffer::Params::AnyOf do
        variant do
          required :kind, String, enum: ["service"]
          required :billing_code, String
          required :practitioner_name, String
          required :duration_minutes, Integer
          required :amount, Float
        end
        variant do
          required :kind, String, enum: ["product"]
          required :sku, String
          required :quantity, Integer
          required :unit_price, Float
          required :amount, Float
        end
        variant do
          required :kind, String, enum: ["adjustment"]
          required :reason, String, enum: Ledger::ADJUSTMENT_REASONS
          required :amount, Float, description: "Negative: adjustments are credits"
        end
      end
    end
    required :totals, Hash do
      required :services, Float
      required :products, Float
      required :adjustments, Float, description: "Negative"
      required :net, Float
    end
  end

  def grade_ledger(out)
    items = (out[:line_items] || []).map { |i| i.merge(i[:entry] || {}) }
    key = lambda { |e, a|
      a[:date] == e[:date] && a[:kind] == e[:kind] && a[:amount].is_a?(Numeric) && (a[:amount].abs - e[:amount].abs).abs < 0.011
    }
    strict = ->(e, a) { key.call(e, a) && g.norm(a[:patient_name]) == g.norm(e[:patient_name]) }
    pairs, extra = g.pair(Ledger::ENTRIES, items, strict, key)
    voids = Ledger::RENDERED.select { |e| e[:void] }

    checks = [g.check("line_items.count", Ledger::ENTRIES.size, items.size)]
    pairs.each_with_index do |(e, a), i|
      prefix = "line_items[#{i}]"
      next checks << g.check(prefix, "#{e[:kind]} #{e[:date]}", nil) unless a

      checks << g.check("#{prefix}.patient_name", e[:patient_name], a[:patient_name], :text)
      checks << g.check("#{prefix}.amount_sign", e[:amount].negative?, a[:amount].negative?)
      case e[:kind]
      when "service"
        checks << g.check("#{prefix}.billing_code", e[:billing_code], a[:billing_code])
        checks << g.check("#{prefix}.practitioner_name", e[:practitioner_name], a[:practitioner_name], :text)
        checks << g.check("#{prefix}.duration_minutes", e[:duration_minutes], a[:duration_minutes])
      when "product"
        checks << g.check("#{prefix}.sku", e[:sku], a[:sku])
        checks << g.check("#{prefix}.quantity", e[:quantity], a[:quantity])
      when "adjustment"
        checks << g.check("#{prefix}.reason", e[:reason], a[:reason])
      end
    end
    extra.each do |a|
      void = voids.any? { |v| key.call(v, a) }
      checks << g.invented(void ? "line_items[voided entry included]" : "line_items[unmatched]",
                           "#{a[:kind]} #{a[:date]} #{a[:amount]}",)
    end
    Ledger.totals.each { |k, v| checks << g.check("totals.#{k}", v, out.dig(:totals, k), :number) }
    checks
  end

  # ── pre-visit summary ─────────────────────────────────────────────────────

  PREVISIT_FIELDS = proc do
    required :patient_id, String
    required :full_name, String
    required :date_of_birth, String, format: "date"
    required :allergies, Array do
      required :substance, String
      required :severity, String, enum: %w[mild moderate severe]
    end
    required :active_medications, Array, of: String
    optional :next_appointment, Hash, description: "Earliest booked appointment from today onward; null if none" do
      required :appointment_id, String
      required :date, String, format: "date"
      required :practitioner_name, String
      required :discipline, String, enum: Clinic::DISCIPLINES
    end
    required :history_12_months, Hash, description: "Appointments dated within the 12 months before today" do
      required :completed, Integer
      required :no_shows, Integer
      required :late_cancellations, Integer
    end
    optional :insurance, Hash, description: "Null if no policy on file" do
      required :insurer, String
      required :policy_number, String
      optional :group_number, String
      required :remaining_coverage_for_next_discipline, Float,
               description: "Annual maximum minus used this year, for the discipline of the next appointment (0 if not covered)"
    end
    optional :emergency_contact, Hash do
      required :name, String
      required :phone, String
    end
    required :alerts, Array, of: String,
                             description: "Clinically or administratively important points for the front desk"
  end

  def grade_previsit(patient_id, out)
    p = Clinic.patient(patient_id)
    nb = Clinic.next_booked(patient_id)
    l12 = Clinic.last_12_months(patient_id)
    allergies = out[:allergies] || []
    meds = out[:active_medications] || []

    checks = [
      g.check("patient_id", patient_id, out[:patient_id]),
      g.check("full_name", "#{p[:first_name]} #{p[:last_name]}", out[:full_name], :text),
      g.check("date_of_birth", p[:date_of_birth], out[:date_of_birth]),
      g.check("allergies.count", p[:allergies].size, allergies.size),
      g.check("active_medications.count", p[:medications].size, meds.size),
      g.check("next_appointment.appointment_id", nb&.dig(:appointment_id), out.dig(:next_appointment, :appointment_id)),
      g.check("next_appointment.date", nb&.dig(:date), out.dig(:next_appointment, :date)),
      g.check("next_appointment.practitioner_name", nb && Clinic.practitioner(nb[:practitioner_id])[:name],
              out.dig(:next_appointment, :practitioner_name), :text,),
      g.check("next_appointment.discipline", nb&.dig(:discipline), out.dig(:next_appointment, :discipline)),
      g.check("history_12_months.completed", l12.count do |a|
        a[:status] == "completed"
      end, out.dig(:history_12_months, :completed),),
      g.check("history_12_months.no_shows", l12.count do |a|
        a[:status] == "no_show"
      end, out.dig(:history_12_months, :no_shows),),
      g.check("history_12_months.late_cancellations", l12.count { |a| a[:status] == "cancelled_late" },
              out.dig(:history_12_months, :late_cancellations),),
      g.check("insurance.insurer", p.dig(:insurance, :insurer), out.dig(:insurance, :insurer), :text),
      g.check("insurance.policy_number", p.dig(:insurance, :policy_number), out.dig(:insurance, :policy_number)),
      g.check("insurance.group_number", p.dig(:insurance, :group_number), out.dig(:insurance, :group_number)),
      g.check("insurance.remaining_coverage", nb && p[:insurance] && Clinic.remaining_coverage(patient_id, nb[:discipline]),
              out.dig(:insurance, :remaining_coverage_for_next_discipline), :number,),
      g.check("emergency_contact.name", p.dig(:emergency_contact, :name), out.dig(:emergency_contact, :name), :text),
      g.check("emergency_contact.phone", p.dig(:emergency_contact, :phone), out.dig(:emergency_contact, :phone),
              :phone,),
    ]
    p[:allergies].each do |a|
      found = allergies.find { |x| g.norm(x[:substance]).include?(g.norm(a[:substance])) }
      checks << g.check("allergies[#{a[:substance]}].severity", a[:severity], found&.dig(:severity))
    end
    p[:medications].each do |m|
      drug = m.split.first
      checks << g.check("active_medications includes #{drug}", drug, meds.find { |x|
        g.norm(x).include?(g.norm(drug))
      }, :loose,)
    end
    checks
  end

  def chart_export(patient_id)
    p = Clinic.patient(patient_id)
    JSON.pretty_generate(
      chart: Clinic.public_patient(p),
      appointments: Clinic.appointments(patient_id),
      insurance_policy: Clinic.public_insurance(p) || "No insurance policy on file",
      practitioners: Clinic::PRACTITIONERS,
    )
  end

  # ── no-show report ────────────────────────────────────────────────────────

  NOSHOW_EXACT_FIELDS = %i[past_appointments no_shows late_cancellations risk_tier].freeze

  NOSHOW_PATIENTS = %w[P-10101 P-10215 P-10412 P-10633 P-10749 P-10856 P-11184 P-11290].freeze

  NOSHOW_FIELDS = proc do
    required :report_date, String, format: "date"
    required :patients, Array, description: "One row per requested patient, in the order requested" do
      required :patient_id, String
      required :full_name, String
      required :past_appointments, Integer
      required :no_shows, Integer
      required :late_cancellations, Integer
      required :no_show_rate, Float
      required :risk_tier, String, enum: %w[low medium high]
      optional :next_booked_date, String, format: "date", description: "Null if nothing is booked"
    end
    required :highest_risk_patient_id, String
  end

  def grade_noshow(out)
    rows = out[:patients] || []
    checks = [g.check("report_date", Clinic::TODAY.iso8601, out[:report_date]),
              g.check("patients.count", NOSHOW_PATIENTS.size, rows.size),]
    NOSHOW_PATIENTS.each do |id|
      p = Clinic.patient(id)
      stats = Clinic.no_show_stats(id)
      row = rows.find { |r| r[:patient_id] == id }
      next checks << g.check("patients[#{id}]", id, nil) unless row

      checks << g.check("patients[#{id}].full_name", "#{p[:first_name]} #{p[:last_name]}", row[:full_name], :text)
      NOSHOW_EXACT_FIELDS.each do |k|
        checks << g.check("patients[#{id}].#{k}", stats[k], row[k])
      end
      checks << g.check("patients[#{id}].no_show_rate", stats[:no_show_rate], row[:no_show_rate], :number)
      checks << g.check("patients[#{id}].next_booked_date", Clinic.next_booked(id)&.dig(:date), row[:next_booked_date])
    end
    (rows.map { |r| r[:patient_id] } - NOSHOW_PATIENTS).each { |id| checks << g.invented("patients[unrequested]", id) }
    top = NOSHOW_PATIENTS.max_by { |id| Clinic.no_show_stats(id)[:no_show_rate] }
    checks << g.check("highest_risk_patient_id", top, out[:highest_risk_patient_id])
    checks
  end

  # ── treatment plan ────────────────────────────────────────────────────────

  PLAN_FIELDS = proc do
    required :plan_title, String
    required :phases, Array do
      required :phase_number, Integer
      required :name, String
      required :duration_weeks, Integer
      required :entry_criteria, Array, of: String
      required :goals, Array do
        required :description, String
        required :measurable_target, String
        required :exercises, Array do
          required :exercise_id, String, description: "Library ID, e.g. EX-001"
          required :sets, Integer
          required :reps, Integer
          required :frequency_per_week, Integer
          required :progression, Hash do
            required :criterion, String
            required :next_step, String
          end
        end
      end
    end
    required :precautions, Array, of: String
  end

  def grade_plan(out)
    phases = out[:phases] || []
    library = TreatmentPlan::LIBRARY.to_h { |e| [e[:id], e] }
    checks = [
      g.check("phases.count", 4, phases.size),
      g.check("total_weeks", TreatmentPlan::TOTAL_WEEKS, phases.sum { |p| p[:duration_weeks].to_i }),
    ]
    phases.each_with_index do |phase, i|
      number = i + 1
      goals = phase[:goals] || []
      checks << g.constraint("phases[#{number}].goals 2-4", (2..4).cover?(goals.size), goals.size)
      restricted = TreatmentPlan::RESTRICTIONS.fetch(number, [])
      goals.each_with_index do |goal, j|
        exercises = goal[:exercises] || []
        checks << g.constraint("phases[#{number}].goals[#{j}].exercises 3-5", (3..5).cover?(exercises.size),
                               exercises.size,)
        exercises.each do |ex|
          entry = library[ex[:exercise_id]]
          next checks << g.invented("exercise_id not in library", ex[:exercise_id]) unless entry

          violated = entry[:tags] & restricted
          checks << g.constraint("phase #{number} restriction", violated.empty?,
                                 "#{entry[:id]} #{entry[:name]} (#{violated.join(', ')})",)
        end
      end
    end
    checks
  end

  # ── forced choice ─────────────────────────────────────────────────────────

  REFERRAL_LETTER = Intake::DOCUMENT[/GRANDVIEW FAMILY PRACTICE.*?MD CCFP/m]

  # Every field is required, and six have no answer in the letter: native
  # decoding cannot emit null for them, so it must abstain in-band or invent.
  FORCED_FIELDS = proc do
    required :patient_name, String
    required :referral_date, String, format: "date"
    required :working_diagnosis, String
    required :imaging_done, Riffer::Params::Boolean
    required :referring_clinic_phone, String
    required :urgency, String, enum: %w[routine urgent emergent]
    required :patient_email, String, format: "email"
    required :insurance_provider, String
    required :requested_visit_count, Integer
    required :workers_compensation_claim, Riffer::Params::Boolean
    required :preferred_practitioner_gender, String, enum: %w[female male no_preference]
  end

  FORCED_UNKNOWABLE = %i[urgency patient_email insurance_provider requested_visit_count workers_compensation_claim
                         preferred_practitioner_gender].freeze

  ABSTENTIONS = ["", "unknown", "not stated", "not provided", "not specified", "n a", "none", "not available"].freeze

  def grade_forced(out)
    stated = [
      g.check("patient_name", "Naomi Lindqvist", out[:patient_name], :loose),
      g.check("referral_date", "2026-10-06", out[:referral_date]),
      g.check("working_diagnosis", "rotator cuff", out[:working_diagnosis], :loose),
      g.check("imaging_done", true, out[:imaging_done]),
      g.check("referring_clinic_phone", "604-555-0100", out[:referring_clinic_phone], :phone),
    ]
    unknowable = FORCED_UNKNOWABLE.map do |field|
      value = out[field]
      abstained = value.nil? || (value.is_a?(String) && ABSTENTIONS.include?(g.norm(value)))
      Grading::Check.new(field: "#{field} (not in letter)", outcome: abstained ? :correct : :fabricated, expected: nil, actual: value)
    end
    stated + unknowable
  end

  # ── catalogue ─────────────────────────────────────────────────────────────

  ALL = [
    Scenario.new(
      key: "forced_choice", title: "Required fields the source can't answer",
      summary: "A short referral letter → 11 required fields, 6 of which the letter does not answer (incl. a required enum and a required email).",
      tools: :forbidden, required_tools: [],
      schema: params(&FORCED_FIELDS),
      prompt: "Fill in the referral intake record from this faxed referral letter.\n\n#{REFERRAL_LETTER}",
      grader: method(:grade_forced),
    ),
    Scenario.new(
      key: "intake_lite", title: "Intake packet, native-sized schema",
      summary: "The same packet and traps, trimmed to a schema Bedrock native accepts (~30 properties, 9 optional).",
      tools: :forbidden, required_tools: [],
      schema: params(&INTAKE_LITE_FIELDS),
      prompt: "Extract this new patient's key details for our EMR from the scanned intake packet below.\n\n#{Intake::DOCUMENT}",
      grader: method(:grade_intake_lite),
    ),
    Scenario.new(
      key: "intake", title: "Intake packet extraction",
      summary: "9k-char scanned intake packet → nested record (13 optional fields, 6 arrays). Traps: stopped meds, spouse's meds, sibling's allergy, old address.",
      tools: :forbidden, required_tools: [],
      schema: params(&INTAKE_FIELDS),
      prompt: "Extract this new patient's record for our EMR from the scanned intake packet below.\n\n#{Intake::DOCUMENT}",
      grader: method(:grade_intake),
    ),
    Scenario.new(
      key: "intake_xl", title: "Intake packet, extended schema",
      summary: "Same packet, 25 more optional fields (38 nullable in total) — over Bedrock's 16-union limit.",
      tools: :forbidden, required_tools: [],
      schema: params(&INTAKE_XL_FIELDS),
      prompt: "Extract this new patient's full record for our EMR from the scanned intake packet below.\n\n#{Intake::DOCUMENT}",
      grader: method(:grade_intake_xl),
    ),
    Scenario.new(
      key: "ledger", title: "Ledger reconciliation (80 rows)",
      summary: "80 mixed-format ledger rows + 5 voided rows → array of anyOf line items + totals. A billing-code lookup tool is available but unnecessary.",
      tools: :forbidden, required_tools: [],
      schema: params(&LEDGER_FIELDS),
      prompt: "Reconcile the September ledger below. Return every non-voided entry in the order it appears, normalised into line items, then the totals.\n\n#{Ledger.document}",
      grader: method(:grade_ledger),
    ),
    Scenario.new(
      key: "previsit_tools", title: "Pre-visit summary (tools required)",
      summary: "Only a patient ID is given; chart, appointments, insurance and practitioner must be fetched (4 tools). Patient has no emergency contact and no group number.",
      tools: :required, required_tools: %w[get_patient list_appointments get_insurance_policy],
      schema: params(&PREVISIT_FIELDS),
      prompt: "Prepare the pre-visit summary for patient P-10307 ahead of their next booked appointment.",
      grader: ->(out) { grade_previsit("P-10307", out) },
    ),
    Scenario.new(
      key: "previsit_context", title: "Pre-visit summary (data in prompt)",
      summary: "Same schema, but the full chart export is pasted in. Any tool call is unnecessary. Patient has no insurance and no emergency contact.",
      tools: :forbidden, required_tools: [],
      schema: params(&PREVISIT_FIELDS),
      prompt: "Prepare the pre-visit summary for patient P-11184 ahead of their next booked appointment. Here is the complete, current export of their chart, " \
              "appointment history, insurance and our practitioner list, pulled from the EMR five minutes ago — it has everything you need:\n\n#{chart_export('P-11184')}",
      grader: ->(out) { grade_previsit("P-11184", out) },
    ),
    Scenario.new(
      key: "noshow_tools", title: "No-show risk report, 8 patients (tools required)",
      summary: "8 patient IDs → per-patient stats computed from tool data (~16 tool calls). Four patients have nothing booked.",
      tools: :required, required_tools: %w[get_patient list_appointments],
      schema: params(&NOSHOW_FIELDS),
      prompt: <<~TEXT,
        Build a no-show risk report for these patients, in this order: #{NOSHOW_PATIENTS.join(', ')}.
        Definitions: past_appointments counts appointments dated before today with status completed, no_show or cancelled_late (ignore plain "cancelled").
        no_show_rate = (no_shows + late_cancellations) / past_appointments, rounded to 2 decimals.
        risk_tier: high if rate >= 0.30, medium if rate >= 0.15, otherwise low.
        next_booked_date is the earliest "booked" appointment from today onward.
        highest_risk_patient_id is the patient with the highest no_show_rate (first in the list on ties).
      TEXT
      grader: method(:grade_noshow),
    ),
    Scenario.new(
      key: "treatment_plan", title: "Treatment plan, 4 levels deep",
      summary: "Generate a 16-week, 4-phase rehab plan (phases → goals → exercises → progression) using only library IDs and obeying per-phase restrictions.",
      tools: :forbidden, required_tools: [],
      schema: params(&PLAN_FIELDS),
      prompt: "Write the full rehab plan for this patient.\n\n#{TreatmentPlan::NOTE}",
      grader: method(:grade_plan),
    ),
  ].freeze

  def find(key) = ALL.find { |s| s.key == key } || raise(ArgumentError, "unknown scenario #{key}")
end
