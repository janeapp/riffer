# frozen_string_literal: true
# rbs_inline: enabled

require "open3"

# Default +client+ for Riffer::Providers::ClaudeCode; any object implementing
# +#call+/+#stream+ with the same contract works. Spawns the CLI via Open3
# with +unsetenv_others+, so scrubbed env vars cannot leak back in from the
# parent process.
class Riffer::Providers::ClaudeCode::Client
  # A single monotonic deadline bounds child exit AND pipe drains, so a
  # grandchild that inherits the pipes cannot hang the call after the child
  # itself exits in time.
  #--
  #: (Array[String], env: Hash[String, String], stdin: String, chdir: String, timeout: Numeric) -> [String, String, Process::Status]
  def call(argv, env:, stdin:, chdir:, timeout:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    Open3.popen3(env, *argv, unsetenv_others: true, pgroup: true,
                             chdir: chdir,) do |stdin_io, stdout_io, stderr_io, wait_thr|
      stdout_reader = Thread.new { stdout_io.read }
      stderr_reader = Thread.new { stderr_io.read }
      # Written from a thread so a child that never drains stdin still hits
      # the deadline below instead of deadlocking the writer.
      writer = Thread.new do
        stdin_io.write(stdin)
      rescue Errno::EPIPE
        nil
      ensure
        stdin_io.close
      end

      pipe_threads = [writer, stdout_reader, stderr_reader]
      expire!(wait_thr, pipe_threads, timeout) unless joined?(wait_thr, remaining(deadline))
      pipe_threads.each do |thread|
        expire!(wait_thr, pipe_threads, timeout) unless joined?(thread, remaining(deadline))
      end

      [stdout_reader.value, stderr_reader.value, wait_thr.value]
    end
  rescue SystemCallError => e
    raise Riffer::Error, "claude CLI could not be spawned: #{e.message}"
  end

  # Any exit that doesn't drain the stream kills the process group and reaps
  # the pipe threads first, so popen3's ensure never closes the IOs out from
  # under a live reader thread.
  #--
  #: (Array[String], env: Hash[String, String], stdin: String, chdir: String, timeout: Numeric) { (String) -> void } -> [String, Process::Status]
  def stream(argv, env:, stdin:, chdir:, timeout:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    Open3.popen3(env, *argv, unsetenv_others: true, pgroup: true,
                             chdir: chdir,) do |stdin_io, stdout_io, stderr_io, wait_thr|
      lines = Queue.new
      stdout_reader = Thread.new do
        stdout_io.each_line { |line| lines << [:line, line] }
        lines << [:eof, nil]
      end
      stderr_reader = Thread.new { stderr_io.read }
      writer = Thread.new do
        stdin_io.write(stdin)
      rescue Errno::EPIPE
        nil
      ensure
        stdin_io.close
      end

      pipe_threads = [writer, stdout_reader, stderr_reader]
      done = false

      begin
        loop do
          wait = remaining(deadline)
          expire!(wait_thr, pipe_threads, timeout) if wait <= 0
          kind, payload = lines.pop(timeout: wait)
          next if kind.nil? # the pop itself timed out; the next iteration re-checks the deadline
          break if kind == :eof

          yield payload
        end

        expire!(wait_thr, pipe_threads, timeout) unless joined?(wait_thr, remaining(deadline))
        [writer, stderr_reader].each do |thread|
          expire!(wait_thr, pipe_threads, timeout) unless joined?(thread, remaining(deadline))
        end

        done = true
        [stderr_reader.value, wait_thr.value]
      ensure
        unless done
          kill_process_group(wait_thr.pid)
          pipe_threads.each { |thread| thread.kill unless joined?(thread, 1) }
          joined?(wait_thr, 1)
        end
      end
    end
  rescue SystemCallError => e
    raise Riffer::Error, "claude CLI could not be spawned: #{e.message}"
  end

  private

  # Seconds left until +deadline+, floored at zero so an expired deadline
  # turns the next join into a non-blocking check.
  #--
  #: (Float) -> Float
  def remaining(deadline)
    [deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0.0].max
  end

  # Group-kills the child (covering grandchildren that inherited the pipes)
  # and reaps the pipe threads before popen3's ensure closes their IOs under
  # them — the group kill unblocks the reads with EOF.
  #--
  #: (Process::Waiter, Array[Thread], Numeric) -> void
  def expire!(wait_thr, pipe_threads, timeout)
    kill_process_group(wait_thr.pid)
    pipe_threads.each { |thread| thread.kill unless joined?(thread, 1) }
    joined?(wait_thr, 1)
    raise Riffer::TimeoutError, "claude CLI timed out after #{timeout} seconds"
  end

  #--
  #: (Integer) -> void
  def kill_process_group(pid)
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

  # Thread#join is typed to always return the thread, never nil, even
  # though a timed-out join returns nil at runtime — assert the real type.
  #--
  #: (Thread, Numeric) -> bool
  def joined?(thread, wait)
    outcome = thread.join(wait) #: Thread?
    !outcome.nil?
  end
end
