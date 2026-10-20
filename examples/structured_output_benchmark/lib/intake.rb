# frozen_string_literal: true

# A new-patient intake packet (form, free-text history, referral letter and
# clinic boilerplate). It is full of traps: a discontinued statin, the spouse's
# warfarin, a sister's sulfa allergy, the mother's cancer, an old Calgary
# address and the referring clinic's phone number.
module Intake
  TRUTH = {
    patient: {
      first_name: "Naomi", last_name: "Lindqvist", preferred_name: nil,
      date_of_birth: "1985-07-09", email: "naomi.lindqvist@example.org",
      phone: "604-555-0168", secondary_phone: nil,
      address: { street: "4-2211 Commercial Drive", city: "Vancouver", province: "BC", postal_code: "V5N 4B4" },
      occupation: "Elementary school teacher", employer: nil,
    },
    emergency_contact: { name: "Erik Lindqvist", relationship: "spouse", phone: "604-555-0169" },
    family_physician: { name: "Dr. Helen Mbeki", clinic: "Grandview Family Practice" },
    insurance: { insurer: "Pacific Blue Cross", policy_number: "PBC-603318", member_id: "NL-77810" },
    referral: {
      referred_by: "Dr. Helen Mbeki", referral_date: "2026-10-06", urgency: nil,
    },
    presenting_complaints: [
      { body_region: "shoulder", side: "right", pain_now: 4, pain_worst: 8, onset: "2026-08-15" },
      { body_region: "neck", side: "bilateral", pain_now: 2, pain_worst: 5, onset: "2026-09-01" },
      { body_region: "lower_back", side: "left", pain_now: 1, pain_worst: 6, onset: "2026-03-10" },
    ],
    medications: [
      { name: "Naproxen", frequency: "twice_daily", prescriber: "Dr. Helen Mbeki" },
      { name: "Levothyroxine", frequency: "once_daily", prescriber: "Dr. Helen Mbeki" },
      { name: "Sumatriptan", frequency: "as_needed", prescriber: nil },
      { name: "Vitamin D", frequency: "once_daily", prescriber: nil },
    ],
    trap_medications: %w[atorvastatin warfarin cyclobenzaprine],
    allergies: [
      { name: "Penicillin", severity: "moderate" },
      { name: "Adhesive", severity: "mild" },
    ],
    trap_allergies: %w[latex sulfa],
    conditions: %w[hypothyroidism migraine],
    trap_conditions: %w[cholesterol atrial afib cancer hyperlipid],
    surgeries: [{ procedure: "appendectomy", year: 2003 }, { procedure: "acl", year: 2012 }],
    red_flags: { unexplained_weight_loss: false, night_pain: true, bowel_bladder_changes: false, fever: false,
                 history_of_cancer: false, },
    consents: { treatment: true, email_reminders: true, sms_reminders: false, research: false },
  }.freeze

  XL_TRUTH = {
    pronouns: "she/her", height_cm: 168, weight_kg: 64.0, smoking_status: "former", alcohol_drinks_per_week: 3,
    dominant_hand: "right", blood_type: nil, marital_status: "married", number_of_children: nil,
    work_status: "full_time", workers_comp_claim: false, motor_vehicle_accident: false, previous_physiotherapy: true,
    previous_imaging: "X-ray", preferred_contact_method: "email", preferred_language: nil, interpreter_required: nil,
    pharmacy: nil, personal_health_number: "9876 543 210", gender_identity: nil, sleep_hours_per_night: 5,
    stress_level: nil, referral_source: "Google", accessibility_needs: nil, legal_guardian: nil,
  }.freeze

  BOILERPLATE = <<~TEXT
    CLINIC POLICIES — PLEASE READ AND KEEP FOR YOUR RECORDS

    Cancellation policy. We require 24 hours' notice to cancel or reschedule an appointment. Appointments cancelled with less than 24 hours' notice, and missed appointments, are charged the full appointment fee. This fee is not covered by extended-health insurance plans. We understand that emergencies happen; please speak to the front desk if you believe an exception applies to you. Repeated missed appointments may result in a requirement to prepay future bookings.

    Direct billing. As a courtesy we will submit claims directly to participating insurers. Coverage is determined by your plan, not by the clinic, and you remain responsible for any portion your insurer declines. If your insurer requires a physician referral for coverage, it is your responsibility to provide it before your first visit. Please notify us of any change in your coverage, policy number, or plan member details as soon as possible; claims rejected because of outdated information will be billed to you.

    Privacy. Your personal health information is collected, used and disclosed in accordance with the Personal Information Protection Act (British Columbia). We collect only the information necessary to provide care, to bill you or your insurer, and to meet our legal and professional obligations. Your record is stored in a secure, Canadian-hosted electronic medical record. You may request a copy of your record at any time. We will not share your information with third parties, including family members, without your consent, except where required or permitted by law.

    Communication. Appointment reminders are sent by email and/or text message according to the preferences you indicate on the consent section of this form. Reminders contain the date, time and location of your visit but no clinical details. You may change your preferences at any time through the patient portal or by asking the front desk.

    Informed consent to treatment. Treatment may include, but is not limited to, manual therapy, joint mobilisation and manipulation, soft-tissue techniques, dry needling, therapeutic exercise, education, taping and electrotherapeutic modalities. Your practitioner will explain the nature, benefits and risks of any proposed treatment and the alternatives available, and you may ask questions or withdraw consent at any time. Common, temporary side effects include soreness, stiffness and fatigue. Rare but serious risks will be discussed before any technique to which they apply.

    Research. From time to time the clinic participates in ethics-approved research and quality-improvement projects. Participation is entirely voluntary, does not affect your care, and requires your explicit opt-in on the consent section of this form. De-identified data may be used for aggregate reporting.

    Scent-free and accessible clinic. Please refrain from wearing perfume, cologne or other scented products. All treatment rooms are on the ground floor and are wheelchair accessible. Service animals are welcome. Please let us know if you need any accommodation and we will do our best to provide it.

    Payment. Payment is due at the time of service. We accept debit, Visa, Mastercard and American Express. Gift cards purchased at the clinic may be used for any service or product. Prices are subject to change with 30 days' notice. Receipts are emailed automatically if you have an email address on file.

    Children and dependants. Patients under the age of 16 must be accompanied by a parent or legal guardian for their first visit, and a guardian must sign the consent section of this form. For adult patients who have a legal guardian or representative, please provide that person's details and documentation of their authority.
  TEXT

  DOCUMENT = <<~TEXT.freeze
    ==================================================================
    GRANVILLE ISLAND PHYSIO & WELLNESS — NEW PATIENT INTAKE PACKET
    Scanned 2026-10-14 · 6 pages · OCR confidence: medium
    ==================================================================

    --- PAGE 1: PATIENT INFORMATION ---------------------------------
    Legal last name: LINDQVIST            Legal first name: Naomi
    Preferred name (if different): ______________________
    Pronouns: she/her                     Gender identity: (left blank)
    Date of birth (DD/MM/YYYY): 09/07/1985
    Personal Health Number (BC Care Card): 9876 543 210
    Mobile phone: (604) 555-0168          Other phone: ______________
    Email: naomi.lindqvist@example.org
    Preferred contact method: [x] Email  [ ] Phone  [ ] Text
    Home address: Unit 4 – 2211 Commercial Drive, Vancouver, BC  V5N 4B4
    Occupation: Elementary school teacher (Grade 3)
    Employer: prefer not to say
    Work status: [x] Full-time [ ] Part-time [ ] Off work [ ] Retired [ ] Student
    Marital status: Married
    Dominant hand: Right
    Height: 5'6" (168 cm)     Weight: 64 kg
    How did you hear about us? Googled "physio near Commercial Drive"

    --- PAGE 2: EMERGENCY CONTACT, PHYSICIAN & INSURANCE ------------
    Emergency contact: Erik Lindqvist — relationship: husband
      phone: 604-555-0169
    Family physician: Dr. Helen Mbeki, Grandview Family Practice
    Extended health insurer: Pacific Blue Cross
      Policy / contract #: PBC-603318
      Member / certificate ID: NL-77810
      Is this a work-related injury (WorkSafeBC)? [ ] Yes [x] No
      Is this related to a motor vehicle accident (ICBC)? [ ] Yes [x] No

    --- PAGE 3: REASON FOR VISIT ------------------------------------
    Please describe each area of pain. Use 0 (no pain) to 10 (worst imaginable).

    Area 1: RIGHT shoulder. Pain right now: 4/10. At its worst: 8/10.
      When did it start? 15 Aug 2026 — I was repainting the back fence all weekend.
      What makes it worse? Reaching up to high shelves / anything overhead, lying
      on my right side at night, carrying grocery bags.
      It wakes me up most nights (I'm getting maybe 5 hours of sleep).

    Area 2: Neck — stiff on both sides. Now: 2/10, worst: 5/10.
      Started: around Sept 1 2026 (back-to-school; started marking again).
      Worse with looking down at marking and with driving.

    Area 3: Low back, left side. Now 1/10, worst 6/10.
      Started 10/03/2026 (DD/MM/YYYY) after a long flight. Prolonged sitting makes it worse.
      I saw a physio in Calgary for my back in 2024 and it helped a lot.

    Imaging: my doctor sent me for an X-ray of the right shoulder on 2026-09-20; she said it was unremarkable.

    Goals: get back to swimming laps, lift my arm overhead without pain, sleep through the night.

    --- PAGE 4: MEDICAL HISTORY -------------------------------------
    Current medications (name, dose, how often, prescribed by):
      1. Naproxen 250 mg — twice a day with food — Dr. Mbeki
      2. Levothyroxine 50 mcg — every morning — Dr. Mbeki
      3. Sumatriptan 50 mg — only when I get a migraine
      4. Vitamin D 1000 IU — daily (bought it myself)
    Medications you have stopped in the past year:
      - Atorvastatin 10 mg — stopped in January, my cholesterol came down with diet changes
        so Dr. Mbeki took me off it. High cholesterol is no longer an issue.
      - Cyclobenzaprine — a short course last year for a back flare, finished.

    Allergies:
      Penicillin — reaction: hives   severity: [ ] mild [x] moderate [ ] severe
      Adhesive bandages / medical tape — redness   severity: [x] mild [ ] moderate [ ] severe
      Latex: no known allergy. (My sister is allergic to sulfa drugs, not me.)

    Medical conditions: Hypothyroidism (diagnosed 2019). Migraines (since my teens).
    Surgeries: Appendix removed in 2003. Left ACL reconstruction, 2012 (skiing).
    Family history: Mother — breast cancer, diagnosed age 62, in remission. Father — type 2 diabetes.
    Smoking: former smoker, quit in 2015.  Alcohol: about 3 drinks a week.

    Please check any that apply to you:
      [ ] Unexplained weight loss       [x] Pain at night that wakes you
      [ ] Changes in bowel or bladder   [ ] Fever or chills
      [ ] Personal history of cancer

    Notes about my household: Erik (my husband, emergency contact above) takes warfarin
    for AFib, so if you ever need to call him please don't keep him on the phone during
    his INR clinic on Thursday mornings!

    --- PAGE 5: CONSENT ---------------------------------------------
    [x] I consent to assessment and treatment.
    [x] I would like appointment reminders by email.
    [ ] I would like appointment reminders by text message.
    [ ] I agree to be contacted about research studies.
    Signed: N. Lindqvist   Date: 2026-10-14
    (Previous address for our records: 88 Kensington Rd NW, Calgary, AB T2N 3P8 — moved spring 2025)

    --- PAGE 6: REFERRAL LETTER (faxed) -----------------------------
    GRANDVIEW FAMILY PRACTICE · 1650 Grant St, Vancouver BC · Tel 604-555-0100 · Fax 604-555-0101

    6 October 2026

    Re: Ms. Naomi Lindqvist (DOB 1985-07-09)

    Dear colleague,

    Thank you for seeing this pleasant 41-year-old teacher with a two-month history of right
    shoulder pain and reduced active range of motion, worse with overhead activity and at
    night. Examination suggests rotator cuff tendinopathy with possible subacromial
    involvement; X-ray was unremarkable. I have started naproxen 250 mg BID. Please assess
    and treat. Her thyroid function is stable on levothyroxine.

    Yours sincerely,
    Dr. Helen Mbeki, MD CCFP

    ------------------------------------------------------------------
    #{BOILERPLATE}
  TEXT
end
