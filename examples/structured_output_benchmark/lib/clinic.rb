# frozen_string_literal: true

require "date"

# A fake practice-management backend. Every value the tools return is derived
# from these constants, so graders can compute ground truth from the same data.
module Clinic
  TODAY = Date.new(2026, 10, 20)

  PRACTITIONERS = [
    { id: "PR-01", name: "Dr. Amara Okafor", discipline: "physiotherapy", location: "Vancouver - Main St" },
    { id: "PR-02", name: "Liam Chen", discipline: "massage_therapy", location: "Vancouver - Main St" },
    { id: "PR-03", name: "Dr. Sofia Marchetti", discipline: "chiropractic", location: "Burnaby - Metrotown" },
    { id: "PR-04", name: "Noah Tremblay", discipline: "physiotherapy", location: "Burnaby - Metrotown" },
    { id: "PR-05", name: "Dr. Priya Raman", discipline: "naturopathy", location: "Vancouver - Main St" },
    { id: "PR-06", name: "Hannah Kowalski", discipline: "counselling", location: "Telehealth" },
    { id: "PR-07", name: "Dr. Mateo Alvarez", discipline: "acupuncture", location: "Richmond - No. 3 Rd" },
    { id: "PR-08", name: "Grace Whitfield", discipline: "massage_therapy", location: "Richmond - No. 3 Rd" },
  ].freeze

  DISCIPLINES = %w[physiotherapy massage_therapy chiropractic naturopathy counselling acupuncture].freeze

  PATIENTS = [
    {
      id: "P-10101", first_name: "Evelyn", last_name: "Harper", date_of_birth: "1958-04-12",
      phone: "604-555-0142", email: "evelyn.harper@example.com",
      allergies: [{ substance: "Penicillin", severity: "severe", reaction: "anaphylaxis" }],
      medications: ["Metformin 500 mg twice daily", "Lisinopril 10 mg once daily"],
      emergency_contact: { name: "Thomas Harper", relationship: "spouse", phone: "604-555-0199" },
      insurance: { insurer: "Pacific Blue Cross", policy_number: "PBC-448812", group_number: "G-2231",
                   annual_max: { "physiotherapy" => 1500.0, "massage_therapy" => 500.0 },
                   used_ytd: { "physiotherapy" => 620.0, "massage_therapy" => 500.0 }, },
    },
    {
      id: "P-10215", first_name: "Marcus", last_name: "Delacroix-Ng", date_of_birth: "1987-11-03",
      phone: "778-555-0177", email: nil,
      allergies: [],
      medications: ["Sertraline 50 mg once daily"],
      emergency_contact: nil,
      insurance: nil,
    },
    {
      id: "P-10307", first_name: "Aaliyah", last_name: "Brennan", date_of_birth: "1994-02-28",
      phone: "604-555-0123", email: "aaliyah.b@example.com",
      allergies: [
        { substance: "Latex", severity: "moderate", reaction: "contact dermatitis" },
        { substance: "Ibuprofen", severity: "mild", reaction: "stomach upset" },
        { substance: "Shellfish", severity: "severe", reaction: "throat swelling" },
      ],
      medications: ["Levothyroxine 75 mcg once daily", "Cetirizine 10 mg as needed", "Norgestimate-ethinyl estradiol once daily"],
      emergency_contact: nil,
      insurance: { insurer: "Sun Life", policy_number: "SL-99-301277", group_number: nil,
                   annual_max: { "physiotherapy" => 800.0, "chiropractic" => 600.0, "massage_therapy" => 400.0 },
                   used_ytd: { "physiotherapy" => 345.5, "chiropractic" => 120.0, "massage_therapy" => 400.0 }, },
    },
    {
      id: "P-10412", first_name: "Kenji", last_name: "Watanabe", date_of_birth: "1971-07-19",
      phone: "604-555-0188", email: "kwatanabe@example.com",
      allergies: [{ substance: "Codeine", severity: "moderate", reaction: "nausea and dizziness" }],
      medications: ["Atorvastatin 20 mg once daily"],
      emergency_contact: { name: "Yuki Watanabe", relationship: "daughter", phone: "778-555-0105" },
      insurance: { insurer: "Manulife", policy_number: "ML-7731-02", group_number: "88120",
                   annual_max: { "physiotherapy" => 1000.0, "acupuncture" => 500.0 },
                   used_ytd: { "physiotherapy" => 1000.0, "acupuncture" => 75.0 }, },
    },
    {
      id: "P-10520", first_name: "Fatima", last_name: "Zahra", date_of_birth: "2001-09-30",
      phone: "236-555-0164", email: "fatima.zahra@example.com",
      allergies: [],
      medications: [],
      emergency_contact: { name: "Omar Zahra", relationship: "brother", phone: "236-555-0111" },
      insurance: { insurer: "Canada Life", policy_number: "CL-5520-118", group_number: "A-77",
                   annual_max: { "counselling" => 1200.0 }, used_ytd: { "counselling" => 450.0 }, },
    },
    {
      id: "P-10633", first_name: "Gordon", last_name: "MacLeod", date_of_birth: "1949-01-05",
      phone: "604-555-0131", email: nil,
      allergies: [{ substance: "Sulfa drugs", severity: "moderate", reaction: "rash" }],
      medications: ["Warfarin 5 mg once daily", "Amlodipine 5 mg once daily", "Tamsulosin 0.4 mg once daily"],
      emergency_contact: { name: "Morag MacLeod", relationship: "spouse", phone: "604-555-0132" },
      insurance: nil,
    },
    {
      id: "P-10749", first_name: "Isabela", last_name: "Costa", date_of_birth: "1990-06-14",
      phone: "778-555-0150", email: "isa.costa@example.com",
      allergies: [{ substance: "Peanuts", severity: "severe", reaction: "anaphylaxis" }],
      medications: ["Epinephrine auto-injector as needed"],
      emergency_contact: { name: "Rafael Costa", relationship: "partner", phone: "778-555-0151" },
      insurance: { insurer: "Pacific Blue Cross", policy_number: "PBC-771204", group_number: "G-9018",
                   annual_max: { "massage_therapy" => 750.0, "physiotherapy" => 750.0 },
                   used_ytd: { "massage_therapy" => 280.0, "physiotherapy" => 0.0 }, },
    },
    {
      id: "P-10856", first_name: "Dmitri", last_name: "Volkov", date_of_birth: "1983-03-22",
      phone: "604-555-0170", email: "d.volkov@example.com",
      allergies: [],
      medications: ["Omeprazole 20 mg once daily"],
      emergency_contact: nil,
      insurance: { insurer: "Green Shield", policy_number: "GS-30-55871", group_number: "3305",
                   annual_max: { "chiropractic" => 500.0 }, used_ytd: { "chiropractic" => 455.0 }, },
    },
    {
      id: "P-10962", first_name: "Chloe", last_name: "Abernathy", date_of_birth: "1999-12-08",
      phone: "236-555-0193", email: "chloe.abernathy@example.com",
      allergies: [{ substance: "Adhesive tape", severity: "mild", reaction: "redness" }],
      medications: [],
      emergency_contact: { name: "Janet Abernathy", relationship: "mother", phone: "236-555-0194" },
      insurance: nil,
    },
    {
      id: "P-11078", first_name: "Rahul", last_name: "Mehta", date_of_birth: "1966-08-17",
      phone: "604-555-0115", email: "rahul.mehta@example.com",
      allergies: [],
      medications: ["Insulin glargine 20 units once daily", "Rosuvastatin 10 mg once daily"],
      emergency_contact: { name: "Anita Mehta", relationship: "spouse", phone: "604-555-0116" },
      insurance: { insurer: "Sun Life", policy_number: "SL-12-880431", group_number: "14402",
                   annual_max: { "physiotherapy" => 2000.0, "massage_therapy" => 1000.0 },
                   used_ytd: { "physiotherapy" => 1310.0, "massage_therapy" => 240.0 }, },
    },
    {
      id: "P-11184", first_name: "Olivia", last_name: "Sinclair", date_of_birth: "1978-05-25",
      phone: "778-555-0129", email: "olivia.sinclair@example.com",
      allergies: [{ substance: "Aspirin", severity: "moderate", reaction: "wheezing" }],
      medications: ["Salbutamol inhaler as needed"],
      emergency_contact: nil,
      insurance: nil,
    },
    {
      id: "P-11290", first_name: "Tomasz", last_name: "Nowak", date_of_birth: "1992-10-02",
      phone: "604-555-0186", email: "tomasz.nowak@example.com",
      allergies: [],
      medications: [],
      emergency_contact: { name: "Ewa Nowak", relationship: "spouse", phone: "604-555-0187" },
      insurance: { insurer: "Canada Life", policy_number: "CL-1290-004", group_number: "A-12",
                   annual_max: { "physiotherapy" => 600.0 }, used_ytd: { "physiotherapy" => 90.0 }, },
    },
  ].freeze

  FEES = {
    "physiotherapy" => 115.0, "massage_therapy" => 105.0, "chiropractic" => 85.0,
    "naturopathy" => 160.0, "counselling" => 140.0, "acupuncture" => 95.0,
  }.freeze

  QUARTER_HOURS = [0, 15, 30, 45].freeze

  PAST_STATUSES = %w[completed completed completed completed completed completed no_show cancelled_late
                     cancelled].freeze

  module_function

  def patient(id) = PATIENTS.find { |p| p[:id] == id }

  def practitioner(id) = PRACTITIONERS.find { |p| p[:id] == id }

  def appointments(patient_id) = APPOINTMENTS.fetch(patient_id, [])

  # Deterministic per patient: a seeded history of past visits plus zero to two
  # future bookings, so some patients have no next appointment.
  def generate_appointments(patient_id)
    rng = Random.new(patient_id.delete("^0-9").to_i)
    pool = PRACTITIONERS.sample(2, random: rng)
    past_count = rng.rand(6..16)
    past_dates = Array.new(past_count) { TODAY - rng.rand(1..480) }.uniq.sort
    future_count = [0, 1, 1, 2].sample(random: rng)
    future_dates = Array.new(future_count) { TODAY + rng.rand(1..60) }.uniq.sort

    past = past_dates.map { |d| [d, PAST_STATUSES.sample(random: rng)] }
    future = future_dates.map { |d| [d, "booked"] }
    (past + future).each_with_index.map do |(date, status), i|
      pr = pool.sample(random: rng)
      {
        appointment_id: "A-#{patient_id.delete('^0-9')}-#{format('%02d', i + 1)}",
        date: date.iso8601,
        time: format("%02d:%02d", rng.rand(8..18), QUARTER_HOURS.sample(random: rng)),
        practitioner_id: pr[:id],
        discipline: pr[:discipline],
        status: status,
        fee: FEES.fetch(pr[:discipline]),
      }
    end
  end

  # Truth helpers shared by graders.

  def past_counted(patient_id)
    appointments(patient_id).select { |a| Date.parse(a[:date]) < TODAY && a[:status] != "cancelled" }
  end

  def last_12_months(patient_id)
    since = TODAY << 12
    past_counted(patient_id).select { |a| Date.parse(a[:date]) >= since }
  end

  def next_booked(patient_id)
    appointments(patient_id).
      select { |a| a[:status] == "booked" && Date.parse(a[:date]) >= TODAY }.
      min_by { |a| a[:date] }
  end

  def no_show_stats(patient_id)
    past = past_counted(patient_id)
    no_shows = past.count { |a| a[:status] == "no_show" }
    late = past.count { |a| a[:status] == "cancelled_late" }
    rate = past.empty? ? 0.0 : ((no_shows + late).to_f / past.size).round(2)
    tier = if rate >= 0.3
             "high"
           elsif rate >= 0.15
             "medium"
           else
             "low"
           end
    { past_appointments: past.size, no_shows: no_shows, late_cancellations: late, no_show_rate: rate, risk_tier: tier }
  end

  def remaining_coverage(patient_id, discipline)
    ins = patient(patient_id)[:insurance] or return nil
    max = ins[:annual_max][discipline] or return 0.0
    (max - ins[:used_ytd].fetch(discipline, 0.0)).round(2)
  end

  def public_patient(p)
    p.except(:insurance)
  end

  def public_insurance(p)
    ins = p[:insurance] or return nil
    {
      patient_id: p[:id], insurer: ins[:insurer], policy_number: ins[:policy_number], group_number: ins[:group_number],
      coverage: ins[:annual_max].map do |discipline, max|
        { discipline: discipline, annual_maximum: max, used_year_to_date: ins[:used_ytd].fetch(discipline, 0.0) }
      end,
    }
  end

  APPOINTMENTS = PATIENTS.to_h { |p| [p[:id], generate_appointments(p[:id]).freeze] }.freeze
end
