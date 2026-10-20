# frozen_string_literal: true

require "json"

# A long front-desk chat where every assistant turn is a structured reply. The
# final turn needs a tool lookup, so the model must keep both the reply shape
# and its tool discipline across a conversation of 16 user messages.
module Chat
  def self.reply(text, action: "none", patient_ids: [], appointment_date: nil, follow_up_reason: nil)
    JSON.generate(reply: text, action: action, patient_ids: patient_ids, appointment_date: appointment_date,
                  follow_up_reason: follow_up_reason,)
  end

  EXCHANGES = [
    ["Morning! Front desk here (Priya). Pasting our policy sheet so you have it:\n\n#{Intake::BOILERPLATE}\nWhat's our cancellation notice period again?",
     reply("We need 24 hours' notice. Later cancellations and no-shows are charged the full appointment fee."),],
    ["Thanks. A walk-in is asking if we direct bill Pacific Blue Cross.",
     reply("Yes, we direct bill participating insurers including Pacific Blue Cross. The patient pays any portion the insurer declines."),],
    ["Ok. Marcus Delacroix-Ng (P-10215) just called and was really upset about his no-show fee. He's asking for it to be waived.",
     reply("I can't waive fees. A clinic manager needs to review the request.", action: "escalate", patient_ids: ["P-10215"],
                                                                                follow_up_reason: "Patient requests a no-show fee waiver; manager approval needed.",),],
    ["Got it, I'll leave a note for Dana. Do we have wheelchair access in every treatment room?",
     reply("Yes. All treatment rooms are on the ground floor and wheelchair accessible."),],
    ["Can service dogs come into treatment rooms?",
     reply("Yes, service animals are welcome throughout the clinic."),],
    ["Evelyn Harper (P-10101) wants to know if she can use a gift card toward her physio.",
     reply("Yes, clinic gift cards can be used for any service or product.", patient_ids: ["P-10101"]),],
    ["What cards do we take?",
     reply("Debit, Visa, Mastercard and American Express."),],
    ["Kenji Watanabe (P-10412) wants to move his physio to Thursday at 3. Can you just do it?",
     reply("I can't change bookings from here. Please reschedule it in the scheduler.", action: "reschedule", patient_ids: ["P-10412"],
                                                                                        follow_up_reason: "Front desk to move the physiotherapy booking to Thursday 3pm.",),],
    ["Done, I moved it myself. Is there a fragrance policy?",
     reply("Yes, the clinic is scent-free. Please ask patients not to wear perfume or cologne."),],
    ["A mom is asking whether her 14-year-old can come in alone for massage.",
     reply("Patients under 16 must come with a parent or guardian for their first visit, and a guardian must sign the consent form."),],
    ["Fatima Zahra (P-10520) asked if her counselling sessions are covered.",
     reply("Coverage depends on her plan, not the clinic. She should check with her insurer, and we can direct bill participating insurers.", patient_ids: ["P-10520"]),],
    ["How far ahead do prices change?",
     reply("Prices change with 30 days' notice."),],
    ["Do reminders go out by text?",
     reply("Reminders go by email and/or text, based on each patient's consent preferences."),],
    ["Gordon MacLeod (P-10633) says he never got his receipt.",
     reply("Receipts are emailed automatically when there's an email on file. If he has none, offer to print one.", patient_ids: ["P-10633"]),],
    ["Perfect, printed it. Quick one: are we open on Remembrance Day?",
     reply("I don't have holiday hours. Please check with the clinic manager.", action: "escalate",
                                                                                follow_up_reason: "Holiday hours for November 11 are not documented.",),],
  ].freeze

  FINAL = "Next: when is Aaliyah Brennan's next appointment? Her ID is P-10307. Don't book or change anything, just tell me the date."

  def self.messages
    history = EXCHANGES.flat_map do |user, assistant|
      [Riffer::Messages::User.new(user), Riffer::Messages::Assistant.new(assistant)]
    end
    history + [Riffer::Messages::User.new(FINAL)]
  end
end
