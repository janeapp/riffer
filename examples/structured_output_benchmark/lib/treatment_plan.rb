# frozen_string_literal: true

# A post-operative shoulder rehab note and an exercise library. The plan must
# only reference library IDs and must not prescribe exercises tagged with a
# restriction during the phases the surgeon restricted them.
module TreatmentPlan
  REGIONS = {
    "shoulder" => ["pendulum swing", "table slide flexion", "wand-assisted external rotation", "scapular retraction",
                   "isometric internal rotation", "isometric external rotation", "sidelying external rotation",
                   "band row", "band pull-apart", "wall slide", "prone Y raise", "overhead press", "push-up plus",
                   "wall push-up", "cable external rotation at 90 degrees", "overhead carry", "medicine-ball chest pass",
                   "plank shoulder tap", "full can raise", "landmine press",],
    "core" => ["dead bug", "bird dog", "side plank", "pallof press", "glute bridge", "front plank", "suitcase carry",
               "farmer carry", "hollow hold", "cat-camel",],
    "lower" => ["sit-to-stand", "split squat", "step-up", "goblet squat", "Romanian deadlift", "box jump",
                "lateral band walk", "calf raise", "jump squat", "single-leg balance",],
    "cardio" => ["stationary bike", "brisk walk", "elliptical", "treadmill jog", "rowing machine", "swimming freestyle",
                 "jump rope", "stair climber", "aqua jogging", "recumbent stepper",],
    "mobility" => ["thoracic extension over roller", "doorway pec stretch", "sleeper stretch", "cross-body stretch",
                   "neck retraction", "upper trapezius stretch", "open book rotation", "child's pose",
                   "levator scapulae stretch", "diaphragmatic breathing",],
  }.freeze

  TAGS = {
    "overhead" => ["wall slide", "prone Y raise", "overhead press", "overhead carry", "landmine press",
                   "swimming freestyle",],
    "resisted_shoulder" => ["band row", "band pull-apart", "overhead press", "push-up plus", "cable external rotation at 90 degrees",
                            "overhead carry", "medicine-ball chest pass", "plank shoulder tap", "full can raise", "landmine press",
                            "front plank", "side plank", "farmer carry", "suitcase carry", "rowing machine", "wall push-up",
                            "sidelying external rotation",],
    "impact" => ["box jump", "jump squat", "jump rope", "treadmill jog"],
    "stretch_into_end_range" => ["sleeper stretch", "cross-body stretch", "doorway pec stretch"],
  }.freeze

  LIBRARY = REGIONS.flat_map do |region, names|
    names.map do |n|
      [region, n]
    end
  end.each_with_index.map do |(region, name), i|
    { id: format("EX-%03d", i + 1), name: name, region: region, tags: TAGS.select do |_, list|
      list.include?(name)
    end.keys, }
  end.freeze

  IDS = LIBRARY.to_set { |e| e[:id] }.freeze

  # Restricted tags by phase number (1-based).
  RESTRICTIONS = {
    1 => %w[overhead resisted_shoulder impact stretch_into_end_range],
    2 => %w[overhead resisted_shoulder impact],
    3 => %w[overhead impact],
    4 => [],
  }.freeze

  TOTAL_WEEKS = 16

  NOTE = <<~TEXT.freeze
    PHYSIOTHERAPY ASSESSMENT & PLAN REQUEST — Rahul Mehta, 60 y/o, right-hand dominant

    Surgery: right arthroscopic rotator cuff repair (supraspinatus, medium tear) on 2026-10-06, Dr. K. Ilunga.
    Comorbidities: type 2 diabetes (insulin), hypercholesterolaemia. Slower tendon healing expected.
    Goals: return to golf, lift carry-on luggage into overhead bins, swim with grandchildren by summer.

    Surgeon's protocol (mandatory):
      • The whole program is #{TOTAL_WEEKS} weeks, split into exactly 4 phases.
      • Phase 1 (protection): passive / assisted motion only. NO overhead work, NO resisted shoulder work,
        NO impact, NO stretching into end range.
      • Phase 2 (active motion): active motion allowed. Still NO overhead work, NO resisted shoulder work, NO impact.
      • Phase 3 (early strengthening): resisted shoulder work allowed below shoulder height. Still NO overhead
        work and NO impact.
      • Phase 4 (return to function): all exercises allowed as tolerated.
      • Each phase needs 2 to 4 goals; each goal needs 3 to 5 exercises from the library below. Use library IDs only.

    Exercise library (ID — name — region — restriction tags):
    #{LIBRARY.map { |e| "#{e[:id]} — #{e[:name]} — #{e[:region]} — #{e[:tags].empty? ? 'none' : e[:tags].join(', ')}" }.join("\n")}
  TEXT
end
