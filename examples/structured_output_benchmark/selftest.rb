# frozen_string_literal: true

# Checks the graders: a perfect answer built from ground truth must score 100%,
# and each planted hallucination must be caught.
#
#   bundle exec ruby examples/structured_output_benchmark/selftest.rb

require "bundler/setup"
require "riffer"

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "clinic"
require "ledger"
require "intake"
require "treatment_plan"
require "grading"
require "tools"
require "scenarios"

def assert(label, condition)
  puts "#{condition ? 'PASS' : 'FAIL'}  #{label}"
  exit 1 unless condition
end

def outcomes(checks) = checks.map(&:outcome).tally

def perfect_noshow
  {
    report_date: Clinic::TODAY.iso8601,
    patients: Scenarios::NOSHOW_PATIENTS.map do |id|
      p = Clinic.patient(id)
      Clinic.no_show_stats(id).merge(patient_id: id, full_name: "#{p[:first_name]} #{p[:last_name]}",
                                     next_booked_date: Clinic.next_booked(id)&.dig(:date),)
    end,
    highest_risk_patient_id: Scenarios::NOSHOW_PATIENTS.max_by { |id| Clinic.no_show_stats(id)[:no_show_rate] },
  }
end

def perfect_previsit(id)
  p = Clinic.patient(id)
  nb = Clinic.next_booked(id)
  l12 = Clinic.last_12_months(id)
  {
    patient_id: id, full_name: "#{p[:first_name]} #{p[:last_name]}", date_of_birth: p[:date_of_birth],
    allergies: p[:allergies].map { |a| a.slice(:substance, :severity) }, active_medications: p[:medications],
    next_appointment: nb && { appointment_id: nb[:appointment_id], date: nb[:date],
                              practitioner_name: Clinic.practitioner(nb[:practitioner_id])[:name], discipline: nb[:discipline], },
    history_12_months: { completed: l12.count { |a| a[:status] == "completed" }, no_shows: l12.count { |a| a[:status] == "no_show" },
                         late_cancellations: l12.count { |a| a[:status] == "cancelled_late" }, },
    insurance: p[:insurance] && { insurer: p.dig(:insurance, :insurer), policy_number: p.dig(:insurance, :policy_number),
                                  group_number: p.dig(:insurance, :group_number),
                                  remaining_coverage_for_next_discipline: Clinic.remaining_coverage(id, nb[:discipline]), },
    emergency_contact: p[:emergency_contact]&.slice(:name, :phone),
    alerts: [],
  }
end

def perfect_ledger
  items = Ledger::ENTRIES.map do |e|
    { date: e[:date], patient_name: e[:patient_name], entry: e.except(:date, :patient_name) }
  end
  { line_items: items, totals: Ledger.totals }
end

def perfect_intake
  t = Intake::TRUTH
  {
    patient: t[:patient], emergency_contact: t[:emergency_contact], family_physician: t[:family_physician], insurance: t[:insurance],
    referral: t[:referral].merge(reason: "shoulder"),
    presenting_complaints: t[:presenting_complaints],
    medications: t[:medications], allergies: t[:allergies], conditions: t[:conditions],
    surgeries: [{ procedure: "Appendectomy", year: 2003 }, { procedure: "Left ACL reconstruction", year: 2012 }],
    red_flags: t[:red_flags], consents: t[:consents],
  }
end

[
  ["noshow", Scenarios.grade_noshow(perfect_noshow)],
  ["previsit_tools", Scenarios.grade_previsit("P-10307", perfect_previsit("P-10307"))],
  ["previsit_context", Scenarios.grade_previsit("P-11184", perfect_previsit("P-11184"))],
  ["ledger", Scenarios.grade_ledger(perfect_ledger)],
  ["intake", Scenarios.grade_intake(perfect_intake)],
  ["intake_lite", Scenarios.grade_intake_lite(perfect_intake)],
  ["intake_xl", Scenarios.grade_intake_xl(perfect_intake.merge(Intake::XL_TRUTH))],
].each do |name, checks|
  assert("#{name}: perfect answer scores #{checks.size}/#{checks.size}", outcomes(checks).keys == [:correct])
end

bad_previsit = perfect_previsit("P-10307").merge(emergency_contact: { name: "Jane Brennan", phone: "604-555-0000" })
bad_previsit[:insurance] = bad_previsit[:insurance].merge(group_number: "G-1234")
assert("previsit: invented emergency contact and group number are fabrications",
       outcomes(Scenarios.grade_previsit("P-10307", bad_previsit))[:fabricated] == 3,)

bad_intake = perfect_intake.merge(medications: perfect_intake[:medications] + [{ name: "Warfarin", frequency: "once_daily" }])
assert("intake: spouse's warfarin is caught", outcomes(Scenarios.grade_intake(bad_intake))[:fabricated] == 2)

void = Ledger::RENDERED.find { |e| e[:void] }
bad_ledger = perfect_ledger.tap { |l| l[:line_items] += [{ date: void[:date], patient_name: void[:patient_name], entry: void.except(:date, :patient_name, :void) }] }
assert("ledger: an included voided row is a fabrication", Scenarios.grade_ledger(bad_ledger).any? { |c| c.field.include?("voided") })

bad_noshow = perfect_noshow.tap { |r| r[:patients] += [{ patient_id: "P-99999" }] }
assert("noshow: an unrequested patient is a fabrication", outcomes(Scenarios.grade_noshow(bad_noshow))[:fabricated] == 1)

overhead = TreatmentPlan::LIBRARY.find { |e| e[:tags].include?("overhead") }
plan = {
  phases: (1..4).map do |n|
    { duration_weeks: 4,
      goals: Array.new(2) { { exercises: Array.new(3) { { exercise_id: n == 1 ? overhead[:id] : "EX-999" } } } }, }
  end,
}
checks = Scenarios.grade_plan(plan)
assert("plan: invented IDs and phase-1 overhead work are caught",
       checks.count { |c| c.outcome == :fabricated } == 18 && checks.count { |c| c.field == "phase 1 restriction" && c.outcome == :wrong } == 6,)
