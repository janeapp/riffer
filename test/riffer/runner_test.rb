# frozen_string_literal: true

require "test_helper"

describe Riffer::Runner do
  describe "#map" do
    it "raises NotImplementedError" do
      runner = Riffer::Runner.new
      expect { runner.map([1, 2, 3]) { |n| n } }.must_raise NotImplementedError
    end
  end
end

describe Riffer::Runner::Sequential do
  describe "#map" do
    it "returns results in order" do
      runner = Riffer::Runner::Sequential.new
      results = runner.map([1, 2, 3]) { |n| n * 2 }
      expect(results).must_equal [2, 4, 6]
    end

    it "handles empty items" do
      runner = Riffer::Runner::Sequential.new
      results = runner.map([]) { |n| n }
      expect(results).must_equal []
    end
  end
end

describe Riffer::Runner::Threaded do
  describe "#map" do
    it "returns results in order" do
      runner = Riffer::Runner::Threaded.new
      results = runner.map([1, 2, 3]) { |n| n * 2 }
      expect(results).must_equal [2, 4, 6]
    end

    it "executes concurrently" do
      runner = Riffer::Runner::Threaded.new(max_concurrency: 3)
      thread_ids = Mutex.new
      seen = []

      runner.map([1, 2, 3]) do |n|
        thread_ids.synchronize { seen << Thread.current.object_id }
        sleep 0.01
        n
      end

      # Each item runs in its own thread, so we should see distinct thread ids
      expect(seen.uniq.length).must_equal 3
    end

    it "respects max_concurrency" do
      runner = Riffer::Runner::Threaded.new(max_concurrency: 2)
      mutex = Mutex.new
      concurrent = 0
      max_concurrent = 0

      runner.map([1, 2, 3, 4]) do |n|
        mutex.synchronize do
          concurrent += 1
          max_concurrent = [max_concurrent, concurrent].max
        end
        sleep 0.02
        mutex.synchronize { concurrent -= 1 }
        n
      end

      expect(max_concurrent).must_be :<=, 2
    end

    it "handles empty items" do
      runner = Riffer::Runner::Threaded.new
      results = runner.map([]) { |n| n }
      expect(results).must_equal []
    end

    it "propagates exceptions from worker threads" do
      runner = Riffer::Runner::Threaded.new(max_concurrency: 2)
      expect {
        runner.map([1, 2, 3]) do |n|
          raise "boom" if n == 2
          n
        end
      }.must_raise RuntimeError
    end
  end
end
