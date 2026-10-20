# frozen_string_literal: true

module ClinicTools
  class GetPatient < Riffer::Tool
    identifier "get_patient"
    description "Fetches a patient's chart: demographics, contact details, allergies, current medications and emergency contact."

    params do
      required :patient_id, String, description: "Patient ID, e.g. P-10101"
    end

    def call(context:, patient_id:)
      patient = Clinic.patient(patient_id) or return error("No patient with id #{patient_id}", type: :not_found)
      json(Clinic.public_patient(patient))
    end
  end

  class ListAppointments < Riffer::Tool
    identifier "list_appointments"
    description "Lists every appointment (past and future) for a patient, with date, practitioner, discipline, status and fee."

    params do
      required :patient_id, String, description: "Patient ID, e.g. P-10101"
    end

    def call(context:, patient_id:)
      return error("No patient with id #{patient_id}", type: :not_found) unless Clinic.patient(patient_id)

      json(appointments: Clinic.appointments(patient_id))
    end
  end

  class GetInsurancePolicy < Riffer::Tool
    identifier "get_insurance_policy"
    description "Fetches the patient's extended-health insurance policy on file, including per-discipline annual maximums and amounts used this year."

    params do
      required :patient_id, String, description: "Patient ID, e.g. P-10101"
    end

    def call(context:, patient_id:)
      patient = Clinic.patient(patient_id) or return error("No patient with id #{patient_id}", type: :not_found)
      policy = Clinic.public_insurance(patient)
      json(policy || { patient_id: patient_id, policy: nil, note: "No insurance policy on file" })
    end
  end

  class GetPractitioner < Riffer::Tool
    identifier "get_practitioner"
    description "Fetches a practitioner's name, discipline and clinic location."

    params do
      required :practitioner_id, String, description: "Practitioner ID, e.g. PR-01"
    end

    def call(context:, practitioner_id:)
      practitioner = Clinic.practitioner(practitioner_id)
      practitioner ? json(practitioner) : error("No practitioner with id #{practitioner_id}", type: :not_found)
    end
  end

  class SearchPractitioners < Riffer::Tool
    identifier "search_practitioners"
    description "Searches practitioners by discipline."

    params do
      required :discipline, String, enum: Clinic::DISCIPLINES
    end

    def call(context:, discipline:)
      json(practitioners: Clinic::PRACTITIONERS.select { |p| p[:discipline] == discipline })
    end
  end

  class LookupBillingCode < Riffer::Tool
    identifier "lookup_billing_code"
    description "Looks up a clinic billing code and returns its description and standard fee."

    params do
      required :code, String, description: "Billing code, e.g. PT-INIT"
    end

    def call(context:, code:)
      entry = Ledger::CODES[code] or return error("Unknown billing code #{code}", type: :not_found)
      json(code: code, **entry)
    end
  end

  ALL = [GetPatient, ListAppointments, GetInsurancePolicy, GetPractitioner, SearchPractitioners,
         LookupBillingCode,].freeze
end
