require 'event_loop/switch'
require 'thread'

class EventLoop
  class Worker
    def initialize(work_queue, &job)
      @is_on       = false
      @status      = :resting
      @blocker     = Switch.new :blocked
      @work_queue  = work_queue
      @job         = job
      @thread      = Thread.new { process_work }
    end

    def resting?
      @status == :resting
    end

    def waiting?
      @status == :waiting
    end

    def working?
      @status == :working
    end

    def off?
      !on?
    end

    def on?
      @is_on
    end

    def off!
      @is_on = false
      @blocker.block
      self
    end

    def on!
      @is_on = true
      @blocker.unblock
      self
    end
    private

    def process_work
      loop do
        @status = :resting
        @blocker.wait

        @status = :waiting
        work = @work_queue.shift

        @status = :resting
        @blocker.wait

        @status = :working
        @job.call work
      end
    end

  end
end
