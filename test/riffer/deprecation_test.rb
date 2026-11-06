# frozen_string_literal: true

require "test_helper"

describe Riffer::Deprecation do
  let(:details) { { id: :test_api, message: "test_api is deprecated." } }

  after { reset_riffer_config! }

  describe ":warn" do
    before { Riffer.config.deprecations = :warn }

    it "names the calling line" do
      expected = "riffer: test_api is deprecated. Called from #{__FILE__}:"

      expect { Riffer::Deprecation.warn(**details) }.must_output(nil, "#{expected}#{__LINE__}.\n")
    end

    it "warns once per calling line" do
      expect { 2.times { Riffer::Deprecation.warn(**details) } }.must_output(nil, /\A[^\n]+deprecated[^\n]+\n\z/)
    end

    it "warns again from a different line" do
      expect { Riffer::Deprecation.warn(**details) }.must_output(nil, /deprecated/)
      expect { Riffer::Deprecation.warn(**details) }.must_output(nil, /deprecated/)
    end

    it "warns separately for each id on the same line" do
      two_lines = /\A[^\n]+deprecated[^\n]+\n[^\n]+deprecated[^\n]+\n\z/

      expect do
        %i[first_api second_api].each do |id|
          Riffer::Deprecation.warn(**details, id: id)
        end
      end.must_output(nil, two_lines)
    end
  end

  describe ":raise" do
    it "raises on every call from the same line" do
      2.times do
        error = expect { Riffer::Deprecation.warn(**details) }.must_raise Riffer::DeprecationError

        expect(error.message).must_include "Called from #{__FILE__}"
      end
    end
  end

  describe ":silence" do
    it "reports nothing" do
      Riffer.config.deprecations = :silence

      expect { Riffer::Deprecation.warn(**details) }.must_output(nil, "")
    end
  end

  describe "a callable" do
    it "receives the event once per calling line" do
      events = []
      Riffer.config.deprecations = ->(event) { events << event }
      line = __LINE__ + 1
      2.times { Riffer::Deprecation.warn(**details) }

      fields = events.map { |event| [event.id, event.message, event.location] }

      expect(fields).must_equal [[*details.values, "#{__FILE__}:#{line}"]]
    end
  end

  describe "Riffer::Testing.allow_deprecations" do
    it "silences deprecations inside the block and returns its value" do
      result = Riffer::Testing.allow_deprecations do
        Riffer::Deprecation.warn(**details)
        :done
      end

      expect(result).must_equal :done
    end

    it "restores reporting after the block raises" do
      expect { Riffer::Testing.allow_deprecations { raise "boom" } }.must_raise RuntimeError

      expect { Riffer::Deprecation.warn(**details) }.must_raise Riffer::DeprecationError
    end

    it "silences threads started inside the block" do
      result = Riffer::Testing.allow_deprecations do
        Thread.new do
          Riffer::Deprecation.warn(**details)
          :done
        end.value
      end

      expect(result).must_equal :done
    end

    it "leaves other threads reporting" do
      ready = Queue.new
      thread = Thread.new do
        ready.pop
        Riffer::Deprecation.warn(**details)
      end
      thread.report_on_exception = false

      Riffer::Testing.allow_deprecations do
        ready << true

        expect { thread.join }.must_raise Riffer::DeprecationError
      end
    end
  end
end
